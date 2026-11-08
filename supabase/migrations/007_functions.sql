-- ============================================================================
-- Migration: 003_functions.sql
-- Description: Transactional RPC functions for core business workflows
-- All functions use `security invoker`, `set search_path = public`
-- Down Migration Note:
-- DROP FUNCTION IF EXISTS export_all(), delete_branch(text), delete_account(text),
--   restore_account(text), archive_account(text), set_claim_status(text, text, bigint, timestamptz),
--   bulk_claim(text, text[], bigint), create_update(text, text, date, date, text, bigint, text, text);
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Function: create_update
-- Creates update and auto-populates claims once for all active eligible accounts
-- ----------------------------------------------------------------------------
create or replace function public.create_update(
    p_update_id text,
    p_update_name text,
    p_start_date date default null,
    p_end_date date default null,
    p_reward_type text default 'DM',
    p_reward_amount bigint default 0,
    p_eligibility_rule text default 'all_active',
    p_notes text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_owner_id uuid := auth.uid();
    v_claims_count bigint := 0;
begin
    -- Validations
    if p_update_id is null or trim(p_update_id) = '' then
        raise exception 'update_id cannot be empty';
    end if;
    if p_update_name is null or trim(p_update_name) = '' then
        raise exception 'update_name cannot be empty';
    end if;
    if p_reward_type not in ('DM', 'VC') then
        raise exception 'Invalid reward_type: %, must be DM or VC', p_reward_type;
    end if;
    if p_reward_amount < 0 then
        raise exception 'reward_amount must be >= 0';
    end if;
    if p_eligibility_rule not in ('all_active', 'ready_only') then
        raise exception 'Invalid eligibility_rule: %, must be all_active or ready_only', p_eligibility_rule;
    end if;

    -- Insert update row
    insert into public.updates (
        update_id, owner_id, update_name, start_date, end_date,
        status, reward_type, reward_amount, eligibility_rule, notes
    ) values (
        p_update_id, v_owner_id, trim(p_update_name), p_start_date, p_end_date,
        'Active', p_reward_type, p_reward_amount, p_eligibility_rule, p_notes
    );

    -- Create claims for active accounts (not Archived)
    -- Rule: if ready_only, only 'Ready' accounts are Eligible; otherwise all active accounts are Eligible
    insert into public.claims (
        claim_id, owner_id, update_id, account_id, branch_id_at_claim,
        eligibility_status, claim_status, reward_type, reward_amount_claimed, notes
    )
    select
        'clm_' || substr(md5(random()::text || clock_timestamp()::text || a.account_id), 1, 16),
        v_owner_id,
        p_update_id,
        a.account_id,
        a.branch_id,
        case
            when p_eligibility_rule = 'ready_only' and a.status <> 'Ready' then 'Not Eligible'
            else 'Eligible'
        end,
        'Pending',
        p_reward_type,
        0,
        'Auto-created on update creation'
    from public.accounts a
    where a.owner_id = v_owner_id
      and a.status <> 'Archived';

    get diagnostics v_claims_count = row_count;

    -- Audit log
    insert into public.activity_logs (
        log_id, owner_id, action, entity_type, entity_id, new_value
    ) values (
        'log_' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
        v_owner_id,
        'CREATE_UPDATE',
        'update',
        p_update_id,
        jsonb_build_object(
            'update_id', p_update_id,
            'update_name', p_update_name,
            'reward_type', p_reward_type,
            'reward_amount', p_reward_amount,
            'eligibility_rule', p_eligibility_rule,
            'claims_created', v_claims_count
        )
    );

    return jsonb_build_object(
        'update_id', p_update_id,
        'claims_created', v_claims_count
    );
end;
$$;

-- ----------------------------------------------------------------------------
-- 2. Function: bulk_claim
-- Claims rewards for specified accounts; skips archived & not eligible; idempotent
-- ----------------------------------------------------------------------------
create or replace function public.bulk_claim(
    p_update_id text,
    p_account_ids text[],
    p_amount bigint default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_owner_id uuid := auth.uid();
    v_update record;
    v_claim_amount bigint;
    v_updated_count bigint := 0;
    v_skipped_count bigint := 0;
begin
    -- Validate update exists
    select * into v_update
    from public.updates
    where update_id = p_update_id and owner_id = v_owner_id;

    if not found then
        raise exception 'Update % not found', p_update_id;
    end if;

    -- Default amount from patch if not specified
    v_claim_amount := coalesce(p_amount, v_update.reward_amount);
    if v_claim_amount < 0 then
        raise exception 'Claim amount must be >= 0';
    end if;

    -- Update claims:
    -- Only updates claims for the targeted accounts that are:
    -- 1. Currently Pending or Failed (already Claimed claims are untouched -> idempotent)
    -- 2. Eligible (eligibility_status = 'Eligible')
    -- 3. Account is NOT Archived
    with target_claims as (
        select c.claim_id
        from public.claims c
        join public.accounts a on c.account_id = a.account_id
        where c.owner_id = v_owner_id
          and c.update_id = p_update_id
          and c.account_id = any(p_account_ids)
          and c.claim_status in ('Pending', 'Failed')
          and c.eligibility_status = 'Eligible'
          and a.status <> 'Archived'
    ),
    updated as (
        update public.claims c
        set
            claim_status = 'Claimed',
            reward_amount_claimed = v_claim_amount,
            claimed_at = now()
        from target_claims t
        where c.claim_id = t.claim_id
        returning c.claim_id
    )
    select count(*) into v_updated_count from updated;

    v_skipped_count := coalesce(cardinality(p_account_ids), 0) - v_updated_count;

    -- Activity log
    insert into public.activity_logs (
        log_id, owner_id, action, entity_type, entity_id, new_value
    ) values (
        'log_' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
        v_owner_id,
        'BULK_CLAIM',
        'update',
        p_update_id,
        jsonb_build_object(
            'update_id', p_update_id,
            'claim_amount', v_claim_amount,
            'updated_count', v_updated_count,
            'skipped_count', v_skipped_count,
            'account_ids', p_account_ids
        )
    );

    return jsonb_build_object(
        'update_id', p_update_id,
        'updated_count', v_updated_count,
        'skipped_count', v_skipped_count
    );
end;
$$;

-- ----------------------------------------------------------------------------
-- 3. Function: set_claim_status
-- Sets individual claim status; prevents claiming for archived accounts
-- ----------------------------------------------------------------------------
create or replace function public.set_claim_status(
    p_claim_id text,
    p_status text,
    p_amount bigint default null,
    p_claimed_at timestamptz default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_owner_id uuid := auth.uid();
    v_claim record;
    v_account record;
    v_update record;
    v_final_amount bigint := 0;
    v_final_claimed_at timestamptz := null;
    v_old_value jsonb;
    v_new_value jsonb;
begin
    if p_status not in ('Pending', 'Claimed', 'Failed', 'Not Eligible') then
        raise exception 'Invalid claim status: %', p_status;
    end if;

    select * into v_claim
    from public.claims
    where claim_id = p_claim_id and owner_id = v_owner_id;

    if not found then
        raise exception 'Claim % not found', p_claim_id;
    end if;

    select * into v_account
    from public.accounts
    where account_id = v_claim.account_id and owner_id = v_owner_id;

    select * into v_update
    from public.updates
    where update_id = v_claim.update_id and owner_id = v_owner_id;

    -- Business Rule: Archived accounts cannot be newly Claimed
    if p_status = 'Claimed' and v_account.status = 'Archived' then
        raise exception 'Cannot mark claim as Claimed for archived account %', v_claim.account_id;
    end if;

    if p_status = 'Claimed' then
        v_final_amount := coalesce(p_amount, v_update.reward_amount, 0);
        v_final_claimed_at := coalesce(p_claimed_at, now());
    else
        -- Pending, Failed, Not Eligible have 0 reward and null claimed_at
        v_final_amount := 0;
        v_final_claimed_at := null;
    end if;

    v_old_value := row_to_json(v_claim)::jsonb;

    update public.claims
    set
        claim_status = p_status,
        reward_amount_claimed = v_final_amount,
        claimed_at = v_final_claimed_at
    where claim_id = p_claim_id;

    select row_to_json(c)::jsonb into v_new_value
    from public.claims c
    where c.claim_id = p_claim_id;

    -- Activity log
    insert into public.activity_logs (
        log_id, owner_id, action, entity_type, entity_id, old_value, new_value
    ) values (
        'log_' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
        v_owner_id,
        'SET_CLAIM_STATUS',
        'claim',
        p_claim_id,
        v_old_value,
        v_new_value
    );

    return v_new_value;
end;
$$;

-- ----------------------------------------------------------------------------
-- 4. Function: archive_account & restore_account
-- ----------------------------------------------------------------------------
create or replace function public.archive_account(p_account_id text)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_owner_id uuid := auth.uid();
    v_acc record;
    v_old_value jsonb;
    v_new_value jsonb;
begin
    select * into v_acc
    from public.accounts
    where account_id = p_account_id and owner_id = v_owner_id;

    if not found then
        raise exception 'Account % not found', p_account_id;
    end if;

    if v_acc.status = 'Archived' then
        raise exception 'Account % is already archived', p_account_id;
    end if;

    v_old_value := row_to_json(v_acc)::jsonb;

    update public.accounts
    set
        status_before_archive = v_acc.status,
        status = 'Archived',
        archived_at = now()
    where account_id = p_account_id;

    select row_to_json(a)::jsonb into v_new_value
    from public.accounts a
    where a.account_id = p_account_id;

    insert into public.activity_logs (
        log_id, owner_id, action, entity_type, entity_id, old_value, new_value
    ) values (
        'log_' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
        v_owner_id,
        'ARCHIVE_ACCOUNT',
        'account',
        p_account_id,
        v_old_value,
        v_new_value
    );

    return v_new_value;
end;
$$;

create or replace function public.restore_account(p_account_id text)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_owner_id uuid := auth.uid();
    v_acc record;
    v_target_status text;
    v_old_value jsonb;
    v_new_value jsonb;
begin
    select * into v_acc
    from public.accounts
    where account_id = p_account_id and owner_id = v_owner_id;

    if not found then
        raise exception 'Account % not found', p_account_id;
    end if;

    if v_acc.status <> 'Archived' then
        raise exception 'Account % is not archived', p_account_id;
    end if;

    -- Legacy rows or empty status_before_archive restore to 'Pre-farm'
    v_target_status := coalesce(v_acc.status_before_archive, 'Pre-farm');

    v_old_value := row_to_json(v_acc)::jsonb;

    update public.accounts
    set
        status = v_target_status,
        status_before_archive = null,
        archived_at = null
    where account_id = p_account_id;

    select row_to_json(a)::jsonb into v_new_value
    from public.accounts a
    where a.account_id = p_account_id;

    insert into public.activity_logs (
        log_id, owner_id, action, entity_type, entity_id, old_value, new_value
    ) values (
        'log_' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
        v_owner_id,
        'RESTORE_ACCOUNT',
        'account',
        p_account_id,
        v_old_value,
        v_new_value
    );

    return v_new_value;
end;
$$;

-- ----------------------------------------------------------------------------
-- 5. Function: delete_account
-- Deletes account, claims, sources, topups, and account-linked VC transactions
-- Global VC is NEVER deleted. Raises exception if total VC would go negative.
-- ----------------------------------------------------------------------------
create or replace function public.delete_account(p_account_id text)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_owner_id uuid := auth.uid();
    v_acc record;
    v_current_global_vc bigint := 0;
    v_account_vc_net bigint := 0;
    v_post_deletion_vc bigint := 0;
    v_snapshot jsonb;
begin
    select * into v_acc
    from public.accounts
    where account_id = p_account_id and owner_id = v_owner_id;

    if not found then
        raise exception 'Account % not found', p_account_id;
    end if;

    -- Check VC balance impact
    -- Global VC balance right now
    select coalesce(sum(vc_earned) - sum(vc_spent), 0) into v_current_global_vc
    from public.vc_transactions
    where owner_id = v_owner_id;

    -- Net VC of this account
    select coalesce(sum(vc_earned) - sum(vc_spent), 0) into v_account_vc_net
    from public.vc_transactions
    where owner_id = v_owner_id and account_id = p_account_id;

    -- After deleting this account's VC rows, remaining VC balance would be:
    -- current_global_vc - account_vc_net
    v_post_deletion_vc := v_current_global_vc - v_account_vc_net;

    if v_post_deletion_vc < 0 then
        raise exception 'Cannot delete account %: VC balance would become negative (%). Consider archiving instead.',
            p_account_id, v_post_deletion_vc;
    end if;

    -- Capture snapshot before deletion
    v_snapshot := jsonb_build_object(
        'account', row_to_json(v_acc),
        'claims', (
            select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb)
            from public.claims c where c.account_id = p_account_id and c.owner_id = v_owner_id
        ),
        'sources', (
            select coalesce(jsonb_agg(row_to_json(s)), '[]'::jsonb)
            from public.account_sources s where s.account_id = p_account_id and s.owner_id = v_owner_id
        ),
        'topups', (
            select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb)
            from public.account_topups t where t.account_id = p_account_id and t.owner_id = v_owner_id
        ),
        'vc_transactions', (
            select coalesce(jsonb_agg(row_to_json(v)), '[]'::jsonb)
            from public.vc_transactions v where v.account_id = p_account_id and v.owner_id = v_owner_id
        )
    );

    -- Delete linked rows in order
    delete from public.claims where account_id = p_account_id and owner_id = v_owner_id;
    delete from public.account_sources where account_id = p_account_id and owner_id = v_owner_id;
    delete from public.account_topups where account_id = p_account_id and owner_id = v_owner_id;
    -- ONLY delete account-linked VC transactions; global VC (account_id is null) is NEVER deleted
    delete from public.vc_transactions where account_id = p_account_id and owner_id = v_owner_id;
    delete from public.accounts where account_id = p_account_id and owner_id = v_owner_id;

    -- Activity log
    insert into public.activity_logs (
        log_id, owner_id, action, entity_type, entity_id, old_value
    ) values (
        'log_' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
        v_owner_id,
        'DELETE_ACCOUNT',
        'account',
        p_account_id,
        v_snapshot
    );

    return v_snapshot;
end;
$$;

-- ----------------------------------------------------------------------------
-- 6. Function: delete_branch
-- Deletes a branch only if no accounts reference it
-- ----------------------------------------------------------------------------
create or replace function public.delete_branch(p_branch_id text)
returns boolean
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_owner_id uuid := auth.uid();
    v_branch record;
    v_acc_count bigint;
begin
    select * into v_branch
    from public.branches
    where branch_id = p_branch_id and owner_id = v_owner_id;

    if not found then
        raise exception 'Branch % not found', p_branch_id;
    end if;

    select count(*) into v_acc_count
    from public.accounts
    where branch_id = p_branch_id and owner_id = v_owner_id;

    if v_acc_count > 0 then
        raise exception 'Cannot delete branch %: branch still contains % accounts. Move or archive accounts first.',
            p_branch_id, v_acc_count;
    end if;

    delete from public.branches where branch_id = p_branch_id and owner_id = v_owner_id;

    insert into public.activity_logs (
        log_id, owner_id, action, entity_type, entity_id, old_value
    ) values (
        'log_' || substr(md5(random()::text || clock_timestamp()::text), 1, 16),
        v_owner_id,
        'DELETE_BRANCH',
        'branch',
        p_branch_id,
        row_to_json(v_branch)::jsonb
    );

    return true;
end;
$$;

-- ----------------------------------------------------------------------------
-- 7. Function: export_all
-- Returns complete backup JSON of all tables for authenticated owner
-- ----------------------------------------------------------------------------
create or replace function public.export_all()
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_owner_id uuid := auth.uid();
    v_result jsonb;
begin
    v_result := jsonb_build_object(
        'exported_at', now(),
        'owner_id', v_owner_id,
        'schema_version', 3,
        'branches', (
            select coalesce(jsonb_agg(row_to_json(b)), '[]'::jsonb)
            from public.branches b where b.owner_id = v_owner_id
        ),
        'accounts', (
            select coalesce(jsonb_agg(row_to_json(a)), '[]'::jsonb)
            from public.accounts a where a.owner_id = v_owner_id
        ),
        'updates', (
            select coalesce(jsonb_agg(row_to_json(u)), '[]'::jsonb)
            from public.updates u where u.owner_id = v_owner_id
        ),
        'claims', (
            select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb)
            from public.claims c where c.owner_id = v_owner_id
        ),
        'account_sources', (
            select coalesce(jsonb_agg(row_to_json(s)), '[]'::jsonb)
            from public.account_sources s where s.owner_id = v_owner_id
        ),
        'account_topups', (
            select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb)
            from public.account_topups t where t.owner_id = v_owner_id
        ),
        'vc_transactions', (
            select coalesce(jsonb_agg(row_to_json(v)), '[]'::jsonb)
            from public.vc_transactions v where v.owner_id = v_owner_id
        ),
        'settings', (
            select coalesce(jsonb_agg(row_to_json(st)), '[]'::jsonb)
            from public.settings st where st.owner_id = v_owner_id
        ),
        'activity_logs', (
            select coalesce(jsonb_agg(row_to_json(al)), '[]'::jsonb)
            from public.activity_logs al where al.owner_id = v_owner_id
        )
    );

    return v_result;
end;
$$;
