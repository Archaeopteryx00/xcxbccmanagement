-- ============================================================================
-- Seed Import Migration: seed_import.sql
-- Generated from: backup/xcx_bbc_backup_2026-11-01T13-43-55-466Z.json
-- Idempotent: can be run repeatedly without duplicating or corrupting data
-- ============================================================================

do $$
declare
    v_owner_id uuid;
    v_count_branches int := 0;
    v_count_accounts int := 0;
    v_count_updates int := 0;
    v_count_claims int := 0;
    v_count_sources int := 0;
    v_count_topups int := 0;
    v_count_vc int := 0;
    v_count_logs int := 0;
    v_global record;
begin
    -- 1. Automatically detect first user from auth.users
    select id into v_owner_id from auth.users order by created_at asc limit 1;
    if v_owner_id is null then
        raise exception 'Belum ada user di Supabase Auth! Silakan buat 1 user di menu Authentication -> Users terlebih dahulu.';
    end if;

    raise notice 'Importing data for owner_id: %', v_owner_id;

    -- 2. Import branches (4 rows)
    insert into public.branches (branch_id, owner_id, branch_name, email_login, status, notes, created_at)
    values ('b_works', v_owner_id, '@works', 'muftidoworks@gmail.com', 'Active', 'cabang 1', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (branch_id) do update set
        branch_name = excluded.branch_name,
        email_login = excluded.email_login,
        status = excluded.status,
        notes = excluded.notes;
    insert into public.branches (branch_id, owner_id, branch_name, email_login, status, notes, created_at)
    values ('b_school', v_owner_id, '@school', 'school_admin@xcx.com', 'Active', 'Termasuk 7 akun belum dinamai', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (branch_id) do update set
        branch_name = excluded.branch_name,
        email_login = excluded.email_login,
        status = excluded.status,
        notes = excluded.notes;
    insert into public.branches (branch_id, owner_id, branch_name, email_login, status, notes, created_at)
    values ('b_amazon', v_owner_id, '@amazon', 'amazon_admin@xcx.com', 'Active', 'Termasuk ready dan gagal auto-level', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (branch_id) do update set
        branch_name = excluded.branch_name,
        email_login = excluded.email_login,
        status = excluded.status,
        notes = excluded.notes;
    insert into public.branches (branch_id, owner_id, branch_name, email_login, status, notes, created_at)
    values ('b_main', v_owner_id, '@main', 'main_admin@xcx.com', 'Active', 'XCX 200-206 pre-farm', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (branch_id) do update set
        branch_name = excluded.branch_name,
        email_login = excluded.email_login,
        status = excluded.status,
        notes = excluded.notes;

    -- 3. Import accounts (34 rows)
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_w1', v_owner_id, 'b_works', 'XCX 002', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_w2', v_owner_id, 'b_works', 'XCX 007', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_w3', v_owner_id, 'b_works', 'XCX 008', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s1', v_owner_id, 'b_school', 'XCX 001', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s2', v_owner_id, 'b_school', 'XCX 003', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s3', v_owner_id, 'b_school', 'XCX 004', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s4', v_owner_id, 'b_school', 'XCX 005', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s5', v_owner_id, 'b_school', 'XCX 006', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s6', v_owner_id, 'b_school', 'UN 01', 1, 'Pre-farm', 'Untested', 'Akun belum dinamai detail', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s7', v_owner_id, 'b_school', 'UN 02', 1, 'Pre-farm', 'Untested', 'Akun belum dinamai detail', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s8', v_owner_id, 'b_school', 'UN 03', 1, 'Pre-farm', 'Untested', 'Akun belum dinamai detail', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s9', v_owner_id, 'b_school', 'UN 05', 1, 'Pre-farm', 'Untested', 'Akun belum dinamai detail', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s10', v_owner_id, 'b_school', 'UN 06', 1, 'Pre-farm', 'Untested', 'Akun belum dinamai detail', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s11', v_owner_id, 'b_school', 'UN 07', 1, 'Pre-farm', 'Untested', 'Akun belum dinamai detail', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_s12', v_owner_id, 'b_school', 'UN 08', 1, 'Pre-farm', 'Untested', 'Akun belum dinamai detail', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a104', v_owner_id, 'b_amazon', 'XCX 104', 6, 'Failed', 'Failed', 'Gagal auto-level di level 6', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a105', v_owner_id, 'b_amazon', 'XCX 105', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a111', v_owner_id, 'b_amazon', 'XCX 111', 6, 'Failed', 'Failed', 'Gagal auto-level di level 6', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a110', v_owner_id, 'b_amazon', 'XCX 110', 10, 'Ready', 'Success', 'Diperbarui menjadi Ready dengan 500 DM', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a_extra_1', v_owner_id, 'b_amazon', 'XCX 112', 10, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a_extra_2', v_owner_id, 'b_amazon', 'XCX 113', 10, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a_extra_3', v_owner_id, 'b_amazon', 'XCX 114', 10, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a_extra_4', v_owner_id, 'b_amazon', 'XCX 109', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a_extra_5', v_owner_id, 'b_amazon', 'XCX 108', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a_extra_6', v_owner_id, 'b_amazon', 'XCX 107', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_a_extra_7', v_owner_id, 'b_amazon', 'XCX 106', 23, 'Ready', 'Success', '', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_m1', v_owner_id, 'b_main', 'XCX 200', 1, 'Pre-farm', 'Untested', 'Pre-farm batch 200-206', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_m2', v_owner_id, 'b_main', 'XCX 201', 1, 'Pre-farm', 'Untested', 'Pre-farm batch 200-206', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_m3', v_owner_id, 'b_main', 'XCX 202', 1, 'Pre-farm', 'Untested', 'Pre-farm batch 200-206', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_m4', v_owner_id, 'b_main', 'XCX 203', 1, 'Pre-farm', 'Untested', 'Pre-farm batch 200-206', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_m5', v_owner_id, 'b_main', 'XCX 204', 1, 'Pre-farm', 'Untested', 'Pre-farm batch 200-206', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_m6', v_owner_id, 'b_main', 'XCX 205', 1, 'Pre-farm', 'Untested', 'Pre-farm batch 200-206', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_m7', v_owner_id, 'b_main', 'XCX 206', 1, 'Pre-farm', 'Untested', 'Pre-farm batch 200-206', coalesce('2026-10-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values ('acc_1793539815820', v_owner_id, 'b_school', 'UN 09', 1, 'Pre-farm', 'Untested', '', coalesce('2026-11-01'::timestamptz, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;

    -- 4. Import updates (2 rows)
    insert into public.updates (update_id, owner_id, update_name, start_date, end_date, status, reward_type, reward_amount, notes, created_at)
    values ('up_oct26', v_owner_id, 'Update Periode Oktober 2026', '2026-10-15'::date, '2026-10-31'::date, 'Closed', 'DM', 125, 'Klaim pertama 2026', now())
    on conflict (update_id) do update set
        update_name = excluded.update_name,
        start_date = excluded.start_date,
        end_date = excluded.end_date,
        status = excluded.status,
        notes = excluded.notes;
    insert into public.updates (update_id, owner_id, update_name, start_date, end_date, status, reward_type, reward_amount, notes, created_at)
    values ('up_1793540102526', v_owner_id, 'TEST', '2026-11-01'::date, '2026-11-02'::date, 'Active', 'DM', 125, '', now())
    on conflict (update_id) do update set
        update_name = excluded.update_name,
        start_date = excluded.start_date,
        end_date = excluded.end_date,
        status = excluded.status,
        notes = excluded.notes;

    -- 5. Import claims (68 rows)
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1', v_owner_id, 'up_oct26', 'acc_w1', 'b_works', 'Eligible', 'Claimed', 'DM', 100, '2026-10-25'::timestamptz, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_2', v_owner_id, 'up_oct26', 'acc_w2', 'b_works', 'Eligible', 'Claimed', 'DM', 100, '2026-10-25'::timestamptz, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_3', v_owner_id, 'up_oct26', 'acc_a110', 'b_amazon', 'Eligible', 'Claimed', 'DM', 500, '2026-10-26'::timestamptz, 'Bonus 500 DM claim', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_w3_c7iay', v_owner_id, 'up_oct26', 'acc_w3', 'b_works', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s1_96b4n', v_owner_id, 'up_oct26', 'acc_s1', 'b_school', 'Eligible', 'Claimed', 'DM', 100, '2026-11-01'::timestamptz, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s2_shof1', v_owner_id, 'up_oct26', 'acc_s2', 'b_school', 'Eligible', 'Claimed', 'DM', 100, '2026-11-01'::timestamptz, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s3_ylwn2', v_owner_id, 'up_oct26', 'acc_s3', 'b_school', 'Eligible', 'Claimed', 'DM', 100, '2026-11-01'::timestamptz, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s4_0up3p', v_owner_id, 'up_oct26', 'acc_s4', 'b_school', 'Eligible', 'Claimed', 'DM', 0, '2026-11-01'::timestamptz, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s5_jxiwb', v_owner_id, 'up_oct26', 'acc_s5', 'b_school', 'Eligible', 'Claimed', 'DM', 0, '2026-11-01'::timestamptz, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s6_tbk37', v_owner_id, 'up_oct26', 'acc_s6', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s7_raw9a', v_owner_id, 'up_oct26', 'acc_s7', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s8_4trd5', v_owner_id, 'up_oct26', 'acc_s8', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s9_a10v6', v_owner_id, 'up_oct26', 'acc_s9', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s10_cciab', v_owner_id, 'up_oct26', 'acc_s10', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s11_csk31', v_owner_id, 'up_oct26', 'acc_s11', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_s12_u0kvw', v_owner_id, 'up_oct26', 'acc_s12', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_a104_vs2k4', v_owner_id, 'up_oct26', 'acc_a104', 'b_amazon', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205085_acc_a105_4iugw', v_owner_id, 'up_oct26', 'acc_a105', 'b_amazon', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_a111_fa7t0', v_owner_id, 'up_oct26', 'acc_a111', 'b_amazon', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_a_extra_1_nylr4', v_owner_id, 'up_oct26', 'acc_a_extra_1', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_a_extra_2_ieuho', v_owner_id, 'up_oct26', 'acc_a_extra_2', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_a_extra_3_qvjm5', v_owner_id, 'up_oct26', 'acc_a_extra_3', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_a_extra_4_cy7n0', v_owner_id, 'up_oct26', 'acc_a_extra_4', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_a_extra_5_trchz', v_owner_id, 'up_oct26', 'acc_a_extra_5', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_a_extra_6_5dmrp', v_owner_id, 'up_oct26', 'acc_a_extra_6', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_a_extra_7_p6yi6', v_owner_id, 'up_oct26', 'acc_a_extra_7', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_m1_djwds', v_owner_id, 'up_oct26', 'acc_m1', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_m2_4jml5', v_owner_id, 'up_oct26', 'acc_m2', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_m3_wc8x3', v_owner_id, 'up_oct26', 'acc_m3', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_m4_odc6r', v_owner_id, 'up_oct26', 'acc_m4', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_m5_psgz5', v_owner_id, 'up_oct26', 'acc_m5', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_m6_pib0k', v_owner_id, 'up_oct26', 'acc_m6', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539205086_acc_m7_djauz', v_owner_id, 'up_oct26', 'acc_m7', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793539850696_acc_1793539815820_xeqmw', v_owner_id, 'up_oct26', 'acc_1793539815820', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102530_acc_w1_hhctg', v_owner_id, 'up_1793540102526', 'acc_w1', 'b_works', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102530_acc_w2_hj0st', v_owner_id, 'up_1793540102526', 'acc_w2', 'b_works', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102530_acc_w3_f3ke2', v_owner_id, 'up_1793540102526', 'acc_w3', 'b_works', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102530_acc_s1_muf7t', v_owner_id, 'up_1793540102526', 'acc_s1', 'b_school', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102531_acc_s2_0pyd7', v_owner_id, 'up_1793540102526', 'acc_s2', 'b_school', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102531_acc_s3_0xp0e', v_owner_id, 'up_1793540102526', 'acc_s3', 'b_school', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102531_acc_s4_m4wc6', v_owner_id, 'up_1793540102526', 'acc_s4', 'b_school', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102531_acc_s5_bnlxu', v_owner_id, 'up_1793540102526', 'acc_s5', 'b_school', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102531_acc_s6_ucyiw', v_owner_id, 'up_1793540102526', 'acc_s6', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102531_acc_s7_0874z', v_owner_id, 'up_1793540102526', 'acc_s7', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102531_acc_s8_o979a', v_owner_id, 'up_1793540102526', 'acc_s8', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102531_acc_s9_ma2f8', v_owner_id, 'up_1793540102526', 'acc_s9', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102531_acc_s10_maxg8', v_owner_id, 'up_1793540102526', 'acc_s10', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102532_acc_s11_5n2s1', v_owner_id, 'up_1793540102526', 'acc_s11', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102532_acc_s12_vikux', v_owner_id, 'up_1793540102526', 'acc_s12', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102532_acc_a104_r7e1j', v_owner_id, 'up_1793540102526', 'acc_a104', 'b_amazon', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102532_acc_a105_f0dy1', v_owner_id, 'up_1793540102526', 'acc_a105', 'b_amazon', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102533_acc_a111_yldgl', v_owner_id, 'up_1793540102526', 'acc_a111', 'b_amazon', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102533_acc_a110_snod8', v_owner_id, 'up_1793540102526', 'acc_a110', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102533_acc_a_extra_1_j9bvw', v_owner_id, 'up_1793540102526', 'acc_a_extra_1', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102533_acc_a_extra_2_q8td1', v_owner_id, 'up_1793540102526', 'acc_a_extra_2', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102533_acc_a_extra_3_ib9ek', v_owner_id, 'up_1793540102526', 'acc_a_extra_3', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102533_acc_a_extra_4_ux60c', v_owner_id, 'up_1793540102526', 'acc_a_extra_4', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102533_acc_a_extra_5_64j83', v_owner_id, 'up_1793540102526', 'acc_a_extra_5', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102534_acc_a_extra_6_bxtj7', v_owner_id, 'up_1793540102526', 'acc_a_extra_6', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102534_acc_a_extra_7_w28sc', v_owner_id, 'up_1793540102526', 'acc_a_extra_7', 'b_amazon', 'Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102534_acc_m1_4s8ju', v_owner_id, 'up_1793540102526', 'acc_m1', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102534_acc_m2_eu0i3', v_owner_id, 'up_1793540102526', 'acc_m2', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102534_acc_m3_xkk6b', v_owner_id, 'up_1793540102526', 'acc_m3', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102534_acc_m4_zp2bp', v_owner_id, 'up_1793540102526', 'acc_m4', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102534_acc_m5_boni3', v_owner_id, 'up_1793540102526', 'acc_m5', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102535_acc_m6_uupaa', v_owner_id, 'up_1793540102526', 'acc_m6', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102535_acc_m7_52rz4', v_owner_id, 'up_1793540102526', 'acc_m7', 'b_main', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values ('cl_1793540102535_acc_1793539815820_zlign', v_owner_id, 'up_1793540102526', 'acc_1793539815820', 'b_school', 'Not Eligible', 'Pending', 'DM', 0, null, '', now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;

    -- 6. Import account_sources (3 rows)
    insert into public.account_sources (source_id, owner_id, account_id, source_type, nominal, bonus_amount, total_received, received_at, notes, created_at)
    values ('src_1', v_owner_id, 'acc_w1', 'DM', 212, 0, 212, '2026-10-12'::date, 'Activity gift', now())
    on conflict (source_id) do update set
        nominal = excluded.nominal,
        bonus_amount = excluded.bonus_amount,
        total_received = excluded.total_received,
        received_at = excluded.received_at,
        notes = excluded.notes;
    insert into public.account_sources (source_id, owner_id, account_id, source_type, nominal, bonus_amount, total_received, received_at, notes, created_at)
    values ('src_2', v_owner_id, 'acc_w1', 'Top-up', 100, 100, 200, '2026-10-05'::date, 'First topup double', now())
    on conflict (source_id) do update set
        nominal = excluded.nominal,
        bonus_amount = excluded.bonus_amount,
        total_received = excluded.total_received,
        received_at = excluded.received_at,
        notes = excluded.notes;
    insert into public.account_sources (source_id, owner_id, account_id, source_type, nominal, bonus_amount, total_received, received_at, notes, created_at)
    values ('src_3', v_owner_id, 'acc_a110', 'DM', 500, 0, 500, '2026-10-10'::date, 'Initial DM', now())
    on conflict (source_id) do update set
        nominal = excluded.nominal,
        bonus_amount = excluded.bonus_amount,
        total_received = excluded.total_received,
        received_at = excluded.received_at,
        notes = excluded.notes;

    -- 7. Import account_topups (3 rows)
    insert into public.account_topups (topup_id, owner_id, account_id, nominal, bonus_status, bonus_amount, total_received, topup_date, bonus_claim_date, notes, created_at)
    values ('tp_1', v_owner_id, 'acc_w1', 100, 'Claimed', 100, 200, '2026-10-05'::date, '2026-10-05'::date, 'First Topup Double Bonus Claimed', now())
    on conflict (topup_id) do update set
        nominal = excluded.nominal,
        bonus_status = excluded.bonus_status,
        bonus_amount = excluded.bonus_amount,
        total_received = excluded.total_received,
        topup_date = excluded.topup_date,
        bonus_claim_date = excluded.bonus_claim_date,
        notes = excluded.notes;
    insert into public.account_topups (topup_id, owner_id, account_id, nominal, bonus_status, bonus_amount, total_received, topup_date, bonus_claim_date, notes, created_at)
    values ('tp_2', v_owner_id, 'acc_w2', 100, 'Available', 0, 100, '2026-10-06'::date, null, 'Bonus double available', now())
    on conflict (topup_id) do update set
        nominal = excluded.nominal,
        bonus_status = excluded.bonus_status,
        bonus_amount = excluded.bonus_amount,
        total_received = excluded.total_received,
        topup_date = excluded.topup_date,
        bonus_claim_date = excluded.bonus_claim_date,
        notes = excluded.notes;
    insert into public.account_topups (topup_id, owner_id, account_id, nominal, bonus_status, bonus_amount, total_received, topup_date, bonus_claim_date, notes, created_at)
    values ('tp_3', v_owner_id, 'acc_a110', 500, 'Claimed', 500, 1000, '2026-10-10'::date, '2026-10-10'::date, 'Large topup claim', now())
    on conflict (topup_id) do update set
        nominal = excluded.nominal,
        bonus_status = excluded.bonus_status,
        bonus_amount = excluded.bonus_amount,
        total_received = excluded.total_received,
        topup_date = excluded.topup_date,
        bonus_claim_date = excluded.bonus_claim_date,
        notes = excluded.notes;

    -- 8. Import vc_transactions (2 rows)
    insert into public.vc_transactions (transaction_id, owner_id, account_id, source, vc_earned, vc_spent, transaction_date, description, created_at)
    values ('vctx_1', v_owner_id, null, 'Update Reward', 100, 0, '2026-10-25'::date, 'October 2026 Update Completion', now())
    on conflict (transaction_id) do update set
        source = excluded.source,
        vc_earned = excluded.vc_earned,
        vc_spent = excluded.vc_spent,
        transaction_date = excluded.transaction_date,
        description = excluded.description;
    insert into public.vc_transactions (transaction_id, owner_id, account_id, source, vc_earned, vc_spent, transaction_date, description, created_at)
    values ('vctx_2', v_owner_id, null, 'Quest Reward', 250, 0, '2026-10-28'::date, 'Weekly Boss Event Quest', now())
    on conflict (transaction_id) do update set
        source = excluded.source,
        vc_earned = excluded.vc_earned,
        vc_spent = excluded.vc_spent,
        transaction_date = excluded.transaction_date,
        description = excluded.description;

    -- 9. Import activity_logs (43 rows)
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540470344', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_a_extra_4', '{"account_id":"acc_a_extra_4","branch_id":"b_amazon","server_code":"XCX 115","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_a_extra_4","branch_id":"b_amazon","server_code":"XCX 109","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:41:10'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540460470', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_a_extra_5', '{"account_id":"acc_a_extra_5","branch_id":"b_amazon","server_code":"XCX 116","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_a_extra_5","branch_id":"b_amazon","server_code":"XCX 108","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:41:00'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540451360', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_a_extra_7', '{"account_id":"acc_a_extra_7","branch_id":"b_amazon","server_code":"XCX 106","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_a_extra_7","branch_id":"b_amazon","server_code":"XCX 106","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:40:51'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540446301', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_a_extra_6', '{"account_id":"acc_a_extra_6","branch_id":"b_amazon","server_code":"XCX 117","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_a_extra_6","branch_id":"b_amazon","server_code":"XCX 107","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:40:46'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540430870', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_a_extra_7', '{"account_id":"acc_a_extra_7","branch_id":"b_amazon","server_code":"XCX 118","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_a_extra_7","branch_id":"b_amazon","server_code":"XCX 106","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:40:30'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540387777', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_a105', '{"account_id":"acc_a105","branch_id":"b_amazon","server_code":"XCX 105","level":6,"status":"Failed","auto_level_result":"Failed","notes":"Gagal auto-level di level 6","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_a105","branch_id":"b_amazon","server_code":"XCX 105","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:39:47'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540102526', v_owner_id, 'CREATE_UPDATE_PERIOD', 'UpdatePeriod', 'up_1793540102526', 'null'::jsonb, '{"update_id":"up_1793540102526","update_name":"TEST","start_date":"2026-11-01","end_date":"2026-11-02","status":"Open","notes":""}'::jsonb, coalesce('2026-11-01 13:35:02'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540055558', v_owner_id, 'RECORD_CLAIM', 'Claim', 'cl_1793539205085_acc_s3_ylwn2', '{"claim_id":"cl_1793539205085_acc_s3_ylwn2","update_id":"up_oct26","account_id":"acc_s3","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":0,"claimed_at":"2026-11-01","notes":""}'::jsonb, '{"claim_id":"cl_1793539205085_acc_s3_ylwn2","update_id":"up_oct26","account_id":"acc_s3","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":100,"claimed_at":"2026-11-01","notes":""}'::jsonb, coalesce('2026-11-01 13:34:15'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540022689', v_owner_id, 'BULK_MARK_CLAIMED', 'Claim', 'cl_1793539205085_acc_s5_jxiwb', '{"claim_id":"cl_1793539205085_acc_s5_jxiwb","update_id":"up_oct26","account_id":"acc_s5","eligibility_status":"Eligible","claim_status":"Pending","dm_claimed":0,"claimed_at":"","notes":""}'::jsonb, '{"claim_id":"cl_1793539205085_acc_s5_jxiwb","update_id":"up_oct26","account_id":"acc_s5","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":0,"claimed_at":"2026-11-01","notes":""}'::jsonb, coalesce('2026-11-01 13:33:42'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540022689', v_owner_id, 'BULK_MARK_CLAIMED', 'Claim', 'cl_1793539205085_acc_s4_0up3p', '{"claim_id":"cl_1793539205085_acc_s4_0up3p","update_id":"up_oct26","account_id":"acc_s4","eligibility_status":"Eligible","claim_status":"Pending","dm_claimed":0,"claimed_at":"","notes":""}'::jsonb, '{"claim_id":"cl_1793539205085_acc_s4_0up3p","update_id":"up_oct26","account_id":"acc_s4","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":0,"claimed_at":"2026-11-01","notes":""}'::jsonb, coalesce('2026-11-01 13:33:42'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793540022689', v_owner_id, 'BULK_MARK_CLAIMED', 'Claim', 'cl_1793539205085_acc_s3_ylwn2', '{"claim_id":"cl_1793539205085_acc_s3_ylwn2","update_id":"up_oct26","account_id":"acc_s3","eligibility_status":"Eligible","claim_status":"Pending","dm_claimed":0,"claimed_at":"","notes":""}'::jsonb, '{"claim_id":"cl_1793539205085_acc_s3_ylwn2","update_id":"up_oct26","account_id":"acc_s3","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":0,"claimed_at":"2026-11-01","notes":""}'::jsonb, coalesce('2026-11-01 13:33:42'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539949466', v_owner_id, 'RECORD_CLAIM', 'Claim', 'cl_1793539205085_acc_s2_shof1', '{"claim_id":"cl_1793539205085_acc_s2_shof1","update_id":"up_oct26","account_id":"acc_s2","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":0,"claimed_at":"2026-11-01","notes":""}'::jsonb, '{"claim_id":"cl_1793539205085_acc_s2_shof1","update_id":"up_oct26","account_id":"acc_s2","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":100,"claimed_at":"2026-11-01","notes":""}'::jsonb, coalesce('2026-11-01 13:32:29'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539938417', v_owner_id, 'RECORD_CLAIM', 'Claim', 'cl_1793539205085_acc_s1_96b4n', '{"claim_id":"cl_1793539205085_acc_s1_96b4n","update_id":"up_oct26","account_id":"acc_s1","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":0,"claimed_at":"2026-11-01","notes":""}'::jsonb, '{"claim_id":"cl_1793539205085_acc_s1_96b4n","update_id":"up_oct26","account_id":"acc_s1","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":100,"claimed_at":"2026-11-01","notes":""}'::jsonb, coalesce('2026-11-01 13:32:18'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539922676', v_owner_id, 'BULK_MARK_CLAIMED', 'Claim', 'cl_1793539205085_acc_s2_shof1', '{"claim_id":"cl_1793539205085_acc_s2_shof1","update_id":"up_oct26","account_id":"acc_s2","eligibility_status":"Eligible","claim_status":"Pending","dm_claimed":0,"claimed_at":"","notes":""}'::jsonb, '{"claim_id":"cl_1793539205085_acc_s2_shof1","update_id":"up_oct26","account_id":"acc_s2","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":0,"claimed_at":"2026-11-01","notes":""}'::jsonb, coalesce('2026-11-01 13:32:02'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539922676', v_owner_id, 'BULK_MARK_CLAIMED', 'Claim', 'cl_1793539205085_acc_s1_96b4n', '{"claim_id":"cl_1793539205085_acc_s1_96b4n","update_id":"up_oct26","account_id":"acc_s1","eligibility_status":"Eligible","claim_status":"Pending","dm_claimed":0,"claimed_at":"","notes":""}'::jsonb, '{"claim_id":"cl_1793539205085_acc_s1_96b4n","update_id":"up_oct26","account_id":"acc_s1","eligibility_status":"Eligible","claim_status":"Claimed","dm_claimed":0,"claimed_at":"2026-11-01","notes":""}'::jsonb, coalesce('2026-11-01 13:32:02'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539815820', v_owner_id, 'CREATE_ACCOUNT', 'Account', 'acc_1793539815820', 'null'::jsonb, '{"account_id":"acc_1793539815820","branch_id":"b_school","server_code":"UN 09","level":1,"status":"Pre-farm","auto_level_result":"Untested","notes":"","created_at":"2026-11-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:30:15'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539802020', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s12', '{"account_id":"acc_s12","branch_id":"b_school","server_code":"XCX 22","level":4,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s12","branch_id":"b_school","server_code":"UN 08","level":1,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:30:02'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539788548', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s11', '{"account_id":"acc_s11","branch_id":"b_school","server_code":"UN 08","level":1,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_s11","branch_id":"b_school","server_code":"UN 07","level":1,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:29:48'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539782580', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s11', '{"account_id":"acc_s11","branch_id":"b_school","server_code":"XCX 21","level":4,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s11","branch_id":"b_school","server_code":"UN 08","level":1,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:29:42'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539765894', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s10', '{"account_id":"acc_s10","branch_id":"b_school","server_code":"XCX 20","level":4,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s10","branch_id":"b_school","server_code":"UN 06","level":1,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:29:25'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539751793', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s9', '{"account_id":"acc_s9","branch_id":"b_school","server_code":"XCX 19","level":4,"status":"Farming","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s9","branch_id":"b_school","server_code":"UN 05","level":1,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:29:11'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539738786', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s8', '{"account_id":"acc_s8","branch_id":"b_school","server_code":"XCX 18","level":4,"status":"Farming","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s8","branch_id":"b_school","server_code":"UN 03","level":1,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:28:58'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539724424', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s6', '{"account_id":"acc_s6","branch_id":"b_school","server_code":"UN 01","level":4,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_s6","branch_id":"b_school","server_code":"UN 01","level":1,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:28:44'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539718823', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s7', '{"account_id":"acc_s7","branch_id":"b_school","server_code":"XCX 17","level":4,"status":"Farming","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s7","branch_id":"b_school","server_code":"UN 02","level":1,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:28:38'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539707872', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s6', '{"account_id":"acc_s6","branch_id":"b_school","server_code":"XCX 16","level":4,"status":"Farming","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s6","branch_id":"b_school","server_code":"UN 01","level":4,"status":"Pre-farm","auto_level_result":"Untested","notes":"Akun belum dinamai detail","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:28:27'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539591166', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s5', '{"account_id":"acc_s5","branch_id":"b_school","server_code":"XCX 15","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s5","branch_id":"b_school","server_code":"XCX 006","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:26:31'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539564668', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s4', '{"account_id":"acc_s4","branch_id":"b_school","server_code":"XCX 14","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s4","branch_id":"b_school","server_code":"XCX 005","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:26:04'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539552042', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s3', '{"account_id":"acc_s3","branch_id":"b_school","server_code":"XCX 13","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s3","branch_id":"b_school","server_code":"XCX 004","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:25:52'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539534968', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s2', '{"account_id":"acc_s2","branch_id":"b_school","server_code":"XCX 003","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_s2","branch_id":"b_school","server_code":"XCX 003","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:25:34'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539525688', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s1', '{"account_id":"acc_s1","branch_id":"b_school","server_code":"XCX 001","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_s1","branch_id":"b_school","server_code":"XCX 001","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:25:25'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539516957', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s2', '{"account_id":"acc_s2","branch_id":"b_school","server_code":"XCX 12","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s2","branch_id":"b_school","server_code":"XCX 003","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:25:16'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539487230', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_s1', '{"account_id":"acc_s1","branch_id":"b_school","server_code":"XCX 11","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_s1","branch_id":"b_school","server_code":"XCX 001","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:24:47'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539465731', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_w1', '{"account_id":"acc_w1","branch_id":"b_works","server_code":"XCX 002","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_w1","branch_id":"b_works","server_code":"XCX 002","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:24:25'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539458483', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_w2', '{"account_id":"acc_w2","branch_id":"b_works","server_code":"XCX 007","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_w2","branch_id":"b_works","server_code":"XCX 007","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:24:18'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539452408', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_w3', '{"account_id":"acc_w3","branch_id":"b_works","server_code":"XCX 008","level":8,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_w3","branch_id":"b_works","server_code":"XCX 008","level":23,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:24:12'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539377222', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_w3', '{"account_id":"acc_w3","branch_id":"b_works","server_code":"XCX 003","level":8,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_w3","branch_id":"b_works","server_code":"XCX 008","level":8,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:22:57'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539372283', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_w2', '{"account_id":"acc_w2","branch_id":"b_works","server_code":"XCX 002","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_w2","branch_id":"b_works","server_code":"XCX 007","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:22:52'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539366246', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_w1', '{"account_id":"acc_w1","branch_id":"b_works","server_code":"XCX 001","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_w1","branch_id":"b_works","server_code":"XCX 002","level":10,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:22:46'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539336493', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_w3', '{"account_id":"acc_w3","branch_id":"b_works","server_code":"XCX 003","level":8,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_w3","branch_id":"b_works","server_code":"XCX 003","level":8,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:22:16'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539326023', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_w3', '{"account_id":"acc_w3","branch_id":"b_works","server_code":"XCX 003","level":8,"status":"Ready","auto_level_result":"Untested","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, '{"account_id":"acc_w3","branch_id":"b_works","server_code":"XCX 003","level":8,"status":"Ready","auto_level_result":"Success","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:22:06'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539317950', v_owner_id, 'UPDATE_ACCOUNT', 'Account', 'acc_w3', '{"account_id":"acc_w3","branch_id":"b_works","server_code":"XCX 003","level":8,"status":"Farming","auto_level_result":"Untested","notes":"","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"account_id":"acc_w3","branch_id":"b_works","server_code":"XCX 003","level":8,"status":"Ready","auto_level_result":"Untested","notes":"","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:21:57'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_1793539087983', v_owner_id, 'UPDATE_BRANCH', 'Branch', 'b_works', '{"branch_id":"b_works","branch_name":"@works","email_login":"works_admin@xcx.com","status":"Active","notes":"Akun tercatat cabang works","created_at":"2026-10-01","updated_at":"2026-10-31"}'::jsonb, '{"branch_id":"b_works","branch_name":"@works","email_login":"muftidoworks@gmail.com","status":"Active","notes":"cabang 1","created_at":"2026-10-01","updated_at":"2026-11-01"}'::jsonb, coalesce('2026-11-01 13:18:07'::timestamptz, now()))
    on conflict (log_id) do nothing;
    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values ('log_init', v_owner_id, 'SYSTEM_INIT_V1_2', 'System', '0', null, '"Initialized PRD v1.2 Account Source & Reward Tracking"'::jsonb, coalesce('2026-11-01 09:00:00'::timestamptz, now()))
    on conflict (log_id) do nothing;

    -- 10. Update settings with owner_id
    insert into public.settings (key, owner_id, value, description)
    values
        ('bbc_to_diamond_rate', v_owner_id, '5'::jsonb, 'Number of BBCoins per 1 diamond'),
        ('vc_to_diamond_rate', v_owner_id, '1'::jsonb, 'Number of VC per 1 diamond'),
        ('dm_to_bbc_rate', v_owner_id, '1'::jsonb, 'Number of BBCoin per 1 DM'),
        ('monthly_tracking_start', v_owner_id, '"2026-11-01"'::jsonb, 'Starting month for monthly totals calculations'),
        ('schema_version', v_owner_id, '3'::jsonb, 'Current schema version')
    on conflict (owner_id, key) do update set value = excluded.value;

    -- 11. Count imported rows
    select count(*) into v_count_branches from public.branches where owner_id = v_owner_id;
    select count(*) into v_count_accounts from public.accounts where owner_id = v_owner_id;
    select count(*) into v_count_updates from public.updates where owner_id = v_owner_id;
    select count(*) into v_count_claims from public.claims where owner_id = v_owner_id;
    select count(*) into v_count_sources from public.account_sources where owner_id = v_owner_id;
    select count(*) into v_count_topups from public.account_topups where owner_id = v_owner_id;
    select count(*) into v_count_vc from public.vc_transactions where owner_id = v_owner_id;
    select count(*) into v_count_logs from public.activity_logs where owner_id = v_owner_id;

    -- Fetch calculated totals
    select * into v_global from public.v_global_totals where owner_id = v_owner_id;

    raise notice '==================================================';
    raise notice 'RECONCILIATION SUMMARY FOR OWNER: %', v_owner_id;
    raise notice 'Branches imported: %', v_count_branches;
    raise notice 'Accounts imported: %', v_count_accounts;
    raise notice 'Updates imported: %', v_count_updates;
    raise notice 'Claims imported: %', v_count_claims;
    raise notice 'Sources imported: %', v_count_sources;
    raise notice 'Topups imported: %', v_count_topups;
    raise notice 'VC Transactions imported: %', v_count_vc;
    raise notice 'Activity Logs imported: %', v_count_logs;
    raise notice '--------------------------------------------------';
    raise notice 'Calculated Total DM: % (Expected: 3212)', v_global.total_dm;
    raise notice 'Calculated Total VC: % (Expected: 350)', v_global.total_vc_balance;
    raise notice 'Calculated Estimated Diamonds: %', v_global.estimated_diamonds;
    raise notice '==================================================';
end $$;
