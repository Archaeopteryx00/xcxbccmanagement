# XCX BBC Management — API Microservice

Layanan backend microservice ringan berbasis Node.js/Express yang menghubungkan aplikasi frontend XCX BBC Management dengan Supabase (Postgres, RLS, Views, dan RPC Functions).

---

## 1. Arsitektur

```text
[ Browser / Frontend ]
         │
         │ HTTP / JSON
         ▼
[ Express Microservice ] (Port 3001)
         │
         │ Supabase Client (dengan User Bearer JWT)
         ▼
[ Supabase Staging ]
   ├─ Postgres Views  (v_global_totals, v_account_totals, v_patch_summary)
   ├─ RPC Functions   (bulk_claim, create_update, delete_account, delete_branch)
   └─ RLS Enforcement (Setiap request dibatasi oleh owner_id = auth.uid())
```

---

## 2. Cara Menjalankan Microservice

Pastikan dependency sudah terinstall, lalu jalankan:

```powershell
# Jalankan server
npm start
```

Server akan aktif di:
- **Base URL:** `http://localhost:3001/api`
- **Health Check:** `http://localhost:3001/api/health`

---

## 3. Daftar Endpoint API

### Autentikasi
| Method | Endpoint | Deskripsi |
| :--- | :--- | :--- |
| `POST` | `/api/auth/login` | Login menggunakan email & password (`{ email, password }`) |
| `POST` | `/api/auth/logout` | Logout sesi user saat ini |
| `GET` | `/api/auth/user` | Mendapatkan data user yang sedang login |

### Overview & Database Views (Single Source of Truth)
| Method | Endpoint | Deskripsi |
| :--- | :--- | :--- |
| `GET` | `/api/overview` | Mengambil `v_global_totals`, `v_branch_performance`, `v_patch_summary`, dan `v_monthly_totals` |

### Akun (`accounts`)
| Method | Endpoint | Deskripsi |
| :--- | :--- | :--- |
| `GET` | `/api/accounts` | Mengambil seluruh akun berserta saldo DM/VC dari view `v_account_totals` |
| `POST` | `/api/accounts` | Menambahkan akun baru |
| `PUT` | `/api/accounts/:id` | Mengedit akun |
| `POST` | `/api/accounts/:id/archive` | Mengarsipkan akun (memanggil RPC `archive_account`) |
| `POST` | `/api/accounts/:id/restore` | Mengembalikan akun arsip (memanggil RPC `restore_account`) |
| `DELETE` | `/api/accounts/:id` | Menghapus akun secara atomik aman (memanggil RPC `delete_account`) |

### Cabang (`branches`)
| Method | Endpoint | Deskripsi |
| :--- | :--- | :--- |
| `GET` | `/api/branches` | Mengambil daftar cabang |
| `POST` | `/api/branches` | Menambahkan cabang |
| `PUT` | `/api/branches/:id` | Mengedit cabang |
| `DELETE` | `/api/branches/:id` | Menghapus cabang (memanggil RPC `delete_branch`) |

### Patch & Klaim (`updates` & `claims`)
| Method | Endpoint | Deskripsi |
| :--- | :--- | :--- |
| `GET` | `/api/updates` | Mengambil daftar patch dan klaim |
| `POST` | `/api/updates` | Membuat patch baru dan auto-generate claim (memanggil RPC `create_update`) |
| `POST` | `/api/updates/:id/bulk-claim` | Klaim massal reward (memanggil RPC `bulk_claim`) |
| `POST` | `/api/claims/:id/status` | Ubah status klaim (memanggil RPC `set_claim_status`) |

### Transaksi & Backup
| Method | Endpoint | Deskripsi |
| :--- | :--- | :--- |
| `GET` / `POST` | `/api/sources` | Riwayat & penambahan account sources |
| `GET` / `POST` | `/api/topups` | Riwayat & penambahan topup |
| `GET` / `POST` | `/api/vc` | Transaksi VC (akun & global) |
| `GET` | `/api/logs` | Log aktivitas |
| `GET` | `/api/backup/export` | Backup lengkap satu database JSON (memanggil RPC `export_all`) |
