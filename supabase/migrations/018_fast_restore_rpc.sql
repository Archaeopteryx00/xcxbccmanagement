-- ============================================================================
-- Migration: 018_fast_restore_rpc.sql
-- Description: Ultra-fast set-based bulk restore (100ms instead of 10s loop)
-- Avoids pgbouncer deadlocks and locks tables for minimal time
-- ============================================================================

create or replace function public.restore_full_backup(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid := auth.uid();
  b_count int := 0;
  a_count int := 0;
  u_count int := 0;
  c_count int := 0;
  s_count int := 0;
  t_count int := 0;
  v_count int := 0;
  set_count int := 0;
begin
  if v_owner is null then
    return jsonb_build_object('success', false, 'error', 'Not authenticated');
  end if;

  -- 1. Atomic delete of owner's existing records (child -> parent)
  delete from public.claims          where owner_id = v_owner;
  delete from public.account_sources where owner_id = v_owner;
  delete from public.account_topups  where owner_id = v_owner;
  delete from public.vc_transactions where owner_id = v_owner;
  delete from public.accounts        where owner_id = v_owner;
  delete from public.updates         where owner_id = v_owner;
  delete from public.branches        where owner_id = v_owner;

  -- 2. Bulk Insert Branches (set-based)
  with inserted as (
    insert into public.branches (branch_id, owner_id, branch_name, email_login, status, notes)
    select
      elem->>'branch_id',
      v_owner,
      elem->>'branch_name',
      nullif(trim(elem->>'email_login'), ''),
      case when elem->>'status' in ('Active','Inactive','Archived') then elem->>'status' else 'Active' end,
      nullif(trim(elem->>'notes'), '')
    from jsonb_array_elements(coalesce(payload->'branches', '[]'::jsonb)) as elem
    where nullif(trim(elem->>'branch_id'), '') is not null
    on conflict (branch_id) do update
      set branch_name = excluded.branch_name,
          email_login = excluded.email_login,
          status      = excluded.status,
          notes       = excluded.notes
    returning 1
  )
  select count(*) from inserted into b_count;

  -- 3. Bulk Insert Accounts (set-based)
  with inserted as (
    insert into public.accounts (
      account_id, owner_id, branch_id, server_code, level, status,
      status_before_archive, archived_at, auto_level_result, notes
    )
    select
      elem->>'account_id',
      v_owner,
      elem->>'branch_id',
      nullif(trim(elem->>'server_code'), ''),
      greatest(1, coalesce(nullif(elem->>'level','')::int, 1)),
      case when elem->>'status' in ('Pre-farm','Farming','Ready','Failed','Archived') then elem->>'status' else 'Pre-farm' end as st,
      case when elem->>'status' = 'Archived' then nullif(trim(elem->>'status_before_archive'), '') else null end,
      case when elem->>'status' = 'Archived' then coalesce(nullif(elem->>'archived_at','')::timestamptz, now()) else null end,
      case when elem->>'auto_level_result' in ('Untested','Success','Failed') then elem->>'auto_level_result' else 'Untested' end,
      nullif(trim(elem->>'notes'), '')
    from jsonb_array_elements(coalesce(payload->'accounts', '[]'::jsonb)) as elem
    where nullif(trim(elem->>'account_id'), '') is not null
    on conflict (account_id) do update
      set branch_id             = excluded.branch_id,
          server_code           = excluded.server_code,
          level                 = excluded.level,
          status                = excluded.status,
          status_before_archive = excluded.status_before_archive,
          archived_at           = excluded.archived_at,
          auto_level_result     = excluded.auto_level_result,
          notes                 = excluded.notes
    returning 1
  )
  select count(*) from inserted into a_count;

  -- 4. Bulk Insert Updates (set-based)
  with inserted as (
    insert into public.updates (
      update_id, owner_id, update_name, start_date, end_date,
      status, reward_type, reward_amount, eligibility_rule, notes
    )
    select
      elem->>'update_id',
      v_owner,
      elem->>'update_name',
      nullif(elem->>'start_date','')::date,
      nullif(elem->>'end_date','')::date,
      case lower(coalesce(elem->>'status','active'))
        when 'open'     then 'Active'
        when 'closed'   then 'Closed'
        when 'archived' then 'Archived'
        when 'draft'    then 'Draft'
        else 'Active'
      end,
      case when elem->>'reward_type' in ('DM','VC') then elem->>'reward_type' else 'DM' end,
      greatest(0, coalesce(nullif(elem->>'reward_amount','')::bigint, 0)),
      case when elem->>'eligibility_rule' in ('all_active','ready_only') then elem->>'eligibility_rule' else 'all_active' end,
      nullif(trim(elem->>'notes'), '')
    from jsonb_array_elements(coalesce(payload->'updates', '[]'::jsonb)) as elem
    where nullif(trim(elem->>'update_id'), '') is not null
    on conflict (update_id) do update
      set update_name      = excluded.update_name,
          start_date       = excluded.start_date,
          end_date         = excluded.end_date,
          status           = excluded.status,
          reward_type      = excluded.reward_type,
          reward_amount    = excluded.reward_amount,
          eligibility_rule = excluded.eligibility_rule,
          notes            = excluded.notes
    returning 1
  )
  select count(*) from inserted into u_count;

  -- 5. Bulk Insert Claims (set-based)
  with inserted as (
    insert into public.claims (
      claim_id, owner_id, update_id, account_id, branch_id_at_claim,
      eligibility_status, claim_status, reward_type,
      reward_amount_claimed, claimed_at, notes
    )
    select
      elem->>'claim_id',
      v_owner,
      elem->>'update_id',
      elem->>'account_id',
      nullif(trim(coalesce(elem->>'branch_id_at_claim','')), ''),
      case when lower(coalesce(elem->>'eligibility_status','')) = 'not eligible' then 'Not Eligible' else 'Eligible' end,
      case when elem->>'claim_status' in ('Pending','Claimed','Failed','Not Eligible') then elem->>'claim_status' else 'Pending' end as cs,
      case when elem->>'reward_type' in ('DM','VC') then elem->>'reward_type' else 'DM' end,
      case when elem->>'claim_status' = 'Claimed' then greatest(0, coalesce(nullif(elem->>'reward_amount_claimed','')::bigint, nullif(elem->>'dm_claimed','')::bigint, 0)) else 0 end,
      case when elem->>'claim_status' = 'Claimed' then coalesce(nullif(elem->>'claimed_at','')::timestamptz, now()) else null end,
      nullif(trim(elem->>'notes'), '')
    from jsonb_array_elements(coalesce(payload->'claims', '[]'::jsonb)) as elem
    where nullif(trim(elem->>'claim_id'), '') is not null
    on conflict (claim_id) do update
      set eligibility_status    = excluded.eligibility_status,
          claim_status          = excluded.claim_status,
          reward_type           = excluded.reward_type,
          reward_amount_claimed = excluded.reward_amount_claimed,
          claimed_at            = excluded.claimed_at,
          notes                 = excluded.notes
    returning 1
  )
  select count(*) from inserted into c_count;

  -- 6. Bulk Insert Account Sources (set-based)
  with inserted as (
    insert into public.account_sources (
      source_id, owner_id, account_id, source_type,
      nominal, bonus_amount, total_received,
      received_at, bonus_status, multiplier, notes
    )
    select
      elem->>'source_id',
      v_owner,
      elem->>'account_id',
      coalesce(nullif(trim(elem->>'source_type'),''), 'DM'),
      greatest(0, coalesce(nullif(elem->>'nominal','')::bigint, 0)),
      greatest(0, coalesce(nullif(elem->>'bonus_amount','')::bigint, 0)),
      greatest(0, coalesce(nullif(elem->>'total_received','')::bigint, 0)),
      nullif(elem->>'received_at','')::date,
      coalesce(nullif(trim(elem->>'bonus_status'),''), 'Not Eligible'),
      greatest(1, coalesce(nullif(elem->>'multiplier','')::numeric, 1)),
      nullif(trim(elem->>'notes'), '')
    from jsonb_array_elements(coalesce(payload->'account_sources', '[]'::jsonb)) as elem
    where nullif(trim(elem->>'source_id'), '') is not null
    on conflict (source_id) do update
      set source_type    = excluded.source_type,
          nominal        = excluded.nominal,
          bonus_amount   = excluded.bonus_amount,
          total_received = excluded.total_received,
          received_at    = excluded.received_at,
          bonus_status   = excluded.bonus_status,
          multiplier     = excluded.multiplier,
          notes          = excluded.notes
    returning 1
  )
  select count(*) from inserted into s_count;

  -- 7. Bulk Insert Account Topups (set-based)
  with inserted as (
    insert into public.account_topups (
      topup_id, owner_id, account_id, nominal,
      bonus_status, bonus_amount, total_received,
      topup_date, bonus_claim_date, notes
    )
    select
      elem->>'topup_id',
      v_owner,
      elem->>'account_id',
      greatest(0, coalesce(nullif(elem->>'nominal','')::bigint, 0)),
      coalesce(nullif(trim(elem->>'bonus_status'),''), 'None'),
      greatest(0, coalesce(nullif(elem->>'bonus_amount','')::bigint, 0)),
      greatest(0, coalesce(nullif(elem->>'total_received','')::bigint, 0)),
      nullif(elem->>'topup_date','')::date,
      nullif(elem->>'bonus_claim_date','')::date,
      nullif(trim(elem->>'notes'), '')
    from jsonb_array_elements(coalesce(payload->'account_topups', '[]'::jsonb)) as elem
    where nullif(trim(elem->>'topup_id'), '') is not null
    on conflict (topup_id) do update
      set nominal          = excluded.nominal,
          bonus_status     = excluded.bonus_status,
          bonus_amount     = excluded.bonus_amount,
          total_received   = excluded.total_received,
          topup_date       = excluded.topup_date,
          bonus_claim_date = excluded.bonus_claim_date,
          notes            = excluded.notes
    returning 1
  )
  select count(*) from inserted into t_count;

  -- 8. Bulk Insert VC Transactions (set-based)
  with inserted as (
    insert into public.vc_transactions (
      transaction_id, owner_id, account_id, source,
      vc_earned, vc_spent, transaction_date, description
    )
    select
      elem->>'transaction_id',
      v_owner,
      nullif(trim(coalesce(elem->>'account_id','')), ''),
      coalesce(nullif(trim(elem->>'source'),''), 'Manual'),
      greatest(0, coalesce(nullif(elem->>'vc_earned','')::bigint, 0)),
      greatest(0, coalesce(nullif(elem->>'vc_spent','')::bigint, 0)),
      coalesce(nullif(elem->>'transaction_date','')::date, nullif(elem->>'date','')::date, current_date),
      nullif(trim(coalesce(elem->>'description', elem->>'notes', '')), '')
    from jsonb_array_elements(coalesce(payload->'vc_transactions', '[]'::jsonb)) as elem
    where nullif(trim(elem->>'transaction_id'), '') is not null
      and (coalesce(nullif(elem->>'vc_earned','')::bigint, 0) > 0 or coalesce(nullif(elem->>'vc_spent','')::bigint, 0) > 0)
    on conflict (transaction_id) do update
      set source           = excluded.source,
          vc_earned        = excluded.vc_earned,
          vc_spent         = excluded.vc_spent,
          transaction_date = excluded.transaction_date,
          description      = excluded.description
    returning 1
  )
  select count(*) from inserted into v_count;

  -- 9. Upsert Settings (set-based)
  with inserted as (
    insert into public.settings (owner_id, key, value)
    select
      v_owner,
      kv.key,
      kv.value
    from jsonb_each(coalesce(payload->'settings', '{}'::jsonb)) as kv
    on conflict (owner_id, key) do update
      set value = excluded.value
    returning 1
  )
  select count(*) from inserted into set_count;

  return jsonb_build_object(
    'success', true,
    'counts', jsonb_build_object(
      'branches',       b_count,
      'accounts',       a_count,
      'updates',        u_count,
      'claims',         c_count,
      'account_sources', s_count,
      'account_topups', t_count,
      'vc_transactions', v_count,
      'settings',       set_count
    )
  );

exception when others then
  return jsonb_build_object(
    'success', false,
    'error',   SQLERRM,
    'detail',  SQLSTATE
  );
end;
$$;

grant execute on function public.restore_full_backup(jsonb) to authenticated;
