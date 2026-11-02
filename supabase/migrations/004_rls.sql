-- ============================================================================
-- Migration: 004_rls.sql
-- Description: Row Level Security (RLS) enforcement and role permission hardening
-- Down Migration Note:
-- ALTER TABLE public.branches DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.accounts DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.updates DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.claims DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.account_sources DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.account_topups DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.vc_transactions DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.settings DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.activity_logs DISABLE ROW LEVEL SECURITY;
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Enable and Force RLS on all tables
-- ----------------------------------------------------------------------------
alter table public.branches enable row level security;
alter table public.branches force row level security;

alter table public.accounts enable row level security;
alter table public.accounts force row level security;

alter table public.updates enable row level security;
alter table public.updates force row level security;

alter table public.claims enable row level security;
alter table public.claims force row level security;

alter table public.account_sources enable row level security;
alter table public.account_sources force row level security;

alter table public.account_topups enable row level security;
alter table public.account_topups force row level security;

alter table public.vc_transactions enable row level security;
alter table public.vc_transactions force row level security;

alter table public.settings enable row level security;
alter table public.settings force row level security;

alter table public.activity_logs enable row level security;
alter table public.activity_logs force row level security;

-- ----------------------------------------------------------------------------
-- 2. Drop existing policies if any
-- ----------------------------------------------------------------------------
drop policy if exists "branches_authenticated_owner" on public.branches;
drop policy if exists "accounts_authenticated_owner" on public.accounts;
drop policy if exists "updates_authenticated_owner" on public.updates;
drop policy if exists "claims_authenticated_owner" on public.claims;
drop policy if exists "account_sources_authenticated_owner" on public.account_sources;
drop policy if exists "account_topups_authenticated_owner" on public.account_topups;
drop policy if exists "vc_transactions_authenticated_owner" on public.vc_transactions;
drop policy if exists "settings_authenticated_owner" on public.settings;
drop policy if exists "activity_logs_select_owner" on public.activity_logs;
drop policy if exists "activity_logs_insert_owner" on public.activity_logs;

-- ----------------------------------------------------------------------------
-- 3. Policies for Core Tables (Select, Insert, Update, Delete for authenticated)
-- ----------------------------------------------------------------------------
create policy "branches_authenticated_owner"
    on public.branches
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

create policy "accounts_authenticated_owner"
    on public.accounts
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

create policy "updates_authenticated_owner"
    on public.updates
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

create policy "claims_authenticated_owner"
    on public.claims
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

create policy "account_sources_authenticated_owner"
    on public.account_sources
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

create policy "account_topups_authenticated_owner"
    on public.account_topups
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

create policy "vc_transactions_authenticated_owner"
    on public.vc_transactions
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

create policy "settings_authenticated_owner"
    on public.settings
    for all
    to authenticated
    using (owner_id = auth.uid())
    with check (owner_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 4. Policies for activity_logs (Strictly Append-Only: SELECT & INSERT only)
-- NO update or delete policies exist for activity_logs!
-- ----------------------------------------------------------------------------
create policy "activity_logs_select_owner"
    on public.activity_logs
    for select
    to authenticated
    using (owner_id = auth.uid());

create policy "activity_logs_insert_owner"
    on public.activity_logs
    for insert
    to authenticated
    with check (owner_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 5. Revoke default privileges from anon and public, grant to authenticated
-- ----------------------------------------------------------------------------
revoke all on all tables in schema public from anon, public;
revoke all on all routines in schema public from anon, public;
revoke all on all sequences in schema public from anon, public;

-- Grant permissions to authenticated role
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
-- Ensure update and delete remain revoked on activity_logs
revoke update, delete, truncate on public.activity_logs from authenticated, anon, public;

grant select on all sequences in schema public to authenticated;
grant execute on all routines in schema public to authenticated;
