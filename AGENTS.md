# AGENTS.md — XCX BBC Management (Supabase migration)

Instructions for any coding/audit agent working in this repository. Read this file and `PRD_XCX_BBC_Supabase_Migration.md` fully before doing anything. If they conflict with a user message, the user's latest explicit instruction wins, except for the Hard Rules below, which require the user to confirm explicitly.

## 1. Project in one paragraph

XCX BBC Management is a single-operator tool for managing game accounts across branches, patch (update) reward claims, and the currencies DM, BBCoin and VC. It is a single-file HTML/CSS/vanilla-JS app, currently persisting to LocalStorage (key `xcx_bbc_management_v1_2`), being migrated to Supabase (Postgres + Auth + RPC). The operator updates it only on events (new patch, account change), not daily.

Reference implementation: `XCX_BBC_Management_v1.6.html`. Original untouched backup: `XCX_BBC_Management_v1.4.ORIGINAL_BACKUP.html`. Treat the code as the source of truth for current behavior and the PRD as the target.

## 2. Hard rules (never break; ask first)

1. **Never delete, overwrite, or migrate user data without a backup.** Never clear LocalStorage. Never `drop`/`truncate` anything outside a disposable staging database.
2. **Never put `service_role` keys, DB passwords, or JWT secrets in the HTML, the repo, logs, or chat.** Client code uses only the project URL and `anon` key. If you see a secret, stop and tell the user.
3. **RLS must be enabled on every table**, with owner-only policies. A table without RLS is a defect.
4. **Do not change business or financial rules silently.** Any change that alters a number the user sees must be listed with before/after values and approved. Open decisions D1–D8 in the PRD must be answered by the user, not guessed.
5. **DM, BBCoin and VC are separate.** Never merge VC into DM/BBCoin. 5 BBCoin = 1 diamond, 1 VC = 1 diamond, 1 DM = 1 BBCoin unless settings say otherwise.
6. **Potential rewards are never actual balances.** Only successfully claimed rewards count.
7. **One reward counts once.** One claim per (update, account). Repeating an action must not duplicate records.
8. **New accounts never receive historical patch rewards automatically.**
9. **Lifetime balances never reset when a month changes.** Monthly tracking starts 2026-11-01 (from settings, not hard-coded in queries).
10. **Do not remove the Forecast feature.** Do not rebuild the app from scratch.
11. **Never claim something was tested unless you ran the test.** Report real output. If you could not run something, say so.
12. **Do not merge accounts automatically.** Duplicate handling is warn-only.
13. **Destructive operations require confirmation UI and run as a single transaction (RPC).** Activity logs are append-only.

## 3. Stop and ask when

- A decision in PRD §3 (D1–D8) is needed to proceed.
- A change would alter an existing number, status value, or stored field name.
- You find data that fails validation (orphans, duplicates, negatives): report it, do not "fix" it silently.
- A migration would be irreversible or you lack a verified backup.
- The task needs credentials you were not given.
- Scope is expanding beyond the PRD.

Ask concisely: state the ambiguity, the options, your recommended safe default, and the impact.

## 4. Working method

1. **Inspect before editing.** Read the relevant code/schema first. Do not assume field names; collections use different shapes (e.g. `vc_transactions.account_id` is nullable = global).
2. **Small, testable steps.** One concern per change. Keep a backup/copy before structural edits.
3. **Single source of truth.** Totals come from database views. Do not recompute DM/VC totals in client JS. If a screen needs a number, add it to a view.
4. **Preserve behavior.** Keep element IDs, handlers and UI language unless a migration plan says otherwise. Keep the existing visual style.
5. **Validate JavaScript syntax** after every edit (`node --check` on the extracted script).
6. **Escape all user text** before `innerHTML` (use the existing `esc()`); use `innerText`/`textContent` for plain-text sinks (do not double-escape).
7. **Idempotency.** Import and migration scripts must be safely re‑runnable.
8. **Write migrations as files** (`supabase/migrations/NNN_name.sql`), never as ad‑hoc dashboard edits. Test on staging first.

## 5. Data model essentials

Tables: `branches, accounts, updates, claims, account_sources, account_topups, vc_transactions, settings, activity_logs` (see PRD §5 for columns/constraints).

Key relations: `accounts.branch_id → branches`; `claims(update_id, account_id)` unique, `claims.branch_id_at_claim` snapshot; `account_sources/topups.account_id → accounts`; `vc_transactions.account_id` nullable.

Account lifecycle: statuses include `Archived` (stores `status_before_archive`, `archived_at`). Archived accounts are excluded from new claims, pickers and active lists, but their history stays in totals.

Delete account: removes the account's claims, sources, top‑ups and account‑linked VC transactions; never global VC; blocked if VC balance would go negative; keeps logs; takes a snapshot first.

## 6. Audit mode (when asked to audit)

Audit = read‑only. Do not modify code or data. Cover the eight areas in PRD §8: code, data, schema, security, calculations, flows, performance/reliability, UI regression.

Report format for each finding:

```
[ID] [Severity: Critical|High|Medium|Low] Title
Where:    file:line / table / query
Evidence: what you observed (query output, snippet)
Impact:   what goes wrong, with a concrete example
Fix:      recommended change (and whether it alters any number)
```

End with: a prioritized list, a list of decisions needed from the user, and what you could not verify.

Mandatory data checks: duplicate IDs, orphan references, duplicate claims per (update, account), negative amounts, invalid enums/dates, duplicate source/topup pairs (e.g. `src_2` vs `tp_1`), VC balance consistency, and reconciliation of totals between old and new systems.

Mandatory security checks: RLS enabled on all tables; policies tested with `anon` and with a second user (must be denied); no secrets in repo or git history; public signup disabled; CDN scripts pinned to exact versions.

## 7. Testing requirements

Run tests in a real browser (Playwright/Chromium) against staging, not production. Minimum coverage:

- Patch: create, filter by branch, search, mark Claimed/Pending/Failed/Not Eligible, Bulk Claim (cancel + confirm), repeat bulk (no duplicates), reopen, history.
- Accounts: add, edit, move branch, archive, restore, delete (impact preview, block rule, undo), duplicate warning, no historical rewards for new accounts.
- Currency: DM, BBCoin, VC earn/spend, conversion, monthly vs lifetime, potential excluded, no double counting.
- Data: reload persistence, CSV export/import, backup/restore round‑trip, malformed/missing data, offline/network failure messages.
- Security: RLS denial tests.
- UI: all tabs load, zero console errors, desktop + mobile width.

Include the exact commands and results in your report. A change is not done until its tests pass.

## 8. Definition of done

- Behavior matches the PRD and the user's latest instructions.
- Reconciliation shows old vs new totals equal (or every difference explained and approved).
- No orphans, no duplicate claims, RLS verified.
- Syntax check passes; browser tests pass; console clean.
- Changelog lists: what changed, any number that changed (before/after), known issues, rollback steps.
- Original file and last known‑good backup still intact.

## 9. Communication style

The user prefers concise responses. Lead with the result, then the evidence. Use plain language. List what is unchanged and what needs their decision. Do not pad. Write user‑facing explanations in Indonesian if the user writes in Indonesian; keep code, SQL and identifiers in English.

## 10. Suggested repository layout

```
/AGENTS.md
/PRD_XCX_BBC_Supabase_Migration.md
/app/XCX_BBC_Management_v2.html          # target client
/legacy/XCX_BBC_Management_v1.6.html     # reference, read‑only
/legacy/XCX_BBC_Management_v1.4.ORIGINAL_BACKUP.html
/supabase/migrations/                    # ordered SQL files
/supabase/tests/                         # RLS + constraint + RPC tests
/scripts/import_from_backup.*            # idempotent importer + reconciliation
/reports/                                # audit reports, reconciliation, changelogs
/backups/                                # user JSON backups (gitignored if sensitive)
```

Add `.env*`, `*.key`, and `/backups` (if it holds real data) to `.gitignore`.
