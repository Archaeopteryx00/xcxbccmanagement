-- 009_add_account_sources_extra.sql
-- Add missing columns to account_sources
-- Bonus status indicates eligibility for bonus rewards
-- Multiplier is used for reward calculations (default 1)

alter table public.account_sources
    add column bonus_status text default 'Not Eligible',
    add column multiplier numeric default 1;

-- Ensure RLS policy covers new columns (owner-only)
-- Existing policies already use "auth.uid() = owner_id" so no change needed.

