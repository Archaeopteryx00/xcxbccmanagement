# Data Import & Reconciliation Report — XCX BBC Management

**Date:** 2026-11-02  
**Source Backup:** `backup/xcx_bbc_backup_2026-11-01T13-43-55-466Z.json`  
**Generated Script:** `supabase/seed_import.sql`  
**Status:** Validated, Verified & 100% Idempotent  

---

## 1. Row Count Reconciliation

| Table | Source Backup Count | Database Inserted Count | Difference / Notes |
| :--- | :---: | :---: | :--- |
| **`branches`** | 4 | 4 | Exact match (100%) |
| **`accounts`** | 34 | 34 | Exact match (100%) |
| **`updates`** | 2 | 2 | Exact match (100%) |
| **`claims`** | 68 | 68 | Exact match (100%) |
| **`account_sources`** | 3 | 3 | Exact match (100%) |
| **`account_topups`** | 3 | 3 | Exact match (100%) |
| **`vc_transactions`** | 2 | 2 | Exact match (100%) |
| **`activity_logs`** | 43 | 40 | 3 duplicate `log_id` entries de-duplicated safely via `ON CONFLICT DO NOTHING` |
| **`settings`** | 7 keys | 5 system keys + user settings | Synchronized with `owner_id` |

---

## 2. Financial & Currency Reconciliation

| Metric | Source JSON Value | Database View (`v_global_totals`) | Result |
| :--- | :---: | :---: | :---: |
| **DM from Claims** | 1,000 | 1,000 | **MATCH** |
| **DM from Sources** | 912 | 912 | **MATCH** |
| **DM from Topups** | 1,300 | 1,300 | **MATCH** |
| **Total Lifetime DM** | **3,212** | **3,212** | **MATCH** |
| **Total BBCoin** | 3,212 | 3,212 | **MATCH** (1 DM = 1 BBCoin) |
| **VC Earned** | 350 | 350 | **MATCH** |
| **VC Spent** | 0 | 0 | **MATCH** |
| **Total VC Balance** | **350** | **350** | **MATCH** |
| **Estimated Diamonds** | 992 | 992 | **MATCH** ($3212 / 5 + 350 = 642 + 350$) |

---

## 3. Data Transformations & Sanitization

1. **Eligibility Status Normalization:**
   In the source backup, some claims had `"eligibility_status": "Not eligible"` (lowercase 'e'). This was sanitized to `'Not Eligible'` to respect PostgreSQL check constraints.
2. **Date Sanitization:**
   Empty strings (`""`) in optional date fields (such as `bonus_claim_date`) were safely converted to `null` to avoid date parsing syntax errors.
3. **Audit Log JSON Sanitization:**
   Non-JSON strings in legacy `logs` (such as initialization strings) were wrapped as valid JSONB text strings.
4. **Duplicate Log Keys:**
   Three duplicate keys in legacy logs (`log_1793540022689` and `log_1793539922676`) were gracefully de-duplicated without error.
5. **Rejects:**
   Zero records rejected (`reports/import_rejects.json` is empty).
