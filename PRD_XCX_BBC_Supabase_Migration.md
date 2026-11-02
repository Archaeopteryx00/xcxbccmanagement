# PRD — XCX BBC Management: Migrasi ke Supabase

**Versi dokumen:** 1.0 (draft untuk persetujuan)
**Basis kode:** XCX_BBC_Management v1.6 (single-file HTML, LocalStorage key `xcx_bbc_management_v1_2`)
**Pengguna:** satu operator (Aiden)
**Status keputusan:** lihat §3 — beberapa keputusan HARUS dijawab sebelum Fase 2

---

## 1. Tujuan

1. Memindahkan penyimpanan dari LocalStorage browser ke Supabase (Postgres) supaya data tidak hilang saat browser dibersihkan, bisa diakses dari beberapa perangkat, dan punya backup/restore yang andal.
2. Menjadikan database sebagai **satu sumber kebenaran** untuk semua angka (DM, BBCoin, VC), sehingga masalah "2.812 vs 2.712 DM" dari audit tidak mungkin terjadi lagi.
3. Menegakkan aturan data di level database (unique, foreign key, check, transaksi atomik), bukan hanya di JavaScript.
4. Tetap ringan: aplikasi tetap satu halaman HTML tanpa framework tambahan.

## 2. Non-goals

- Bukan rewrite UI. Tampilan dan alur v1.6 dipertahankan.
- Bukan multi-user / multi-tenant. Satu operator, satu akun.
- Tidak ada merge akun otomatis (butuh desain terpisah).
- Tidak ada perubahan aturan bisnis diam-diam (lihat §3).
- Tidak ada backend server sendiri; hanya Supabase (Auth + Postgres + RPC).
- Forecast tetap ada dan tidak dihapus.

## 3. Keputusan terbuka (blocker)

Dari audit Fase 1. Default yang direkomendasikan ada di kolom kanan. **Agent tidak boleh memilih sendiri.**

| # | Keputusan | Rekomendasi | Dampak jika salah |
|---|---|---|---|
| D1 | Aturan eligibility patch: hanya akun `Ready`, atau semua akun aktif? | Tentukan eksplisit per patch (`eligibility_rule` di tabel `updates`) | Potensi reward salah hitung |
| D2 | Model akuntansi DM: dihitung dari claims + sources + topups (view), atau ledger transaksi eksplisit? | **View turunan** dari data sumber (tanpa saldo tersimpan) | Hitungan ganda |
| D3 | Reward VC patch: per akun, per patch, atau global? | Per patch, dengan `reward_type` + `reward_amount` di `updates` | Duplikat/penolakan salah |
| D4 | Data Oktober 2026: nyata atau sampel? | Jika nyata: import sebagai histori. Laporan bulanan tetap mulai 1 Nov 2026 | Laporan bulanan salah |
| D5 | Login: magic link email atau email+password? | Magic link / password, 1 user, signup publik dimatikan | Akses tak sah |
| D6 | Hapus cabang: blokir jika masih punya akun? | Blokir (arsipkan cabang) | Orphan data |
| D7 | Apakah file HTML boleh dipakai offline? | Tidak di v2.0; online-only, ekspor JSON tetap ada | Scope membengkak |

## 4. Arsitektur target

```
Browser (single HTML, supabase-js v2 dari CDN, versi di-pin)
   │  HTTPS, JWT user
   ▼
Supabase
  ├─ Auth      : 1 user, signup publik OFF
  ├─ Postgres  : tabel + view + RPC (SQL function), RLS aktif di semua tabel
  └─ (opsional) Storage untuk backup JSON
```

Aturan keamanan:
- Hanya `anon key` + `project URL` di klien. **`service_role` key tidak boleh ada di HTML, repo, atau log.**
- RLS aktif di setiap tabel; policy hanya mengizinkan `auth.uid() = owner_id`.
- Operasi multi-tabel (hapus akun, bulk claim, restore) lewat **RPC transaksional**, bukan beberapa request terpisah dari klien.
- Semua teks pengguna di-escape sebelum masuk `innerHTML` (sudah ada `esc()`, dipertahankan).

## 5. Model data

Konvensi: `id text primary key` (ID lama dipertahankan, misal `acc_w1`), `owner_id uuid not null default auth.uid()`, `created_at timestamptz default now()`. Angka reward: `integer`/`bigint` (tidak ada desimal). Tanggal bisnis: `date`.

| Tabel | Kolom kunci | Constraint penting |
|---|---|---|
| `branches` | branch_id, branch_name, email_login, status, notes | unique(owner_id, lower(branch_name)) |
| `accounts` | account_id, branch_id→branches, server_code, level, status, auto_level_result, notes, status_before_archive, archived_at | unique(owner_id, normalized server_code) **atau** soft-warning (lihat catatan), check level ≥ 1, FK `on delete restrict` |
| `updates` | update_id, update_name, start_date, end_date, status, **reward_type** (DM/VC), **reward_amount**, eligibility_rule, notes | check reward_amount ≥ 0 |
| `claims` | claim_id, update_id→updates, account_id→accounts, **branch_id_at_claim**, eligibility_status, claim_status, reward_type, reward_amount_claimed, claimed_at, notes | **unique(update_id, account_id)**; check claim_status='Claimed' ⇒ claimed_at not null |
| `account_sources` | source_id, account_id→accounts, source_type, nominal, bonus_amount, total_received, received_at, notes | check nominal ≥ 0 |
| `account_topups` | topup_id, account_id→accounts, nominal, bonus_status, bonus_amount, total_received, topup_date, bonus_claim_date | check nominal ≥ 0 |
| `vc_transactions` | transaction_id, account_id (**nullable** = global), source, vc_earned, vc_spent, transaction_date, description | check earned ≥ 0 and spent ≥ 0 and (earned>0 or spent>0); **tanpa kolom saldo tersimpan** |
| `settings` | key, value (jsonb) | termasuk `bbc_to_diamond_rate`=5, `vc_to_diamond_rate`=1, `monthly_tracking_start`='2026-11-01' |
| `activity_logs` | log_id, action, entity_type, entity_id, old_value jsonb, new_value jsonb, created_at | **append-only**: tidak ada policy UPDATE/DELETE; tombol "Clear Log" dihapus |

Catatan server_code: pilih salah satu (dicatat sebagai keputusan D8 saat Fase 1b): (a) unique index keras, atau (b) tidak unik tetapi UI memperingatkan seperti v1.6. Karena v1.6 mengizinkan duplikat setelah peringatan, **default (b)** agar data lama tidak ditolak saat import; sediakan view `v_duplicate_accounts`.

### 5.1 View turunan (satu sumber untuk semua angka)

- `v_account_totals` — per akun: DM dari claims berstatus Claimed (reward_type=DM) + sources bertipe DM + topups; VC dari vc_transactions; **dipakai oleh Dashboard, tabel Accounts, Branch Performance, Calculator, Monthly Report**.
- `v_global_totals` — total DM, BBCoin (= DM), VC earned/spent/balance, estimasi diamond (5 BBC = 1💎, 1 VC = 1💎).
- `v_monthly_totals` — earned/spent per bulan, mulai dari `monthly_tracking_start`; saldo lifetime tidak direset.
- `v_branch_performance` — jumlah akun aktif/arsip, completion rate claim, DM aktual per cabang.
- `v_patch_summary` — per update: total/eligible/claimed/pending/failed/not-eligible, potensi vs aktual (potensi **tidak** masuk saldo).

### 5.2 RPC (transaksional)

| RPC | Perilaku |
|---|---|
| `create_update(...)` | Membuat patch + membuat claim **sekali** untuk akun aktif yang eligible (bukan saat render) |
| `bulk_claim(update_id, account_ids[], amount)` | Validasi eligibility, lewati akun arsip/Not Eligible, idempotent (ulang tidak menggandakan), tulis log |
| `set_claim_status(...)` | Pending/Claimed/Failed/Not Eligible; Pending mengembalikan reward aktual ke 0 |
| `archive_account` / `restore_account` | Atur status + `status_before_archive` |
| `delete_account(account_id)` | Satu transaksi: hapus claims/sources/topups/vc_transactions milik akun; **tidak** menyentuh VC global; tolak jika saldo VC jadi negatif; tulis log berisi data yang dihapus |
| `delete_branch(branch_id)` | Tolak jika masih ada akun |
| `restore_snapshot` / `export_all` | Backup JSON penuh |

## 6. Rencana migrasi

**Fase 0 — Persiapan (wajib sebelum apa pun)**
- Operator mengunduh **Backup JSON dari v1.6** dan menyimpannya. File ini = titik rollback.
- Catat angka acuan dari aplikasi lama (lihat §9).

**Fase 1 — Audit & desain (tanpa mengubah kode aplikasi)**
- Audit sesuai §8, hasilkan laporan + keputusan D1–D8.

**Fase 2 — Skema Supabase**
- File SQL bermigrasi (`/supabase/migrations/*.sql`): tabel, constraint, view, RPC, RLS.
- Dites di project Supabase **staging** terlebih dahulu.

**Fase 3 — Import data**
- Skrip import membaca Backup JSON v1.6 → validasi → insert. ID lama dipertahankan.
- Import **idempotent** (upsert), dapat diulang tanpa duplikat.
- Laporan rekonsiliasi otomatis: jumlah baris per tabel dan total angka dibandingkan dengan aplikasi lama.
- Baris yang gagal validasi masuk file `import_rejects.json`, **tidak dibuang diam-diam**.

**Fase 4 — Adaptasi klien**
- Lapisan data (`data-access`) menggantikan `appData` + `saveData()`; UI dipertahankan.
- Hapus `ensureClaimForAccount` dari render; claim dibuat oleh `create_update`.
- Angka di UI dibaca dari view, bukan dihitung ulang di JS.

**Fase 5 — Dual-run (read-only)**
- Versi Supabase dibuka berdampingan dengan v1.6; bandingkan semua angka halaman demi halaman.

**Fase 6 — Cutover**
- Backup terakhir dari v1.6 → import final → verifikasi rekonsiliasi → pakai Supabase. LocalStorage lama **tidak dihapus**; tetap sebagai cadangan.

**Rollback:** v1.6 + Backup JSON tetap utuh dan bisa dipakai kapan saja. Untuk Supabase, simpan dump SQL sebelum tiap migrasi skema.

## 7. Perubahan perilaku yang disengaja (perlu persetujuan)

1. DM total hanya punya **satu** definisi (D2). Angka Dashboard dan per-akun akan sama; salah satu dari 2.712/2.812 akan berubah.
2. Saldo VC tidak lagi disimpan per baris; dihitung dari transaksi.
3. Claim dibuat saat patch dibuat, bukan saat halaman dibuka.
4. Log aktivitas tidak bisa dihapus.
5. Hapus cabang diblokir jika masih ada akun.
6. Bulk Claim mengisi reward default dari patch (bukan 0 DM).

Setiap poin harus tercatat di changelog dengan angka sebelum/sesudah.

## 8. Cakupan audit

Agent melakukan audit ini **sebelum** dan **sesudah** migrasi. Output tiap audit: temuan, tingkat risiko, bukti (file/baris/query), rekomendasi.

1. **Audit kode** — semua tempat yang membaca/menulis `appData`, `localStorage`, `saveData`; fungsi tanpa definisi; kode mati; `innerHTML` tanpa escape; fungsi yang menghitung total sendiri (target: hanya baca dari view).
2. **Audit data** — cek data Backup JSON: ID duplikat, referensi yatim (account_id/branch_id/update_id tidak ada), claim ganda per (update, akun), nilai negatif, tanggal tidak valid, status di luar enum, source duplikat (contoh `src_2` vs `tp_1`).
3. **Audit skema** — setiap tabel punya PK, FK, check, index untuk kolom filter (account_id, update_id, branch_id, tanggal); tidak ada kolom turunan yang disimpan.
4. **Audit keamanan** — RLS aktif di semua tabel (cek via `pg_tables.rowsecurity`); policy diuji dengan role `anon` (harus ditolak); tidak ada `service_role` di klien/repo; signup publik mati; CSP/CDN di-pin versinya; tidak ada secret di git history.
5. **Audit perhitungan** — rekonsiliasi angka lama vs baru (§9); tes: potensi tidak masuk saldo, reward tidak dihitung dua kali, VC tidak bercampur DM, lifetime tidak reset tiap bulan.
6. **Audit alur** — Patch (buat, claim, bulk, pending, failed, reopen), Akun (tambah, edit, pindah cabang, arsip, restore, hapus), Cabang, CSV import/export, Backup/Restore.
7. **Audit performa & keandalan** — jumlah request per halaman, N+1 query, penanganan error jaringan (pesan jelas, tidak ada data hilang diam-diam), double-submit.
8. **Audit regresi UI** — semua 14 tab dimuat tanpa error konsol; desktop dan mobile.

## 9. Kriteria penerimaan

Angka acuan seed v1.6 (ganti dengan angka data nyata saat Fase 0):

| Metrik | Nilai acuan |
|---|---|
| Jumlah cabang / akun | 4 / 33 |
| Lifetime DM (Dashboard) | 2.712 → setelah D2 harus sama di semua halaman |
| Saldo VC | 350 |
| 5 BBC = 1💎, 1 VC = 1💎 | tidak berubah |

Selesai jika:
- Rekonsiliasi: jumlah baris per tabel sama, total DM/VC/diamond sama (atau selisih dijelaskan di changelog).
- Tidak ada baris yatim; tidak ada claim ganda.
- Tes RLS: request tanpa login atau user lain ditolak.
- Semua alur §8.6 lulus tes di browser sungguhan; konsol tanpa error.
- Backup JSON bisa diekspor dari Supabase dan di-restore ke project kosong dengan hasil identik.
- Rollback ke v1.6 terbukti bisa dilakukan.
- Tidak ada klaim "sudah dites" tanpa hasil tes yang dijalankan.

## 10. Risiko

| Risiko | Mitigasi |
|---|---|
| Angka berubah setelah D2 | Rekonsiliasi + changelog sebelum/sesudah, persetujuan operator |
| Data lama punya duplikat/yatim | Laporan audit data + `import_rejects.json`, tidak dibuang |
| Kebocoran key | Hanya anon key di klien, RLS, pemeriksaan git history |
| Project Supabase free tier ter-pause saat tidak aktif | Catat di README, jadwalkan backup berkala, pertimbangkan upgrade |
| Operasi multi-langkah gagal di tengah | Semua lewat RPC transaksional |
| Scope membengkak | Non-goals §2; perubahan di luar PRD butuh persetujuan |

## 11. Fase & deliverable

| Fase | Deliverable | Gerbang persetujuan |
|---|---|---|
| 1 Audit & desain | Laporan audit §8 + keputusan D1–D8 | Operator menyetujui |
| 2 Skema | Migrasi SQL + tes RLS di staging | Operator menyetujui |
| 3 Import | Skrip + laporan rekonsiliasi | Angka cocok |
| 4 Klien | HTML v2.0 + changelog | Tes alur lulus |
| 5 Dual-run | Tabel perbandingan angka | Selisih nol/terjelaskan |
| 6 Cutover | Checklist cutover + rollback plan | Operator menyetujui |

## 12. Yang dibutuhkan dari operator

1. Jawaban D1–D8.
2. Backup JSON dari v1.6 (data nyata).
3. Project Supabase (staging dulu): URL + anon key. **Jangan kirim service_role key.**
4. Konfirmasi apakah data Oktober nyata.
