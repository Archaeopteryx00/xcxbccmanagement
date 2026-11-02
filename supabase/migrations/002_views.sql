-- ============================================================================
-- Migration: 002_views.sql
-- Description: Analytical views as single source of truth for all calculations
-- All views use `with (security_invoker = true)` to respect RLS
-- Down Migration Note:
-- DROP VIEW IF EXISTS v_orphans, v_duplicate_accounts, v_patch_summary,
--   v_branch_performance, v_monthly_totals, v_global_totals, v_account_totals CASCADE;
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. View: v_account_totals
-- ----------------------------------------------------------------------------
-- Explanatory Comment:
-- Counts:
--   - DM from claims: only where claim_status = 'Claimed' and reward_type = 'DM'.
--   - DM from sources: sum of total_received from account_sources.
--   - DM from topups: sum of total_received from account_topups.
--   - VC earned and VC spent: transactions specifically linked to this account_id.
--   - BBCoin and estimated diamonds calculated via standard conversion rates.
-- Excludes:
--   - Excludes Pending, Failed, and Not Eligible claims.
--   - Potential rewards are NEVER included in balances.
--   - Excludes global VC transactions (where account_id is null).
-- ----------------------------------------------------------------------------
create or replace view public.v_account_totals
with (security_invoker = true)
as
with claim_dm as (
    select
        c.account_id,
        coalesce(sum(c.reward_amount_claimed), 0)::bigint as dm_from_claims
    from public.claims c
    where c.claim_status = 'Claimed' and c.reward_type = 'DM'
    group by c.account_id
),
source_dm as (
    select
        s.account_id,
        coalesce(sum(s.total_received), 0)::bigint as dm_from_sources
    from public.account_sources s
    group by s.account_id
),
topup_dm as (
    select
        t.account_id,
        coalesce(sum(t.total_received), 0)::bigint as dm_from_topups
    from public.account_topups t
    group by t.account_id
),
account_vc as (
    select
        v.account_id,
        coalesce(sum(v.vc_earned), 0)::bigint as vc_earned,
        coalesce(sum(v.vc_spent), 0)::bigint as vc_spent,
        (coalesce(sum(v.vc_earned), 0) - coalesce(sum(v.vc_spent), 0))::bigint as vc_balance
    from public.vc_transactions v
    where v.account_id is not null
    group by v.account_id
)
select
    a.account_id,
    a.owner_id,
    a.branch_id,
    b.branch_name,
    a.server_code,
    a.level,
    a.status,
    a.auto_level_result,
    coalesce(cd.dm_from_claims, 0)::bigint as dm_from_claims,
    coalesce(sd.dm_from_sources, 0)::bigint as dm_from_sources,
    coalesce(td.dm_from_topups, 0)::bigint as dm_from_topups,
    (coalesce(cd.dm_from_claims, 0) + coalesce(sd.dm_from_sources, 0) + coalesce(td.dm_from_topups, 0))::bigint as total_dm,
    -- 1 DM = 1 BBCoin
    (coalesce(cd.dm_from_claims, 0) + coalesce(sd.dm_from_sources, 0) + coalesce(td.dm_from_topups, 0))::bigint as total_bbcoin,
    coalesce(av.vc_earned, 0)::bigint as vc_earned,
    coalesce(av.vc_spent, 0)::bigint as vc_spent,
    coalesce(av.vc_balance, 0)::bigint as vc_balance,
    -- Estimated diamonds: (BBCoin / 5) + (VC balance / 1)
    floor(
        ((coalesce(cd.dm_from_claims, 0) + coalesce(sd.dm_from_sources, 0) + coalesce(td.dm_from_topups, 0)) / 5.0)
        + coalesce(av.vc_balance, 0)
    )::bigint as estimated_diamonds,
    a.created_at
from public.accounts a
left join public.branches b on a.branch_id = b.branch_id
left join claim_dm cd on a.account_id = cd.account_id
left join source_dm sd on a.account_id = sd.account_id
left join topup_dm td on a.account_id = td.account_id
left join account_vc av on a.account_id = av.account_id;

-- ----------------------------------------------------------------------------
-- 2. View: v_global_totals
-- ----------------------------------------------------------------------------
-- Explanatory Comment:
-- Counts:
--   - Total DM across all accounts (claims + sources + topups).
--   - Total BBCoin (1 DM = 1 BBCoin).
--   - Total VC Earned, Spent, and Balance across all transactions (account-linked + global).
--   - Estimated Diamonds: 5 BBCoin = 1 diamond, 1 VC = 1 diamond.
-- Excludes:
--   - VC is NEVER added into DM or BBCoin.
--   - Potential rewards are NEVER included in actual balances.
-- ----------------------------------------------------------------------------
create or replace view public.v_global_totals
with (security_invoker = true)
as
with dm_agg as (
    select
        owner_id,
        coalesce(sum(total_dm), 0)::bigint as global_dm,
        coalesce(sum(total_bbcoin), 0)::bigint as global_bbcoin
    from public.v_account_totals
    group by owner_id
),
vc_agg as (
    select
        owner_id,
        coalesce(sum(vc_earned), 0)::bigint as global_vc_earned,
        coalesce(sum(vc_spent), 0)::bigint as global_vc_spent,
        (coalesce(sum(vc_earned), 0) - coalesce(sum(vc_spent), 0))::bigint as global_vc_balance
    from public.vc_transactions
    group by owner_id
),
accounts_count as (
    select
        owner_id,
        count(*)::bigint as total_accounts,
        count(*) filter (where status <> 'Archived')::bigint as active_accounts,
        count(*) filter (where status = 'Archived')::bigint as archived_accounts
    from public.accounts
    group by owner_id
)
select
    coalesce(ac.owner_id, auth.uid()) as owner_id,
    coalesce(ac.total_accounts, 0)::bigint as total_accounts,
    coalesce(ac.active_accounts, 0)::bigint as active_accounts,
    coalesce(ac.archived_accounts, 0)::bigint as archived_accounts,
    coalesce(da.global_dm, 0)::bigint as total_dm,
    coalesce(da.global_bbcoin, 0)::bigint as total_bbcoin,
    coalesce(va.global_vc_earned, 0)::bigint as total_vc_earned,
    coalesce(va.global_vc_spent, 0)::bigint as total_vc_spent,
    coalesce(va.global_vc_balance, 0)::bigint as total_vc_balance,
    floor(
        (coalesce(da.global_bbcoin, 0) / 5.0) + coalesce(va.global_vc_balance, 0)
    )::bigint as estimated_diamonds
from accounts_count ac
full outer join dm_agg da on ac.owner_id = da.owner_id
full outer join vc_agg va on coalesce(ac.owner_id, da.owner_id) = va.owner_id;

-- ----------------------------------------------------------------------------
-- 3. View: v_monthly_totals
-- ----------------------------------------------------------------------------
-- Explanatory Comment:
-- Counts:
--   - DM and VC earned/spent aggregated by month (month_start date).
--   - Filters only months on or after `monthly_tracking_start` setting (default 2026-11-01).
-- Excludes:
--   - Transactions prior to `monthly_tracking_start` are excluded from monthly breakdown.
--   - Lifetime totals are completely independent and never reset.
-- ----------------------------------------------------------------------------
create or replace view public.v_monthly_totals
with (security_invoker = true)
as
with tracking_start as (
    select
        owner_id,
        coalesce(
            (value->>0)::date,
            '2026-11-01'::date
        ) as start_date
    from public.settings
    where key = 'monthly_tracking_start'
),
monthly_claims as (
    select
        c.owner_id,
        date_trunc('month', c.claimed_at)::date as month_date,
        sum(c.reward_amount_claimed)::bigint as dm_earned
    from public.claims c
    where c.claim_status = 'Claimed'
      and c.reward_type = 'DM'
      and c.claimed_at is not null
    group by c.owner_id, date_trunc('month', c.claimed_at)::date
),
monthly_sources as (
    select
        s.owner_id,
        date_trunc('month', s.received_at)::date as month_date,
        sum(s.total_received)::bigint as dm_earned
    from public.account_sources s
    where s.received_at is not null
    group by s.owner_id, date_trunc('month', s.received_at)::date
),
monthly_topups as (
    select
        t.owner_id,
        date_trunc('month', t.topup_date)::date as month_date,
        sum(t.total_received)::bigint as dm_earned
    from public.account_topups t
    where t.topup_date is not null
    group by t.owner_id, date_trunc('month', t.topup_date)::date
),
monthly_vc as (
    select
        v.owner_id,
        date_trunc('month', v.transaction_date)::date as month_date,
        sum(v.vc_earned)::bigint as vc_earned,
        sum(v.vc_spent)::bigint as vc_spent
    from public.vc_transactions v
    group by v.owner_id, date_trunc('month', v.transaction_date)::date
),
all_months as (
    select owner_id, month_date from monthly_claims
    union
    select owner_id, month_date from monthly_sources
    union
    select owner_id, month_date from monthly_topups
    union
    select owner_id, month_date from monthly_vc
)
select
    m.owner_id,
    to_char(m.month_date, 'YYYY-MM') as month_label,
    m.month_date as month_start,
    coalesce(mc.dm_earned, 0)::bigint + coalesce(ms.dm_earned, 0)::bigint + coalesce(mt.dm_earned, 0)::bigint as dm_earned,
    coalesce(mv.vc_earned, 0)::bigint as vc_earned,
    coalesce(mv.vc_spent, 0)::bigint as vc_spent,
    (coalesce(mv.vc_earned, 0) - coalesce(mv.vc_spent, 0))::bigint as vc_net
from all_months m
left join tracking_start ts on m.owner_id = ts.owner_id
left join monthly_claims mc on m.owner_id = mc.owner_id and m.month_date = mc.month_date
left join monthly_sources ms on m.owner_id = ms.owner_id and m.month_date = ms.month_date
left join monthly_topups mt on m.owner_id = mt.owner_id and m.month_date = mt.month_date
left join monthly_vc mv on m.owner_id = mv.owner_id and m.month_date = mv.month_date
where m.month_date >= coalesce(ts.start_date, '2026-11-01'::date)
order by m.month_date desc;

-- ----------------------------------------------------------------------------
-- 4. View: v_branch_performance
-- ----------------------------------------------------------------------------
-- Explanatory Comment:
-- Counts:
--   - Active vs archived accounts count per branch.
--   - Account status distribution (Pre-farm, Farming, Ready, Failed).
--   - Claim completion rate (Claimed / Total claims).
--   - Actual DM earned by accounts in the branch (archived accounts' historical DM included).
-- Excludes:
--   - Unclaimed or failed claims do not count toward actual DM.
-- ----------------------------------------------------------------------------
create or replace view public.v_branch_performance
with (security_invoker = true)
as
with branch_claims as (
    select
        c.branch_id_at_claim as branch_id,
        count(*)::bigint as total_claims,
        count(*) filter (where c.claim_status = 'Claimed')::bigint as claimed_claims
    from public.claims c
    where c.branch_id_at_claim is not null
    group by c.branch_id_at_claim
),
branch_dm as (
    select
        a.branch_id,
        coalesce(sum(at.total_dm), 0)::bigint as total_dm
    from public.accounts a
    join public.v_account_totals at on a.account_id = at.account_id
    group by a.branch_id
)
select
    b.branch_id,
    b.owner_id,
    b.branch_name,
    b.status as branch_status,
    count(a.account_id) filter (where a.status <> 'Archived')::bigint as active_accounts,
    count(a.account_id) filter (where a.status = 'Archived')::bigint as archived_accounts,
    count(a.account_id)::bigint as total_accounts,
    count(a.account_id) filter (where a.status = 'Pre-farm')::bigint as prefarm_count,
    count(a.account_id) filter (where a.status = 'Farming')::bigint as farming_count,
    count(a.account_id) filter (where a.status = 'Ready')::bigint as ready_count,
    count(a.account_id) filter (where a.status = 'Failed')::bigint as failed_count,
    coalesce(bc.total_claims, 0)::bigint as total_claims,
    coalesce(bc.claimed_claims, 0)::bigint as claimed_claims,
    case
        when coalesce(bc.total_claims, 0) > 0 then
            round((bc.claimed_claims::numeric / bc.total_claims::numeric) * 100, 2)
        else 0
    end as claim_completion_rate,
    coalesce(bdm.total_dm, 0)::bigint as actual_dm_total
from public.branches b
left join public.accounts a on b.branch_id = a.branch_id
left join branch_claims bc on b.branch_id = bc.branch_id
left join branch_dm bdm on b.branch_id = bdm.branch_id
group by b.branch_id, b.owner_id, b.branch_name, b.status, bc.total_claims, bc.claimed_claims, bdm.total_dm;

-- ----------------------------------------------------------------------------
-- 5. View: v_patch_summary
-- ----------------------------------------------------------------------------
-- Explanatory Comment:
-- Counts:
--   - Detailed claim counts (Total, Eligible, Claimed, Pending, Failed, Not Eligible).
--   - Actual reward collected (Claimed only).
--   - Potential reward (eligible, active accounts that are not yet claimed).
-- Excludes:
--   - Potential rewards are NEVER merged into actual reward balance.
-- ----------------------------------------------------------------------------
create or replace view public.v_patch_summary
with (security_invoker = true)
as
select
    u.update_id,
    u.owner_id,
    u.update_name,
    u.status as patch_status,
    u.reward_type,
    u.reward_amount as patch_reward_amount,
    u.eligibility_rule,
    u.start_date,
    u.end_date,
    count(c.claim_id)::bigint as total_claims_targeted,
    count(c.claim_id) filter (where c.eligibility_status = 'Eligible')::bigint as eligible_count,
    count(c.claim_id) filter (where c.claim_status = 'Claimed')::bigint as claimed_count,
    count(c.claim_id) filter (where c.claim_status = 'Pending')::bigint as pending_count,
    count(c.claim_id) filter (where c.claim_status = 'Failed')::bigint as failed_count,
    count(c.claim_id) filter (where c.claim_status = 'Not Eligible' or c.eligibility_status = 'Not Eligible')::bigint as not_eligible_count,
    coalesce(sum(c.reward_amount_claimed) filter (where c.claim_status = 'Claimed'), 0)::bigint as actual_reward_total,
    -- Potential: eligible non-archived claims not yet claimed * update reward amount
    (
        count(c.claim_id) filter (
            where c.claim_status in ('Pending', 'Failed')
              and c.eligibility_status = 'Eligible'
              and a.status <> 'Archived'
        ) * u.reward_amount
    )::bigint as potential_reward_total
from public.updates u
left join public.claims c on u.update_id = c.update_id
left join public.accounts a on c.account_id = a.account_id
group by u.update_id, u.owner_id, u.update_name, u.status, u.reward_type, u.reward_amount, u.eligibility_rule, u.start_date, u.end_date;

-- ----------------------------------------------------------------------------
-- 6. View: v_duplicate_accounts
-- ----------------------------------------------------------------------------
-- Diagnostic view: identifies duplicate server_codes (normalized: lower, trimmed, spaces collapsed)
-- ----------------------------------------------------------------------------
create or replace view public.v_duplicate_accounts
with (security_invoker = true)
as
with normalized as (
    select
        account_id,
        owner_id,
        branch_id,
        server_code,
        status,
        lower(regexp_replace(trim(server_code), '\s+', ' ', 'g')) as normalized_code
    from public.accounts
    where server_code is not null and trim(server_code) <> ''
),
duplicates as (
    select
        owner_id,
        normalized_code,
        count(*) as duplicate_count
    from normalized
    group by owner_id, normalized_code
    having count(*) > 1
)
select
    n.account_id,
    n.owner_id,
    n.branch_id,
    n.server_code,
    n.normalized_code,
    n.status,
    d.duplicate_count
from normalized n
join duplicates d on n.owner_id = d.owner_id and n.normalized_code = d.normalized_code;

-- ----------------------------------------------------------------------------
-- 7. View: v_orphans
-- ----------------------------------------------------------------------------
-- Diagnostic view: checks foreign key integrity. Should always return 0 rows.
-- ----------------------------------------------------------------------------
create or replace view public.v_orphans
with (security_invoker = true)
as
select
    'accounts.branch_id' as orphan_relationship,
    a.account_id as orphan_record_id,
    a.branch_id as missing_foreign_id,
    a.owner_id
from public.accounts a
left join public.branches b on a.branch_id = b.branch_id
where b.branch_id is null

union all

select
    'claims.update_id' as orphan_relationship,
    c.claim_id as orphan_record_id,
    c.update_id as missing_foreign_id,
    c.owner_id
from public.claims c
left join public.updates u on c.update_id = u.update_id
where u.update_id is null

union all

select
    'claims.account_id' as orphan_relationship,
    c.claim_id as orphan_record_id,
    c.account_id as missing_foreign_id,
    c.owner_id
from public.claims c
left join public.accounts a on c.account_id = a.account_id
where a.account_id is null

union all

select
    'account_sources.account_id' as orphan_relationship,
    s.source_id as orphan_record_id,
    s.account_id as missing_foreign_id,
    s.owner_id
from public.account_sources s
left join public.accounts a on s.account_id = a.account_id
where a.account_id is null

union all

select
    'account_topups.account_id' as orphan_relationship,
    t.topup_id as orphan_record_id,
    t.account_id as missing_foreign_id,
    t.owner_id
from public.account_topups t
left join public.accounts a on t.account_id = a.account_id
where a.account_id is null

union all

select
    'vc_transactions.account_id' as orphan_relationship,
    v.transaction_id as orphan_record_id,
    v.account_id as missing_foreign_id,
    v.owner_id
from public.vc_transactions v
left join public.accounts a on v.account_id = a.account_id
where v.account_id is not null and a.account_id is null;
