// scripts/generate_seed_sql.js
import fs from 'fs';

const raw = fs.readFileSync('backup/xcx_bbc_backup_2026-11-01T13-43-55-466Z.json', 'utf8');
const data = JSON.parse(raw);

const rejects = [];

function escDate(val) {
    if (!val || String(val).trim() === '') return 'null';
    return "'" + String(val).trim().replace(/'/g, "''") + "'::date";
}

function escTimestamptz(val) {
    if (!val || String(val).trim() === '') return 'null';
    return "'" + String(val).trim().replace(/'/g, "''") + "'::timestamptz";
}

function escStr(str) {
    if (str === null || str === undefined) return 'null';
    return "'" + String(str).replace(/'/g, "''") + "'";
}

function escJson(val) {
    if (val === null || val === undefined) return 'null';
    if (typeof val === 'string') {
        const trimmed = val.trim();
        if (trimmed === '') return 'null';
        try {
            const parsed = JSON.parse(trimmed);
            return "'" + JSON.stringify(parsed).replace(/'/g, "''") + "'::jsonb";
        } catch {
            // Plain text string: wrap as valid JSON string
            return "'" + JSON.stringify(trimmed).replace(/'/g, "''") + "'::jsonb";
        }
    }
    return "'" + JSON.stringify(val).replace(/'/g, "''") + "'::jsonb";
}

let sql = `-- ============================================================================
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

    -- 2. Import branches (${data.branches.length} rows)
`;

// Branches
for (const b of data.branches) {
    sql += `    insert into public.branches (branch_id, owner_id, branch_name, email_login, status, notes, created_at)
    values (${escStr(b.branch_id)}, v_owner_id, ${escStr(b.branch_name)}, ${escStr(b.email_login)}, ${escStr(b.status || 'Active')}, ${escStr(b.notes)}, coalesce(${escTimestamptz(b.created_at)}, now()))
    on conflict (branch_id) do update set
        branch_name = excluded.branch_name,
        email_login = excluded.email_login,
        status = excluded.status,
        notes = excluded.notes;
`;
}

sql += `\n    -- 3. Import accounts (${data.accounts.length} rows)\n`;

// Accounts map for branch lookup
const accountBranchMap = {};
for (const a of data.accounts) {
    accountBranchMap[a.account_id] = a.branch_id;
    sql += `    insert into public.accounts (account_id, owner_id, branch_id, server_code, level, status, auto_level_result, notes, created_at)
    values (${escStr(a.account_id)}, v_owner_id, ${escStr(a.branch_id)}, ${escStr(a.server_code)}, ${Number(a.level) || 1}, ${escStr(a.status || 'Pre-farm')}, ${escStr(a.auto_level_result || 'Untested')}, ${escStr(a.notes)}, coalesce(${escTimestamptz(a.created_at)}, now()))
    on conflict (account_id) do update set
        branch_id = excluded.branch_id,
        server_code = excluded.server_code,
        level = excluded.level,
        status = excluded.status,
        auto_level_result = excluded.auto_level_result,
        notes = excluded.notes;
`;
}

sql += `\n    -- 4. Import updates (${data.updates.length} rows)\n`;

for (const u of data.updates) {
    const patchStatus = (u.status === 'Open' || u.status === 'Active') ? 'Active' : (u.status || 'Active');
    sql += `    insert into public.updates (update_id, owner_id, update_name, start_date, end_date, status, reward_type, reward_amount, notes, created_at)
    values (${escStr(u.update_id)}, v_owner_id, ${escStr(u.update_name)}, ${escDate(u.start_date)}, ${escDate(u.end_date)}, ${escStr(patchStatus)}, 'DM', 125, ${escStr(u.notes)}, now())
    on conflict (update_id) do update set
        update_name = excluded.update_name,
        start_date = excluded.start_date,
        end_date = excluded.end_date,
        status = excluded.status,
        notes = excluded.notes;
`;
}

sql += `\n    -- 5. Import claims (${data.claims.length} rows)\n`;

for (const c of data.claims) {
    const branchId = accountBranchMap[c.account_id] || null;
    const isClaimed = c.claim_status === 'Claimed';
    const amountClaimed = isClaimed ? (Number(c.dm_claimed) || 0) : 0;
    const claimedAt = isClaimed ? (c.claimed_at ? `${escTimestamptz(c.claimed_at)}` : 'now()') : 'null';
    const normElig = (c.eligibility_status && c.eligibility_status.toLowerCase() === 'not eligible') ? 'Not Eligible' : 'Eligible';

    sql += `    insert into public.claims (claim_id, owner_id, update_id, account_id, branch_id_at_claim, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes, created_at)
    values (${escStr(c.claim_id)}, v_owner_id, ${escStr(c.update_id)}, ${escStr(c.account_id)}, ${escStr(branchId)}, ${escStr(normElig)}, ${escStr(c.claim_status || 'Pending')}, 'DM', ${amountClaimed}, ${claimedAt}, ${escStr(c.notes)}, now())
    on conflict (claim_id) do update set
        branch_id_at_claim = excluded.branch_id_at_claim,
        eligibility_status = excluded.eligibility_status,
        claim_status = excluded.claim_status,
        reward_amount_claimed = excluded.reward_amount_claimed,
        claimed_at = excluded.claimed_at,
        notes = excluded.notes;
`;
}

sql += `\n    -- 6. Import account_sources (${data.account_sources.length} rows)\n`;

for (const s of data.account_sources) {
    const totalRec = Number(s.total_received) || Number(s.nominal) || 0;
    sql += `    insert into public.account_sources (source_id, owner_id, account_id, source_type, nominal, bonus_amount, total_received, received_at, notes, created_at)
    values (${escStr(s.source_id)}, v_owner_id, ${escStr(s.account_id)}, ${escStr(s.source_type)}, ${Number(s.nominal) || 0}, ${Number(s.bonus_amount) || 0}, ${totalRec}, ${escDate(s.received_at)}, ${escStr(s.notes)}, now())
    on conflict (source_id) do update set
        nominal = excluded.nominal,
        bonus_amount = excluded.bonus_amount,
        total_received = excluded.total_received,
        received_at = excluded.received_at,
        notes = excluded.notes;
`;
}

sql += `\n    -- 7. Import account_topups (${data.account_topups.length} rows)\n`;

for (const t of data.account_topups) {
    const totalRec = Number(t.total_received) || Number(t.nominal) || 0;
    sql += `    insert into public.account_topups (topup_id, owner_id, account_id, nominal, bonus_status, bonus_amount, total_received, topup_date, bonus_claim_date, notes, created_at)
    values (${escStr(t.topup_id)}, v_owner_id, ${escStr(t.account_id)}, ${Number(t.nominal) || 0}, ${escStr(t.bonus_status || 'None')}, ${Number(t.bonus_amount) || 0}, ${totalRec}, ${escDate(t.topup_date)}, ${escDate(t.bonus_claim_date)}, ${escStr(t.notes)}, now())
    on conflict (topup_id) do update set
        nominal = excluded.nominal,
        bonus_status = excluded.bonus_status,
        bonus_amount = excluded.bonus_amount,
        total_received = excluded.total_received,
        topup_date = excluded.topup_date,
        bonus_claim_date = excluded.bonus_claim_date,
        notes = excluded.notes;
`;
}

sql += `\n    -- 8. Import vc_transactions (${data.vc_transactions.length} rows)\n`;

for (const v of data.vc_transactions) {
    const txDate = v.transaction_date || v.date || '2026-10-25';
    sql += `    insert into public.vc_transactions (transaction_id, owner_id, account_id, source, vc_earned, vc_spent, transaction_date, description, created_at)
    values (${escStr(v.transaction_id)}, v_owner_id, ${escStr(v.account_id)}, ${escStr(v.source)}, ${Number(v.vc_earned) || 0}, ${Number(v.vc_spent) || 0}, ${escDate(txDate)}, ${escStr(v.description)}, now())
    on conflict (transaction_id) do update set
        source = excluded.source,
        vc_earned = excluded.vc_earned,
        vc_spent = excluded.vc_spent,
        transaction_date = excluded.transaction_date,
        description = excluded.description;
`;
}

sql += `\n    -- 9. Import activity_logs (${data.logs.length} rows)\n`;

for (const l of data.logs) {
    sql += `    insert into public.activity_logs (log_id, owner_id, action, entity_type, entity_id, old_value, new_value, created_at)
    values (${escStr(l.log_id)}, v_owner_id, ${escStr(l.action)}, ${escStr(l.entity_type)}, ${escStr(l.entity_id)}, ${escJson(l.old_value)}, ${escJson(l.new_value)}, coalesce(${escTimestamptz(l.created_at)}, now()))
    on conflict (log_id) do nothing;
`;
}

sql += `\n    -- 10. Update settings with owner_id\n`;
sql += `    insert into public.settings (key, owner_id, value, description)
    values
        ('bbc_to_diamond_rate', v_owner_id, '5'::jsonb, 'Number of BBCoins per 1 diamond'),
        ('vc_to_diamond_rate', v_owner_id, '1'::jsonb, 'Number of VC per 1 diamond'),
        ('dm_to_bbc_rate', v_owner_id, '1'::jsonb, 'Number of BBCoin per 1 DM'),
        ('monthly_tracking_start', v_owner_id, '"2026-11-01"'::jsonb, 'Starting month for monthly totals calculations'),
        ('schema_version', v_owner_id, '3'::jsonb, 'Current schema version')
    on conflict (owner_id, key) do update set value = excluded.value;
`;

sql += `
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
`;

fs.writeFileSync('supabase/seed_import.sql', sql);
fs.writeFileSync('reports/import_rejects.json', JSON.stringify(rejects, null, 2));

console.log('Successfully generated supabase/seed_import.sql!');
console.log('Rejects count:', rejects.length);
