-- ============================================================================
-- Migration: 002_app_data.sql
-- Description: Store the entire client state (app_data) as a JSONB payload.
-- This table is used for synchronization between devices via Supabase.
-- ============================================================================

-- Enable Row Level Security (RLS) for the new table.
create table if not exists public.app_data (
    owner_id uuid not null default auth.uid(),
    data jsonb not null,
    updated_at timestamptz not null default now(),
    primary key (owner_id)
);

-- Ensure only the authenticated user can read/write their own row.
alter table public.app_data enable row level security;

-- Policy: allow SELECT for the owner.
create policy "allow_select_owner"
    on public.app_data
    for select
    using (auth.uid() = owner_id);

-- Policy: allow INSERT for the owner (only one row per owner).
create policy "allow_insert_owner"
    on public.app_data
    for insert
    with check (auth.uid() = owner_id);

-- Policy: allow UPDATE for the owner.
create policy "allow_update_owner"
    on public.app_data
    for update
    using (auth.uid() = owner_id)
    with check (auth.uid() = owner_id);

-- Optional: prevent DELETE to keep a historic backup (hard rule). Comment out if needed.
-- create policy "allow_delete_owner"
--     on public.app_data
--     for delete
--     using (false);

-- Index to speed up lookups by owner.
create index if not exists idx_app_data_owner on public.app_data(owner_id);

-- Insert an empty placeholder for new users (optional, idempotent).
-- The migration runs without an authenticated session, so auth.uid() returns NULL.
-- We skip the automatic insert; the client will create the row on first save.
-- insert into public.app_data (owner_id, data)
-- values (auth.uid(), '{}'::jsonb)
-- on conflict (owner_id) do nothing;

