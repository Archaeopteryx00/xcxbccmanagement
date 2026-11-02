# XCX BBC Management

A single-operator game account and currency tracking management application (DM, BBCoin, VC, and Diamond estimation) migrated to Supabase (PostgreSQL, Analytical Views, Transactional RPC, and Row Level Security).

---

## 📁 Repository Structure

```text
├── AGENTS.md                          # Coding & auditing rules for agents
├── PRD_XCX_BBC_Supabase_Migration.md  # Migration specification & decisions
├── README.md                          # Project overview & documentation
├── index.html                         # Main Web Application client
├── package.json                       # Node.js project & dependencies
│
├── legacy/                            # Reference legacy versions
│   └── XCX_BBC_Management_v1.6.html  # Untouched backup of v1.6
│
├── server/                            # Node.js / Express API Microservice
│   ├── server.js                      # Microservice entry point & REST endpoints
│   ├── supabase.js                    # Scoped Supabase client with RLS support
│   └── README.md                      # Microservice endpoint documentation
│
├── services/                          # Client-side integration services
│   ├── apiService.js                  # Frontend API client SDK
│   └── appBridge.js                   # Live UI synchronization bridge
│
├── supabase/                          # Database schema & migrations
│   ├── README.md                      # Database administration & migration guide
│   ├── config.toml                    # Supabase CLI configuration
│   ├── seed_import.sql                # Idempotent data import script
│   ├── migrations/
│   │   ├── 001_schema.sql             # Tables, constraints, and indexes
│   │   ├── 002_views.sql              # Analytical views (single source of truth)
│   │   ├── 003_functions.sql          # Transactional RPC functions
│   │   └── 004_rls.sql                # Row Level Security (RLS) policies
│   └── tests/
│       └── 01_test_suite.sql          # Database test suite
│
├── reports/                           # Audit & reconciliation reports
│   ├── data_reconciliation_report.md  # Backup import reconciliation metrics
│   ├── db_setup_report.md             # Schema & RLS audit test results
│   └── import_rejects.json            # Rejected data records (0 rejected)
│
└── scripts/                           # Database testing & generation utilities
    ├── audit_backup_data.js           # Backup JSON verification tool
    ├── generate_seed_sql.js           # Idempotent SQL import generator
    ├── test_runner.js                 # PostgreSQL 16 WASM migration test harness
    └── test_seed_import.js            # Seed import validator
```

---

## 🚀 Quick Start

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Environment
Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```
Fill in your Supabase credentials:
```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your-publishable-anon-key
```

### 3. Run Microservice
```bash
npm start
```
The server will run on `http://localhost:3001`.

### 4. Open Application
Open `index.html` in your browser. The header will indicate **Microservice Connected**, and you can log in to view synchronized Supabase data.

---

## 🔒 Security & Data Integrity
- **Row Level Security (RLS)** is enabled and forced on all tables.
- **Analytical Views** serve as the single source of truth for all balances.
- **Append-only Logs**: `activity_logs` records cannot be updated or deleted.
- **Transactional RPCs**: Destructive actions (e.g. deleting an account) run as a single atomic transaction.
