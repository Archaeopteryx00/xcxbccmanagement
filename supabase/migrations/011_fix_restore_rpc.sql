-- ============================================================================
-- Migration: 011_fix_restore_rpc.sql
-- Description: Fix restore_full_backup function - settings loop bug + improvements
-- ============================================================================

create or replace function public.restore_full_backup(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid := auth.uid();
  v_branch jsonb;
  v_account jsonb;
  v_update jsonb;
  v_claim jsonb;
  v_src jsonb;
  v_tp jsonb;
  v_vc jsonb;
  v_key text;
  v_val jsonb;
  v_status text;
  v_reward_type text;
  v_claim_status text;
  v_elig_status text;
  v_reward_amount bigint;
  v_claimed_at timestamptz;
  v_archived_at timestamptz;
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
    raise exception 'Not authenticated';
  end if;

  -- ----------------------------------------------------------------
  -- Delete in dependency order (child tables first)
  -- ----------------------------------------------------------------
  delete from public.activity_logs   where owner_id = v_owner;
  delete from public.claims          where owner_id = v_owner;
  delete from public.account_sources where owner_id = v_owner;
  delete from public.account_topups  where owner_id = v_owner;
  delete from public.vc_transactions where owner_id = v_owner;
  delete from public.accounts        where owner_id = v_owner;
  delete from public.updates         where owner_id = v_owner;
  delete from public.branches        where owner_id = v_owner;

  -- ----------------------------------------------------------------
  -- Insert branches
  -- ----------------------------------------------------------------
  for v_branch in select value from jsonb_array_elements(coalesce(payload->'branches', '[]'::jsonb))
  loop
    v_status := case
      when (v_branch->>'status') in ('Active','Inactive','Archived') then v_branch->>'status'
      else 'Active'
    end;
    insert into public.branches (branch_id, owner_id, branch_name, email_login, status, notes)
    values (
      v_branch->>'branch_id',
      v_owner,
      v_branch->>'branch_name',
      nullif(trim(v_branch->>'email_login'), ''),
      v_status,
      nullif(trim(v_branch->>'notes'), '')
    )
    on conflict (branch_id) do update
      set branch_name = excluded.branch_name,
          email_login = excluded.email_login,
          status      = excluded.status,
          notes       = excluded.notes;
    b_count := b_count + 1;
  end loop;

  -- ----------------------------------------------------------------
  -- Insert accounts
  -- ----------------------------------------------------------------
  for v_account in select value from jsonb_array_elements(coalesce(payload->'accounts', '[]'::jsonb))
  loop
    v_status := case
      when (v_account->>'status') in ('Pre-farm','Farming','Ready','Failed','Archived') then v_account->>'status'
      else 'Pre-farm'
    end;
    v_archived_at := case
      when v_status = 'Archived' then
        coalesce(nullif(v_account->>'archived_at','')::timestamptz, now())
      else null
    end;
    insert into public.accounts (
      account_id, owner_id, branch_id, server_code, level, status,
      status_before_archive, archived_at, auto_level_result, notes
    ) values (
      v_account->>'account_id',
      v_owner,
      v_account->>'branch_id',
      nullif(trim(v_account->>'server_code'), ''),
      greatest(1, coalesce(nullif(v_account->>'level','')::int, 1)),
      v_status,
      case when v_status = 'Archived' then nullif(trim(v_account->>'status_before_archive'),'') else null end,
      v_archived_at,
      case
        when (v_account->>'auto_level_result') in ('Untested','Success','Failed') then v_account->>'auto_level_result'
        else 'Untested'
      end,
      nullif(trim(v_account->>'notes'), '')
    )
    on conflict (account_id) do update
      set branch_id             = excluded.branch_id,
          server_code           = excluded.server_code,
          level                 = excluded.level,
          status                = excluded.status,
          status_before_archive = excluded.status_before_archive,
          archived_at           = excluded.archived_at,
          auto_level_result     = excluded.auto_level_result,
          notes                 = excluded.notes;
    a_count := a_count + 1;
  end loop;

  -- ----------------------------------------------------------------
  -- Insert updates
  -- ----------------------------------------------------------------
  for v_update in select value from jsonb_array_elements(coalesce(payload->'updates', '[]'::jsonb))
  loop
    v_status := case (v_update->>'status')
      when 'Open'     then 'Active'
      when 'open'     then 'Active'
      when 'Active'   then 'Active'
      when 'Closed'   then 'Closed'
      when 'Archived' then 'Archived'
      when 'Draft'    then 'Draft'
      else 'Active'
    end;
    v_reward_type := case
      when (v_update->>'reward_type') in ('DM','VC') then v_update->>'reward_type'
      else 'DM'
    end;
    insert into public.updates (
      update_id, owner_id, update_name, start_date, end_date,
      status, reward_type, reward_amount, eligibility_rule, notes
    ) values (
      v_update->>'update_id',
      v_owner,
      v_update->>'update_name',
      nullif(v_update->>'start_date','')::date,
      nullif(v_update->>'end_date','')::date,
      v_status,
      v_reward_type,
      greatest(0, coalesce(nullif(v_update->>'reward_amount','')::bigint, 0)),
      case
        when (v_update->>'eligibility_rule') in ('all_active','ready_only') then v_update->>'eligibility_rule'
        else 'all_active'
      end,
      nullif(trim(v_update->>'notes'), '')
    )
    on conflict (update_id) do update
      set update_name      = excluded.update_name,
          start_date       = excluded.start_date,
          end_date         = excluded.end_date,
          status           = excluded.status,
          reward_type      = excluded.reward_type,
          reward_amount    = excluded.reward_amount,
          eligibility_rule = excluded.eligibility_rule,
          notes            = excluded.notes;
    u_count := u_count + 1;
  end loop;

  -- ----------------------------------------------------------------
  -- Insert claims
  -- ----------------------------------------------------------------
  for v_claim in select value from jsonb_array_elements(coalesce(payload->'claims', '[]'::jsonb))
  loop
    v_claim_status := case
      when (v_claim->>'claim_status') in ('Pending','Claimed','Failed','Not Eligible') then v_claim->>'claim_status'
      else 'Pending'
    end;
    v_elig_status := case
      when (v_claim->>'eligibility_status') in ('Eligible','Not Eligible') then v_claim->>'eligibility_status'
      when lower(v_claim->>'eligibility_status') = 'not eligible' then 'Not Eligible'
      else 'Eligible'
    end;
    v_reward_type := case
      when (v_claim->>'reward_type') in ('DM','VC') then v_claim->>'reward_type'
      else 'DM'
    end;
    v_reward_amount := case
      when v_claim_status = 'Claimed' then
        greatest(0, coalesce(
          nullif(v_claim->>'reward_amount_claimed','')::bigint,
          nullif(v_claim->>'dm_claimed','')::bigint,
          0
        ))
      else 0
    end;
    v_claimed_at := case
      when v_claim_status = 'Claimed' then
        coalesce(nullif(v_claim->>'claimed_at','')::timestamptz, now())
      else null
    end;
    insert into public.claims (
      claim_id, owner_id, update_id, account_id, branch_id_at_claim,
      eligibility_status, claim_status, reward_type,
      reward_amount_claimed, claimed_at, notes
    ) values (
      v_claim->>'claim_id',
      v_owner,
      v_claim->>'update_id',
      v_claim->>'account_id',
      nullif(trim(coalesce(v_claim->>'branch_id_at_claim','')), ''),
      v_elig_status,
      v_claim_status,
      v_reward_type,
      v_reward_amount,
      v_claimed_at,
      nullif(trim(v_claim->>'notes'), '')
    )
    on conflict (claim_id) do update
      set eligibility_status    = excluded.eligibility_status,
          claim_status          = excluded.claim_status,
          reward_type           = excluded.reward_type,
          reward_amount_claimed = excluded.reward_amount_claimed,
          claimed_at            = excluded.claimed_at,
          notes                 = excluded.notes;
    c_count := c_count + 1;
  end loop;

  -- ----------------------------------------------------------------
  -- Insert account_sources
  -- ----------------------------------------------------------------
  for v_src in select value from jsonb_array_elements(coalesce(payload->'account_sources', '[]'::jsonb))
  loop
    insert into public.account_sources (
      source_id, owner_id, account_id, source_type,
      nominal, bonus_amount, total_received,
      received_at, bonus_status, multiplier, notes
    ) values (
      v_src->>'source_id',
      v_owner,
      v_src->>'account_id',
      coalesce(nullif(trim(v_src->>'source_type'),''), 'DM'),
      greatest(0, coalesce(nullif(v_src->>'nominal','')::bigint, 0)),
      greatest(0, coalesce(nullif(v_src->>'bonus_amount','')::bigint, 0)),
      greatest(0, coalesce(nullif(v_src->>'total_received','')::bigint, 0)),
      nullif(v_src->>'received_at','')::date,
      coalesce(nullif(trim(v_src->>'bonus_status'),''), 'Not Eligible'),
      greatest(1, coalesce(nullif(v_src->>'multiplier','')::numeric, 1)),
      nullif(trim(v_src->>'notes'), '')
    )
    on conflict (source_id) do update
      set source_type    = excluded.source_type,
          nominal        = excluded.nominal,
          bonus_amount   = excluded.bonus_amount,
          total_received = excluded.total_received,
          received_at    = excluded.received_at,
          bonus_status   = excluded.bonus_status,
          multiplier     = excluded.multiplier,
          notes          = excluded.notes;
    s_count := s_count + 1;
  end loop;

  -- ----------------------------------------------------------------
  -- Insert account_topups
  -- ----------------------------------------------------------------
  for v_tp in select value from jsonb_array_elements(coalesce(payload->'account_topups', '[]'::jsonb))
  loop
    insert into public.account_topups (
      topup_id, owner_id, account_id, nominal,
      bonus_status, bonus_amount, total_received,
      topup_date, bonus_claim_date, notes
    ) values (
      v_tp->>'topup_id',
      v_owner,
      v_tp->>'account_id',
      greatest(0, coalesce(nullif(v_tp->>'nominal','')::bigint, 0)),
      coalesce(nullif(trim(v_tp->>'bonus_status'),''), 'None'),
      greatest(0, coalesce(nullif(v_tp->>'bonus_amount','')::bigint, 0)),
      greatest(0, coalesce(nullif(v_tp->>'total_received','')::bigint, 0)),
      nullif(v_tp->>'topup_date','')::date,
      nullif(v_tp->>'bonus_claim_date','')::date,
      nullif(trim(v_tp->>'notes'), '')
    )
    on conflict (topup_id) do update
      set nominal          = excluded.nominal,
          bonus_status     = excluded.bonus_status,
          bonus_amount     = excluded.bonus_amount,
          total_received   = excluded.total_received,
          topup_date       = excluded.topup_date,
          bonus_claim_date = excluded.bonus_claim_date,
          notes            = excluded.notes;
    t_count := t_count + 1;
  end loop;

  -- ----------------------------------------------------------------
  -- Insert vc_transactions
  -- ----------------------------------------------------------------
  for v_vc in select value from jsonb_array_elements(coalesce(payload->'vc_transactions', '[]'::jsonb))
  loop
    continue when coalesce(nullif(v_vc->>'vc_earned','')::bigint, 0) = 0
              and coalesce(nullif(v_vc->>'vc_spent','')::bigint, 0) = 0;
    insert into public.vc_transactions (
      transaction_id, owner_id, account_id, source,
      vc_earned, vc_spent, transaction_date, description
    ) values (
      v_vc->>'transaction_id',
      v_owner,
      nullif(trim(coalesce(v_vc->>'account_id','')), ''),
      coalesce(nullif(trim(v_vc->>'source'),''), 'Manual'),
      greatest(0, coalesce(nullif(v_vc->>'vc_earned','')::bigint, 0)),
      greatest(0, coalesce(nullif(v_vc->>'vc_spent','')::bigint, 0)),
      coalesce(
        nullif(v_vc->>'transaction_date','')::date,
        nullif(v_vc->>'date','')::date,
        current_date
      ),
      nullif(trim(coalesce(v_vc->>'description', v_vc->>'notes', '')), '')
    )
    on conflict (transaction_id) do update
      set source           = excluded.source,
          vc_earned        = excluded.vc_earned,
          vc_spent         = excluded.vc_spent,
          transaction_date = excluded.transaction_date,
          description      = excluded.description;
    v_count := v_count + 1;
  end loop;

  -- ----------------------------------------------------------------
  -- Upsert settings (merge, not delete)
  -- FIX: jsonb_each returns (key text, value jsonb) — use record fields directly
  -- ----------------------------------------------------------------
  for v_key, v_val in select key, value from jsonb_each(coalesce(payload->'settings', '{}'::jsonb))
  loop
    insert into public.settings (owner_id, key, value)
    values (v_owner, v_key, v_val)
    on conflict (owner_id, key) do update
      set value = excluded.value;
    set_count := set_count + 1;
  end loop;

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

