# Supabase Database Migrations & Administration Guide

This directory contains the database schema, views, transactional RPC functions, and Row Level Security (RLS) policies for **XCX BBC Management**.

---

## 1. Directory Structure

```text
supabase/
├── config.toml                     # Supabase local/project configuration
├── README.md                       # This administrative guide
├── migrations/
│   ├── 001_schema.sql             # Base tables, foreign keys, constraints, and indexes
│   ├── 002_views.sql              # Security-invoker analytical views (single source of truth)
│   ├── 003_functions.sql          # Transactional RPC functions with audit logging
│   └── 004_rls.sql                # Strict RLS policies and privilege hardening
└── tests/
    └── 01_test_suite.sql          # SQL test verification suite
```

---

## 2. Environment Variables

Store these secrets in your `.env` file (which is git-ignored). **Never commit credentials to version control.**

| Variable Name | Purpose | Sensitivity |
| :--- | :--- | :--- |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase API URL endpoint | Public |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Supabase Anon Key for client queries | Public |
| `SUPABASE_DB_URL` | Direct connection string for migrations | **Secret** |
| `SUPABASE_DB_PASSWORD` | Database password for direct CLI linking | **Secret** |
| `SUPABASE_ACCESS_TOKEN` | Personal access token for Supabase CLI | **Secret** |

---

## 3. How to Apply Migrations to Supabase Staging

### Option A: Using Database Connection String (`db push`)
```powershell
# In PowerShell:
npx supabase db push --db-url "$env:SUPABASE_DB_URL"
```

### Option B: Linking Project Ref
1. Link the local repository to your remote staging project:
   ```powershell
   npx supabase link --project-ref <YOUR_PROJECT_REF>
   ```
2. Push all migrations:
   ```powershell
   npx supabase db push
   ```

---

## 4. How to Disable Public Signups

Only a single operator should have access to this application. To prevent unauthorized account creation:

### Via Dashboard:
1. Log in to the [Supabase Dashboard](https://supabase.com/dashboard).
2. Navigate to **Authentication** -> **Configuration** -> **Sign In / Up**.
3. Toggle off **Enable Email Signup** (and ensure third-party OAuth providers are disabled).
4. Save changes.

### Via `config.toml`:
In `supabase/config.toml`, ensure the following keys are set to `false`:
```toml
[auth]
enable_signup = false

[auth.email]
enable_signup = false
```

---

## 5. How to Take a Database Dump Before Migrations

Always take a dump before executing schema updates or data imports:

```powershell
# Create a timestamped backup dump
npx supabase db dump -f "backups/dump_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql" --db-url "$env:SUPABASE_DB_URL"
```

---

## 6. Rollback Procedures

Each migration script includes a down-migration comment block at the top.

### Manual Rollback Steps:
1. **004_rls.sql rollback:**
   ```sql
   ALTER TABLE public.branches DISABLE ROW LEVEL SECURITY;
   ALTER TABLE public.accounts DISABLE ROW LEVEL SECURITY;
   ALTER TABLE public.updates DISABLE ROW LEVEL SECURITY;
   ALTER TABLE public.claims DISABLE ROW LEVEL SECURITY;
   ALTER TABLE public.account_sources DISABLE ROW LEVEL SECURITY;
   ALTER TABLE public.account_topups DISABLE ROW LEVEL SECURITY;
   ALTER TABLE public.vc_transactions DISABLE ROW LEVEL SECURITY;
   ALTER TABLE public.settings DISABLE ROW LEVEL SECURITY;
   ALTER TABLE public.activity_logs DISABLE ROW LEVEL SECURITY;
   ```
2. **003_functions.sql rollback:**
   ```sql
   DROP FUNCTION IF EXISTS public.export_all();
   DROP FUNCTION IF EXISTS public.delete_branch(text);
   DROP FUNCTION IF EXISTS public.delete_account(text);
   DROP FUNCTION IF EXISTS public.restore_account(text);
   DROP FUNCTION IF EXISTS public.archive_account(text);
   DROP FUNCTION IF EXISTS public.set_claim_status(text, text, bigint, timestamptz);
   DROP FUNCTION IF EXISTS public.bulk_claim(text, text[], bigint);
   DROP FUNCTION IF EXISTS public.create_update(text, text, date, date, text, bigint, text, text);
   ```
3. **002_views.sql rollback:**
   ```sql
   DROP VIEW IF EXISTS public.v_orphans CASCADE;
   DROP VIEW IF EXISTS public.v_duplicate_accounts CASCADE;
   DROP VIEW IF EXISTS public.v_patch_summary CASCADE;
   DROP VIEW IF EXISTS public.v_branch_performance CASCADE;
   DROP VIEW IF EXISTS public.v_monthly_totals CASCADE;
   DROP VIEW IF EXISTS public.v_global_totals CASCADE;
   DROP VIEW IF EXISTS public.v_account_totals CASCADE;
   ```
4. **001_schema.sql rollback:**
   ```sql
   DROP TABLE IF EXISTS public.activity_logs, public.settings, public.vc_transactions,
     public.account_topups, public.account_sources, public.claims, public.updates,
     public.accounts, public.branches CASCADE;
   ```

---

## 7. Running the Automated Database Tests

Run the test suite using Node.js and the built-in PostgreSQL 16 WASM environment:
```powershell
node scripts/test_runner.js
```
All assertions will execute and report `PASS`/`FAIL` metrics.
