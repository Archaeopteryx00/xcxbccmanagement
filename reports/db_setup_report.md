# Database Setup & Audit Report — XCX BBC Management

**Date:** 2026-11-02  
**Scope:** Supabase Database Setup (Schema, Views, RPC Functions, Security/RLS, Test Suite)  
**Status:** Complete & Verified with 100% Passing Tests  

---

## 1. Assumptions (Configurable Open Decisions)

As specified in the prompt and PRD §3, these business rules were implemented as configurable database structures rather than hard-coded constants:

1. **D1 (Patch Eligibility):** Stored per patch in `updates.eligibility_rule` (`'all_active'` or `'ready_only'`). Default is `'all_active'`. The RPC `create_update` automatically reads this setting to mark accounts as `Eligible` or `Not Eligible`.
2. **D2 (Accounting Model):** **No stored balances**. All balances for DM, BBCoin, VC, and estimated diamonds are strictly derived via real-time analytical views (`v_account_totals`, `v_global_totals`, `v_monthly_totals`).
3. **D3 (Patch Rewards):** Configurable per patch with `updates.reward_type` (`'DM'` or `'VC'`) and `updates.reward_amount` per eligible account.
4. **D6 (Branch Deletion):** Deleting any branch that currently contains accounts is strictly blocked at the RPC level (`delete_branch`) with an explanatory exception.
5. **D8 (`server_code` Uniqueness):** `server_code` is **not** forced with a unique constraint so legacy imports with duplicate warnings are preserved; instead, the view `v_duplicate_accounts` standardizes codes (lowercased, trimmed, whitespace collapsed) to surface warnings in the UI.

---

## 2. Deliverables Summary

### 2.1 Schema Migrations (`supabase/migrations/`)
- **`001_schema.sql`**:
  - Tables created: `branches`, `accounts`, `updates`, `claims`, `account_sources`, `account_topups`, `vc_transactions`, `settings`, `activity_logs`.
  - Primary keys: `text` to preserve existing identifier strings (`acc_w1`, `b_works`).
  - Auditing: All tables enforce `owner_id uuid not null default auth.uid()` and `created_at timestamptz not null default now()`.
  - Foreign keys: `accounts.branch_id → branches`, `claims.update_id → updates`, `claims.account_id → accounts`, `account_sources.account_id → accounts`, `account_topups.account_id → accounts`, and `vc_transactions.account_id → accounts` (all `ON DELETE RESTRICT`).
  - Nullable account ID: `vc_transactions.account_id` is nullable (where null represents global transactions).
  - Check constraints:
    - `accounts.level >= 1`
    - `accounts.status in ('Pre-farm', 'Farming', 'Ready', 'Failed', 'Archived')`
    - `accounts.auto_level_result in ('Untested', 'Success', 'Failed')`
    - `claims.claim_status <> 'Claimed' or claimed_at is not null`
    - `claims.claim_status = 'Claimed' or reward_amount_claimed = 0` (Pending/Failed/Not Eligible force 0 reward)
    - `vc_transactions.vc_earned >= 0 and vc_spent >= 0 and (vc_earned > 0 or vc_spent > 0)`
    - Amount checks (`>= 0`) across all source and top-up tables.
  - Initial `settings` seed: `bbc_to_diamond_rate = 5`, `vc_to_diamond_rate = 1`, `dm_to_bbc_rate = 1`, `monthly_tracking_start = '2026-11-01'`, `schema_version = 3`.

- **`002_views.sql`** (All views created with `security_invoker = true`):
  - `v_account_totals`: Per-account totals for DM, BBCoin, VC, and estimated diamonds. Excludes Pending/Failed/Not Eligible and global VC.
  - `v_global_totals`: System-wide DM, BBCoin, VC earned/spent/balance, and diamonds. VC is strictly separated from DM/BBCoin.
  - `v_monthly_totals`: Monthly breakdown for months $\ge$ `monthly_tracking_start` (2026-11-01). Lifetime balances are independent.
  - `v_branch_performance`: Active vs archived counts, claim completion percentages, and historical DM by branch.
  - `v_patch_summary`: Per-patch statistics; clearly isolates actual collected rewards from potential rewards.
  - `v_duplicate_accounts`: Normalizes `server_code` to flag duplicate accounts.
  - `v_orphans`: Diagnostic view verifying referential integrity across all relationships (returns 0 rows).

- **`003_functions.sql`** (`security invoker`, `set search_path = public`, atomic transactions, audit-logging):
  - `create_update(...)`: Atomically creates update and auto-generates claims for all active eligible accounts.
  - `bulk_claim(...)`: Idempotent bulk claimer that skips archived and ineligible accounts, defaulting reward amount from patch.
  - `set_claim_status(...)`: Status updater that rejects claims on archived accounts and resets rewards to 0 on non-claimed statuses.
  - `archive_account(...)` & `restore_account(...)`: Safely manages account archiving lifecycle while preserving previous status.
  - `delete_account(...)`: Single transaction deleting linked claims, sources, topups, and account VC (preserving global VC), while checking that global VC balance does not turn negative. Writes snapshot to `activity_logs`.
  - `delete_branch(...)`: Blocks deletion if any accounts exist in the branch.
  - `export_all()`: Returns a full JSON backup of all tables for disaster recovery.

- **`004_rls.sql`**:
  - RLS enabled and **forced** on all 9 tables.
  - Policies enforce `owner_id = auth.uid()` for role `authenticated`.
  - `activity_logs`: Only `SELECT` and `INSERT` policies exist (no update/delete policies; append-only).
  - Role `anon` privileges completely revoked on all tables, views, and functions.

---

## 3. Test Execution Results

Tests were executed using the PostgreSQL 16 WASM environment (`scripts/test_runner.js`). All assertions passed:

```text
--- Initializing Local Postgres 16 (PGlite) ---
1. Setting up mock auth schema & roles...
Applying supabase/migrations/001_schema.sql...
  -> Applied successfully.
Applying supabase/migrations/002_views.sql...
  -> Applied successfully.
Applying supabase/migrations/003_functions.sql...
  -> Applied successfully.
Applying supabase/migrations/004_rls.sql...
  -> Applied successfully.

--- Running Test Suite (supabase/tests/01_test_suite.sql) ---
Found 4 test blocks to execute.
Running block 1...
  -> Block 1 completed.
Running block 2...
  -> Block 2 completed.
Running block 3...
  -> Block 3 completed.
Running block 4...
  -> Block 4 completed.

Test Results Summary:
┌─────────┬─────────┬───────────────────┬────────────────────────────────────────────────────────────┬────────┬─────────────────────────────────────────────────────────────────────────┐
│ (index) │ test_id │ test_group        │ test_name                                                  │ status │ details                                                                 │
├─────────┼─────────┼───────────────────┼────────────────────────────────────────────────────────────┼────────┼─────────────────────────────────────────────────────────────────────────┤
│ 0       │ 1       │ 'RLS'             │ 'RLS enabled on all 9 tables'                              │ 'PASS' │ 'All 9 tables have rowsecurity = true'                                  │
│ 1       │ 2       │ 'Constraints'     │ 'Reject unknown Foreign Key (accounts.branch_id)'          │ 'PASS' │ 'Rejected invalid foreign key as expected'                              │
│ 2       │ 3       │ 'Constraints'     │ 'Reject invalid status check'                              │ 'PASS' │ 'Rejected account with status outside allowed enum set'                 │
│ 3       │ 4       │ 'Constraints'     │ 'Reject negative nominal amount'                           │ 'PASS' │ 'Rejected nominal < 0 check constraint'                                 │
│ 4       │ 5       │ 'Constraints'     │ 'Reject VC transaction with 0 earned and 0 spent'          │ 'PASS' │ 'Rejected transaction without positive earn or spend'                   │
│ 5       │ 6       │ 'Constraints'     │ 'Reject Claimed status with null claimed_at date'          │ 'PASS' │ 'Enforced check (claim_status <> Claimed or claimed_at is not null)'    │
│ 6       │ 7       │ 'Constraints'     │ 'Reject duplicate claim for same (update, account)'        │ 'PASS' │ 'Enforced unique constraint on (owner_id, update_id, account_id)'       │
│ 7       │ 8       │ 'RPC & Lifecycle' │ 'Archive account stores status_before_archive'             │ 'PASS' │ 'Account status set to Archived with timestamp'                         │
│ 8       │ 9       │ 'RPC & Lifecycle' │ 'Restore account restores prior status'                    │ 'PASS' │ 'Restored to Pre-farm successfully'                                     │
│ 9       │ 10      │ 'RPC & Lifecycle' │ 'delete_branch blocked when accounts exist'                │ 'PASS' │ 'Raised exception when attempting to delete branch containing accounts' │
│ 10      │ 11      │ 'Calculations'    │ 'v_account_totals exact calculations'                      │ 'PASS' │ 'total_dm=1000, vc_balance=80, diamonds=280'                            │
│ 11      │ 12      │ 'Calculations'    │ 'Potential rewards excluded from actual balances'          │ 'PASS' │ 'Pending claim did not increase total_dm (remained 0)'                  │
│ 12      │ 13      │ 'Calculations'    │ 'v_global_totals includes global VC and computes diamonds' │ 'PASS' │ 'global_dm=1000, vc_balance=120, diamonds=320'                          │
│ 13      │ 14      │ 'Calculations'    │ 'v_patch_summary separates actual from potential reward'   │ 'PASS' │ 'actual=500, potential=500'                                             │
│ 14      │ 15      │ 'Diagnostics'     │ 'v_orphans returns 0 rows'                                 │ 'PASS' │ 'Clean referential integrity verified'                                  │
└─────────┴─────────┴───────────────────┴────────────────────────────────────────────────────────────┴────────┴─────────────────────────────────────────────────────────────────────────┘

ALL 15 TESTS PASSED!

--- Additional Security & RPC Behavioral Tests ---
Testing anon rejection on tables...
Anon SELECT rejected: PASS
Testing cross-user isolation...
Cross-user isolation (User B cannot see User A rows): PASS
Testing activity_logs update/delete denial...
activity_logs UPDATE denied: PASS
activity_logs DELETE denied: PASS
Testing bulk_claim RPC behavior...
bulk_claim 1st run result: { update_id: 'upd_uA_1', skipped_count: 1, updated_count: 1 }
bulk_claim 2nd run result (repeat): { update_id: 'upd_uA_1', skipped_count: 2, updated_count: 0 }
Claimed amount verified (defaults from patch = 250): { claim_status: 'Claimed', reward_amount_claimed: 250 }
bulk_claim idempotency & default patch reward: PASS
Testing delete_account RPC behavior & negative-VC block...
delete_account blocked on negative resulting VC balance: PASS
delete_account removes account rows, preserves global VC, writes audit log: PASS

--- Testing RPC: export_all() ---
export_all() keys returned: [
  'claims',
  'updates',
  'accounts',
  'branches',
  'owner_id',
  'settings',
  'exported_at',
  'activity_logs',
  'account_topups',
  'schema_version',
  'account_sources',
  'vc_transactions'
]
export_all() complete backup export: PASS
```

---

## 4. What Was NOT Verified (Limitations)

1. **Remote Staging Execution:** Direct push against remote staging instance `https://iwwebxwbsbplvzkfwjbc.supabase.co` requires the direct database password or access token (`SUPABASE_DB_URL` / `SUPABASE_DB_PASSWORD`), which are held securely by the operator.
2. **User Data Import:** No production or backup user data was imported during this step (per strict phase boundaries: schema setup only).

---

## 5. Next Steps

1. Operator runs `npx supabase db push --db-url "$env:SUPABASE_DB_URL"` (or via CLI link) to push migrations `001` through `004` to the staging project.
2. Operator proceeds to **Phase 3 (Data Import & Idempotent Migration Script)**.
