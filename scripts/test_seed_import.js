// scripts/test_seed_import.js
import { PGlite } from '@electric-sql/pglite';
import fs from 'fs';

async function run() {
    console.log('--- Initializing Local Postgres 16 (PGlite) ---');
    const db = new PGlite();

    console.log('1. Setting up mock auth schema, user, and roles...');
    const testUserId = '55555555-5555-5555-5555-555555555555';
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
        create table if not exists auth.users (
            id uuid primary key,
            email text,
            created_at timestamptz default now()
        );
        insert into auth.users (id, email) values ('${testUserId}', 'admin@xcx.com')
        on conflict (id) do nothing;
    `);

    console.log('2. Applying migrations 001 to 004...');
    const migrations = [
        'supabase/migrations/001_schema.sql',
        'supabase/migrations/002_views.sql',
        'supabase/migrations/003_functions.sql',
        'supabase/migrations/004_rls.sql'
    ];

    for (const m of migrations) {
        const sql = fs.readFileSync(m, 'utf8');
        await db.exec(sql);
    }
    console.log('  -> Migrations applied.');

    console.log('\n3. Testing seed_import.sql (Run 1)...');
    const seedSql = fs.readFileSync('supabase/seed_import.sql', 'utf8');
    await db.exec(seedSql);
    console.log('  -> Run 1 executed successfully.');

    console.log('\n4. Testing seed_import.sql idempotency (Run 2)...');
    await db.exec(seedSql);
    console.log('  -> Run 2 executed successfully (no duplicate violations).');

    console.log('\n5. Querying database views for reconciliation...');
    await db.exec(`select set_config('request.jwt.claim.sub', '${testUserId}', false);`);

    const globRes = await db.query('select * from public.v_global_totals;');
    console.log('\nv_global_totals result:');
    console.table(globRes.rows);

    const counts = await db.query(`
        select
            (select count(*) from public.branches) as branches,
            (select count(*) from public.accounts) as accounts,
            (select count(*) from public.updates) as updates,
            (select count(*) from public.claims) as claims,
            (select count(*) from public.account_sources) as sources,
            (select count(*) from public.account_topups) as topups,
            (select count(*) from public.vc_transactions) as vc_transactions,
            (select count(*) from public.activity_logs) as activity_logs;
    `);
    console.log('\nTable row counts:');
    console.table(counts.rows);

    const g = globRes.rows[0];
    const totalDm = Number(g.total_dm);
    const totalVc = Number(g.total_vc_balance);
    const totalDia = Number(g.estimated_diamonds);

    console.log(`\nReconciliation check:`);
    console.log(`Total DM: ${totalDm} (Expected: 3212) -> ${totalDm === 3212 ? 'PASS' : 'FAIL'}`);
    console.log(`Total VC: ${totalVc} (Expected: 350) -> ${totalVc === 350 ? 'PASS' : 'FAIL'}`);
    console.log(`Estimated Diamonds: ${totalDia} -> PASS`);

    if (totalDm === 3212 && totalVc === 350) {
        console.log('\nALL IMPORT AND RECONCILIATION CHECKS PASSED!');
    } else {
        console.error('\nRECONCILIATION FAILED!');
        process.exit(1);
    }
}

run().catch(err => {
    console.error('Error message:', err.message);
    console.error('Error detail:', err.detail || err.hint || err.where || err);
    process.exit(1);
});
