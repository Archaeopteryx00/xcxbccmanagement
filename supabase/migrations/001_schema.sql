-- ============================================================================
-- Migration: 001_schema.sql
-- Description: Core schema tables, constraints, indexes, and initial settings
-- Down Migration Note:
-- DROP TABLE IF EXISTS activity_logs, settings, vc_transactions, account_topups,
--   account_sources, claims, updates, accounts, branches CASCADE;
-- ============================================================================

-- Core schema uses built-in PostgreSQL functions (gen_random_uuid, md5)

-- ----------------------------------------------------------------------------
-- 1. Table: branches
-- ----------------------------------------------------------------------------
create table if not exists public.branches (
    branch_id text primary key,
    owner_id uuid not null default auth.uid(),
    branch_name text not null,
    email_login text,
    status text not null default 'Active' check (status in ('Active', 'Inactive', 'Archived')),
    notes text,
    created_at timestamptz not null default now()
);

-- Unique index for case-insensitive branch_name per owner
create unique index if not exists uq_branches_owner_lower_name
    on public.branches (owner_id, lower(trim(branch_name)));

-- ----------------------------------------------------------------------------
-- 2. Table: accounts
-- ----------------------------------------------------------------------------
create table if not exists public.accounts (
    account_id text primary key,
    owner_id uuid not null default auth.uid(),
    branch_id text not null references public.branches(branch_id) on delete restrict,
    server_code text,
    level integer not null default 1 check (level >= 1),
    status text not null default 'Pre-farm' check (status in ('Pre-farm', 'Farming', 'Ready', 'Failed', 'Archived')),
    status_before_archive text check (status_before_archive is null or status_before_archive in ('Pre-farm', 'Farming', 'Ready', 'Failed')),
    archived_at timestamptz,
    auto_level_result text not null default 'Untested' check (auto_level_result in ('Untested', 'Success', 'Failed')),
    notes text,
    created_at timestamptz not null default now(),
    constraint chk_accounts_archive check (
        (status = 'Archived' and archived_at is not null) or
        (status <> 'Archived')
    )
);

create index if not exists idx_accounts_branch_id on public.accounts(branch_id);
create index if not exists idx_accounts_branch_status on public.accounts(branch_id, status);
create index if not exists idx_accounts_owner_status on public.accounts(owner_id, status);

-- ----------------------------------------------------------------------------
-- 3. Table: updates (patches)
-- ----------------------------------------------------------------------------
create table if not exists public.updates (
    update_id text primary key,
    owner_id uuid not null default auth.uid(),
    update_name text not null,
    start_date date,
    end_date date,
    status text not null default 'Active' check (status in ('Active', 'Closed', 'Archived', 'Draft')),
    reward_type text not null default 'DM' check (reward_type in ('DM', 'VC')),
    reward_amount bigint not null default 0 check (reward_amount >= 0),
    eligibility_rule text not null default 'all_active' check (eligibility_rule in ('all_active', 'ready_only')),
    notes text,
    created_at timestamptz not null default now()
);

create index if not exists idx_updates_owner_status on public.updates(owner_id, status);

-- ----------------------------------------------------------------------------
-- 4. Table: claims
-- ----------------------------------------------------------------------------
create table if not exists public.claims (
    claim_id text primary key,
    owner_id uuid not null default auth.uid(),
    update_id text not null references public.updates(update_id) on delete restrict,
    account_id text not null references public.accounts(account_id) on delete restrict,
    branch_id_at_claim text,
    eligibility_status text not null default 'Eligible' check (eligibility_status in ('Eligible', 'Not Eligible')),
    claim_status text not null default 'Pending' check (claim_status in ('Pending', 'Claimed', 'Failed', 'Not Eligible')),
    reward_type text not null default 'DM' check (reward_type in ('DM', 'VC')),
    reward_amount_claimed bigint not null default 0 check (reward_amount_claimed >= 0),
    claimed_at timestamptz,
    notes text,
    created_at timestamptz not null default now(),
    constraint uq_claims_owner_update_account unique (owner_id, update_id, account_id),
    constraint chk_claims_claimed_date check (
        claim_status <> 'Claimed' or claimed_at is not null
    ),
    constraint chk_claims_amount_zero_when_not_claimed check (
        claim_status = 'Claimed' or reward_amount_claimed = 0
    )
);

create index if not exists idx_claims_update_id on public.claims(update_id);
create index if not exists idx_claims_account_id on public.claims(account_id);
create index if not exists idx_claims_owner_update_status on public.claims(owner_id, update_id, claim_status);

-- ----------------------------------------------------------------------------
-- 5. Table: account_sources
-- ----------------------------------------------------------------------------
create table if not exists public.account_sources (
    source_id text primary key,
    owner_id uuid not null default auth.uid(),
    account_id text not null references public.accounts(account_id) on delete restrict,
    source_type text not null,
    nominal bigint not null default 0 check (nominal >= 0),
    bonus_amount bigint not null default 0 check (bonus_amount >= 0),
    total_received bigint not null default 0 check (total_received >= 0),
    received_at date,
    notes text,
    created_at timestamptz not null default now()
);

create index if not exists idx_account_sources_account_id on public.account_sources(account_id);
create index if not exists idx_account_sources_account_received on public.account_sources(account_id, received_at);

-- ----------------------------------------------------------------------------
-- 6. Table: account_topups
-- ----------------------------------------------------------------------------
create table if not exists public.account_topups (
    topup_id text primary key,
    owner_id uuid not null default auth.uid(),
    account_id text not null references public.accounts(account_id) on delete restrict,
    nominal bigint not null default 0 check (nominal >= 0),
    bonus_status text default 'None',
    bonus_amount bigint not null default 0 check (bonus_amount >= 0),
    total_received bigint not null default 0 check (total_received >= 0),
    topup_date date,
    bonus_claim_date date,
    notes text,
    created_at timestamptz not null default now()
);

create index if not exists idx_account_topups_account_id on public.account_topups(account_id);
create index if not exists idx_account_topups_account_date on public.account_topups(account_id, topup_date);

-- ----------------------------------------------------------------------------
-- 7. Table: vc_transactions
-- ----------------------------------------------------------------------------
-- account_id is nullable (null = global transaction)
-- NO stored balance column!
create table if not exists public.vc_transactions (
    transaction_id text primary key,
    owner_id uuid not null default auth.uid(),
    account_id text references public.accounts(account_id) on delete restrict,
    source text,
    vc_earned bigint not null default 0 check (vc_earned >= 0),
    vc_spent bigint not null default 0 check (vc_spent >= 0),
    transaction_date date not null default current_date,
    description text,
    created_at timestamptz not null default now(),
    constraint chk_vc_transactions_nonzero check (vc_earned > 0 or vc_spent > 0)
);

create index if not exists idx_vc_transactions_account_id on public.vc_transactions(account_id);
create index if not exists idx_vc_transactions_date on public.vc_transactions(transaction_date);
create index if not exists idx_vc_transactions_owner_date on public.vc_transactions(owner_id, transaction_date);

-- ----------------------------------------------------------------------------
-- 8. Table: settings
-- ----------------------------------------------------------------------------
create table if not exists public.settings (
    key text not null,
    owner_id uuid not null default auth.uid(),
    value jsonb not null,
    description text,
    created_at timestamptz not null default now(),
    primary key (owner_id, key)
);

-- ----------------------------------------------------------------------------
-- 9. Table: activity_logs (append-only)
-- ----------------------------------------------------------------------------
create table if not exists public.activity_logs (
    log_id text primary key,
    owner_id uuid not null default auth.uid(),
    action text not null,
    entity_type text not null,
    entity_id text not null,
    old_value jsonb,
    new_value jsonb,
    created_at timestamptz not null default now()
);

create index if not exists idx_activity_logs_owner_created on public.activity_logs(owner_id, created_at desc);

-- ----------------------------------------------------------------------------
-- Seed default system settings
-- ----------------------------------------------------------------------------
insert into public.settings (key, owner_id, value, description)
values
    ('bbc_to_diamond_rate', coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), '5'::jsonb, 'Number of BBCoins per 1 diamond'),
    ('vc_to_diamond_rate', coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), '1'::jsonb, 'Number of VC per 1 diamond'),
    ('dm_to_bbc_rate', coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), '1'::jsonb, 'Number of BBCoin per 1 DM'),
    ('monthly_tracking_start', coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), '"2026-11-01"'::jsonb, 'Starting month for monthly totals calculations'),
    ('schema_version', coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), '3'::jsonb, 'Current schema version')
on conflict (owner_id, key) do update
set value = excluded.value,
    description = excluded.description;
