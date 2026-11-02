// scripts/test_runner.js
import { PGlite } from '@electric-sql/pglite';
import fs from 'fs';
import path from 'path';

async function run() {
    console.log('--- Initializing Local Postgres 16 (PGlite) ---');
    const db = new PGlite();

    console.log('1. Setting up mock auth schema & roles...');
    await db.exec(`
        create schema if not exists auth;
        create or replace function auth.uid() returns uuid as $$
            select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
        $$ language sql stable;
        do $$
        begin
            if not exists (select from pg_roles where rolname = 'anon') then
                create role anon nologin;
            end if;
            if not exists (select from pg_roles where rolname = 'authenticated') then
                create role authenticated nologin;
            end if;
        end $$;
        grant usage on schema auth to authenticated, anon;
        grant execute on all functions in schema auth to authenticated, anon;
    `);

    const migrations = [
        'supabase/migrations/001_schema.sql',
        'supabase/migrations/002_views.sql',
        'supabase/migrations/003_functions.sql',
        'supabase/migrations/004_rls.sql'
    ];

    for (const m of migrations) {
        console.log(`Applying ${m}...`);
        const sql = fs.readFileSync(m, 'utf8');
        await db.exec(sql);
        console.log(`  -> Applied successfully.`);
    }

    console.log('\n--- Running Test Suite (supabase/tests/01_test_suite.sql) ---');
    const testSql = fs.readFileSync('supabase/tests/01_test_suite.sql', 'utf8');
    // Split on DO $$ or statements
    await db.exec(`
        create temp table if not exists _test_results (
            test_id serial primary key,
            test_group text not null,
            test_name text not null,
            status text not null check (status in ('PASS', 'FAIL')),
            details text
        );
        truncate table _test_results;
    `);

    // Extract DO $$ blocks
    const doBlocks = testSql.match(/do \$\$[\s\S]*?\$\$[\s]*;/gi) || [];
    console.log(`Found ${doBlocks.length} test blocks to execute.`);
    for (let i = 0; i < doBlocks.length; i++) {
        console.log(`Running block ${i + 1}...`);
        try {
            await db.exec(doBlocks[i]);
            console.log(`  -> Block ${i + 1} completed.`);
        } catch (blockErr) {
            console.error(`Error in block ${i + 1}:`, blockErr.message);
            console.error('Block snippet:', doBlocks[i].slice(0, 200));
            throw blockErr;
        }
    }

    const res = await db.query('select test_id, test_group, test_name, status, details from _test_results order by test_id;');

    console.log('\nTest Results Summary:');
    console.table(res.rows);

    const failures = res.rows.filter(r => r.status === 'FAIL');
    if (failures.length > 0) {
        console.error(`\nFAILED ${failures.length} tests!`);
        process.exit(1);
    } else {
        console.log(`\nALL ${res.rows.length} TESTS PASSED!`);
    }

    console.log('\n--- Additional Security & RPC Behavioral Tests ---');

    // 1. RLS Anon Denial Test
    console.log('Testing anon rejection on tables...');
    let anonBlocked = false;
    try {
        await db.exec(`
            set role anon;
            select * from public.branches;
        `);
    } catch (e) {
        anonBlocked = true;
    } finally {
        await db.exec('reset role;');
    }
    console.log(`Anon SELECT rejected: ${anonBlocked ? 'PASS' : 'FAIL'}`);

    // 2. Cross-user isolation test
    console.log('Testing cross-user isolation...');
    const userA = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    const userB = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    await db.exec(`
        select set_config('request.jwt.claim.sub', '${userA}', false);
        set role authenticated;
        insert into public.branches (branch_id, branch_name) values ('b_user_a', 'Branch A');
        reset role;
    `);

    let userBSeesUserA = false;
    await db.exec(`
        select set_config('request.jwt.claim.sub', '${userB}', false);
        set role authenticated;
    `);
    const userBQuery = await db.query('select * from public.branches where branch_id = $1;', ['b_user_a']);
    if (userBQuery.rows.length === 0) {
        console.log('Cross-user isolation (User B cannot see User A rows): PASS');
    } else {
        console.error('Cross-user isolation: FAIL');
        process.exit(1);
    }
    await db.exec('reset role;');

    // 3. Activity logs append-only test (update & delete denied)
    console.log('Testing activity_logs update/delete denial...');
    let logUpdateDenied = false;
    let logDeleteDenied = false;
    await db.exec(`
        select set_config('request.jwt.claim.sub', '${userA}', false);
        set role authenticated;
    `);
    try {
        await db.exec(`update public.activity_logs set action = 'TAMPER' where true;`);
    } catch (e) {
        logUpdateDenied = true;
    }
    try {
        await db.exec(`delete from public.activity_logs where true;`);
    } catch (e) {
        logDeleteDenied = true;
    }
    await db.exec('reset role;');
    console.log(`activity_logs UPDATE denied: ${logUpdateDenied ? 'PASS' : 'FAIL'}`);
    console.log(`activity_logs DELETE denied: ${logDeleteDenied ? 'PASS' : 'FAIL'}`);

    // 4. Bulk claim test: idempotency, skipping archived, patch default reward
    console.log('Testing bulk_claim RPC behavior...');
    await db.exec(`
        select set_config('request.jwt.claim.sub', '${userA}', false);
        set role authenticated;
        insert into public.accounts (account_id, branch_id, status, status_before_archive, archived_at)
        values
            ('acc_uA_1', 'b_user_a', 'Ready', null, null),
            ('acc_uA_arc', 'b_user_a', 'Archived', 'Ready', now());
        select public.create_update('upd_uA_1', 'Update Patch A', null, null, 'DM', 250, 'all_active', null);
    `);
    // Run bulk claim 1st time
    const bc1 = await db.query(`select public.bulk_claim('upd_uA_1', array['acc_uA_1', 'acc_uA_arc']) as res;`);
    console.log('bulk_claim 1st run result:', bc1.rows[0].res);

    // Run bulk claim 2nd time (must be idempotent: updated_count = 0)
    const bc2 = await db.query(`select public.bulk_claim('upd_uA_1', array['acc_uA_1', 'acc_uA_arc']) as res;`);
    console.log('bulk_claim 2nd run result (repeat):', bc2.rows[0].res);
    const claimRecord = await db.query(`select claim_status, reward_amount_claimed from public.claims where update_id = 'upd_uA_1' and account_id = 'acc_uA_1';`);
    console.log('Claimed amount verified (defaults from patch = 250):', claimRecord.rows[0]);

    if (bc1.rows[0].res.updated_count === 1 && bc2.rows[0].res.updated_count === 0 && Number(claimRecord.rows[0].reward_amount_claimed) === 250) {
        console.log('bulk_claim idempotency & default patch reward: PASS');
    } else {
        console.error('bulk_claim verification: FAIL');
        process.exit(1);
    }
    await db.exec('reset role;');

    // 5. Delete account test: removes only account's rows, global VC untouched, negative VC blocked
    console.log('Testing delete_account RPC behavior & negative-VC block...');
    await db.exec(`
        select set_config('request.jwt.claim.sub', '${userA}', false);
        set role authenticated;
        -- Global VC: 50
        insert into public.vc_transactions (transaction_id, account_id, vc_earned, vc_spent)
        values ('vc_glob_uA', null, 50, 0);
        -- Account-linked VC: earned 100, spent 10 (net = 90)
        insert into public.vc_transactions (transaction_id, account_id, vc_earned, vc_spent)
        values ('vc_acc_uA', 'acc_uA_1', 100, 10);
        -- Global VC balance now = 50 + 90 = 140.
        -- If we had a global spend of 100, global VC balance = 40.
        -- Deleting acc_uA_1 (net 90) would make total VC balance = 40 - 90 = -50 (negative!) -> MUST BE BLOCKED!
        insert into public.vc_transactions (transaction_id, account_id, vc_earned, vc_spent)
        values ('vc_glob_spend_uA', null, 0, 100);
    `);

    let deleteBlockedOnNegativeVC = false;
    try {
        await db.query(`select public.delete_account('acc_uA_1');`);
    } catch (e) {
        deleteBlockedOnNegativeVC = e.message.includes('negative');
    }
    console.log(`delete_account blocked on negative resulting VC balance: ${deleteBlockedOnNegativeVC ? 'PASS' : 'FAIL'}`);

    // Now test valid delete_account when VC balance permits
    await db.exec(`
        -- Add global VC buffer so deletion doesn't go negative
        insert into public.vc_transactions (transaction_id, account_id, vc_earned, vc_spent)
        values ('vc_glob_buffer_uA', null, 200, 0);
        select public.delete_account('acc_uA_1');
    `);

    // Verify account deleted, its claims deleted, its VC deleted, but global VC remains!
    const checkAcc = await db.query(`select * from public.accounts where account_id = 'acc_uA_1';`);
    const checkAccVC = await db.query(`select * from public.vc_transactions where account_id = 'acc_uA_1';`);
    const checkGlobVC = await db.query(`select count(*) as cnt from public.vc_transactions where account_id is null;`);
    const checkLog = await db.query(`select action, entity_id from public.activity_logs where action = 'DELETE_ACCOUNT' and entity_id = 'acc_uA_1';`);

    if (checkAcc.rows.length === 0 && checkAccVC.rows.length === 0 && Number(checkGlobVC.rows[0].cnt) === 3 && checkLog.rows.length > 0) {
        console.log('delete_account removes account rows, preserves global VC, writes audit log: PASS');
    } else {
        console.error('delete_account verification: FAIL');
        process.exit(1);
    }

    // 6. Test export_all() RPC
    console.log('\n--- Testing RPC: export_all() ---');
    const exportRes = await db.query('select public.export_all() as backup;');
    const backupJson = exportRes.rows[0].backup;
    console.log('export_all() keys returned:', Object.keys(backupJson));
    if (backupJson.branches && backupJson.accounts && backupJson.updates && backupJson.claims && backupJson.activity_logs) {
        console.log('export_all() complete backup export: PASS');
    } else {
        console.error('export_all() verification: FAIL');
        process.exit(1);
    }

    await db.exec('reset role;');
}

run().catch(err => {
    console.error('Test execution error message:', err.message);
    console.error('Test execution error detail:', err.detail || err.hint || err);
    process.exit(1);
});
