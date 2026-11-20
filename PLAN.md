# Project Catatan Keuangan Multi-User & Keluarga - Implementation Plan
## Stack: Node.js + MySQL (Backend & Admin) & Flutter (Frontend Client)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun ekosistem aplikasi catatan keuangan (*Personal & Family Finance Tracker*) multi-user modern dengan **Backend & Admin Web berbasis Node.js & MySQL**, serta **Frontend Client berbasis Flutter** (Cross-Platform Mobile/Web). Mendukung isolasi data user, fitur Keluarga (*Family Group Sharing*), pencatatan Pemasukan, Pengeluaran, Tabungan (*savings vault*: saldo keluar dompet namun tabungan bertambah), serta Manajemen Hutang & Piutang dengan sistem tanggal jatuh tempo (*due date alert*).

**Architecture:**
- **Backend & Admin:** Arsitektur modular REST API berbasis Express.js / Node.js dengan database MySQL (`mysql2/promise` pool & ACID transaction). Menyediakan autentikasi JWT untuk Flutter client dan session/dashboard untuk Web Admin.
- **Frontend App:** Aplikasi Flutter berbasis Material 3 dengan *State Management* (Provider / Riverpod), menerapkan prinsip *UI/UX Pro Max* (Fintech design token, palet warna berstandar WCAG AA, navigasi deklaratif, dan performa widget optimal).

**Tech Stack:**
- **Backend:** Node.js (ESM / TypeScript-ready, Express.js, JWT, bcryptjs, mysql2)
- **Database:** MySQL (XAMPP MySQL `localhost:3306`)
- **Admin Panel:** Web Admin terintegrasi pada Node.js (Dashboard statistik sistem, manajemen user, monitoring transaksi agregat)
- **Frontend:** Flutter 3.x / Dart 3.x (Material 3, Provider/Riverpod, FL Chart / Custom Painter, Lucide/Material Icons)
- **Testing:** Jest / Supertest (Backend TDD) & Flutter Test / Mockito (Frontend TDD)
- **Design & Skills Reference:**
  - `skills/mattpocock-skills`: `domain-modeling`, `codebase-design`, `tdd`
  - `skills/superpowers`: `writing-plans`, `test-driven-development`, `verification-before-completion`
  - `skills/ui-ux-pro-max-skill`: `Financial Dashboard` tokens & `flutter.csv` best practices (`StatelessWidget`, `const constructors`, `LayoutBuilder`, `PopScope`, touch target $\ge$ 44px, zero emoji)

**Spec Document:** `docs/spec/finance-spec.md`

---

## Global Constraints

- **Stack Boundary:** Backend dan Admin wajib menggunakan **Node.js & MySQL**. Frontend klien wajib menggunakan **Flutter**.
- **Multi-Tenancy & Data Privacy:** Setiap query data pada API diproteksi oleh middleware JWT dan scoped oleh `user_id`, kecuali entitas dengan `family_id` sama dan bertipe `family_shared`.
- **Presisi Nilai Mata Uang:** Nominal uang disimpan dalam format Integer Rupiah (`BIGINT` di MySQL, `int` di Dart) tanpa floating-point untuk menghindari selisih desimal.
- **Integritas Mutasi Tabungan:** Penyetoran dan penarikan tabungan wajib atomic menggunakan MySQL `START TRANSACTION`, `COMMIT`, dan `ROLLBACK`.
- **Status Jatuh Tempo Hutang:** Status hutang dihitung secara dinamis atau flag query (`unpaid`, `partially_paid`, `paid`, `overdue` jika `due_date < CURRENT_DATE`).
- **UI/UX Pro Max Flutter Standard:**
  - ColorScheme: Deep Slate `#0F172A`, Emerald `#10B981` (pemasukan), Crimson `#EF4444` (pengeluaran), Amber `#F59E0B` (jatuh tempo), Accent Blue `#2563EB` (tabungan).
  - Konsistensi Widget: Gunakan `const constructor`, pisahkan widget besar menjadi komponen terisolasi, touch targets $\ge 44\times 44$ px, larang keras penggunaan emoji sebagai icon UI.

---

## Review Focus (Edge Cases & Safety)

1. **Isolasi Data API:** Pengguna A tidak boleh dapat membaca/mengubah data Pengguna B melalui manipulasi ID pada parameter REST API.
2. **Keluarga / Family Sharing Permission:** User dapat beralih antara filter tampilan *Personal Only* dan *Seluruh Keluarga* tanpa kebocoran data keluarga lain.
3. **Penyetoran Tabungan (Savings Vault):** Pemotongan saldo dompet dan penambahan saldo tabungan harus strictly atomic; kegagalan salah satu harus membatalkan seluruh operasi.
4. **Cicilan & Pelunasan Hutang:** Pembayaran parsial harus mengurangi `remaining_amount`, dan jika sisa menjadi 0, status otomatis berubah menjadi `paid`.
5. **Koneksi Pool MySQL:** Koneksi database harus menggunakan pooling dengan auto-reconnect dan sanitasi parameterized queries (`?`) untuk mencegah SQL Injection.

---

## Domain Model Breakdown (`mattpocock-skills:domain-modeling`)

1. **`users`**: `id`, `name`, `email`, `password_hash`, `role` (`user` | `admin`), `family_id` (nullable), `created_at`
2. **`families`**: `id`, `name`, `invite_code` (unique 8-char), `created_by`, `created_at`
3. **`wallets`**: `id`, `user_id`, `family_id` (nullable), `name` (Kas Tunai, Rekening BCA, GoPay), `balance` (`BIGINT`), `scope` (`personal` | `family`)
4. **`categories`**: `id`, `user_id` (nullable for defaults), `name`, `type` (`income` | `expense`), `icon`, `color`
5. **`transactions`**: `id`, `user_id`, `wallet_id`, `category_id`, `type` (`income` | `expense` | `transfer` | `saving_deposit` | `debt_payment`), `amount` (`BIGINT`), `transaction_date`, `notes`, `destination_id`
6. **`savings`** (Tabungan / Goal): `id`, `user_id`, `family_id` (nullable), `goal_name` (Dana Darurat, Rumah, Liburan), `target_amount` (`BIGINT`), `current_amount` (`BIGINT`), `target_date`, `status` (`active` | `completed`)
7. **`debts`** (Hutang & Piutang): `id`, `user_id`, `family_id` (nullable), `type` (`payable` / hutang kita, `receivable` / piutang orang lain), `person_name`, `total_amount` (`BIGINT`), `remaining_amount` (`BIGINT`), `due_date`, `status` (`unpaid` | `partially_paid` | `paid` | `overdue`), `notes`

---

## Task Decomposition

### Task 1: Backend Scaffolding & MySQL Database Schema Setup
**Files:**
- Create: `backend/package.json`
- Create: `backend/src/config/database.js`
- Create: `backend/database/schema.sql`
- Create: `backend/database/migrate.js`
- Test: `backend/tests/database.test.js`

**Interfaces:**
- Produces: `db.pool` (MySQL2 connection pool instance) and auto-migration script.

- [ ] **Step 1: Write failing database connection & schema test**
  Uji koneksi ke MySQL XAMPP (`localhost:3306`, user `root`, database `finance_db`) dan validasi keberadaan 7 tabel inti.
- [ ] **Step 2: Run test to verify it fails**
  Run: `npm test` di folder `backend/`
  Expected: FAIL (Database config not found).
- [ ] **Step 3: Implement `backend/src/config/database.js` & `backend/database/schema.sql`**
  Konfigurasikan `mysql2/promise` pool dengan auto-creation database dan eksekusi skema SQL.
- [ ] **Step 4: Run test to verify it passes**
  Run: `npm test`
  Expected: PASS (Koneksi pool stabil dan skema terpasang).
- [ ] **Step 5: Commit**
  `git add backend/ && git commit -m "feat: setup node.js backend scaffolding and mysql schema"`

---

### Task 2: Auth Service, JWT Middleware & Family Grouping (Backend TDD)
**Files:**
- Create: `backend/src/services/auth.service.js`
- Create: `backend/src/services/family.service.js`
- Create: `backend/src/middleware/auth.middleware.js`
- Create: `backend/src/controllers/auth.controller.js`
- Create: `backend/src/controllers/family.controller.js`
- Test: `backend/tests/auth.test.js`
- Test: `backend/tests/family.test.js`

**Interfaces:**
- Produces:
  - `POST /api/v1/auth/register` (menghasilkan JWT token)
  - `POST /api/v1/auth/login` (verifikasi email & bcrypt hash)
  - `POST /api/v1/family/create` (menghasilkan unique `invite_code`)
  - `POST /api/v1/family/join` (menghubungkan user ke family_id)
  - `GET /api/v1/family/members`

- [ ] **Step 1: Write failing unit & API tests for Auth and Family invite logic**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement AuthService, FamilyService, dan JWT Auth Middleware**
- [ ] **Step 4: Run test to verify it passes**
  Expected: PASS (Token JWT valid, password terenkripsi, invite code keluarga berfungsi).
- [ ] **Step 5: Commit**
  `git add backend/src/ backend/tests/ && git commit -m "feat: implement auth service and family grouping"`

---

### Task 3: Wallets & Transaction Service with Family Scope (Backend TDD)
**Files:**
- Create: `backend/src/services/wallet.service.js`
- Create: `backend/src/services/transaction.service.js`
- Create: `backend/src/controllers/wallet.controller.js`
- Create: `backend/src/controllers/transaction.controller.js`
- Test: `backend/tests/transaction.test.js`

**Interfaces:**
- Produces:
  - `POST /api/v1/transactions/income`
  - `POST /api/v1/transactions/expense`
  - `POST /api/v1/transactions/transfer` (atomic antar dompet)
  - `GET /api/v1/transactions` (filter: date range, category, wallet, personal vs family scope)
  - `GET /api/v1/transactions/summary` (total balance, monthly cashflow)

- [ ] **Step 1: Write failing test for wallet balance updates and data isolation**
  Pastikan user tidak dapat melihat transaksi user lain kecuali terdaftar di `family_id` yang sama.
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement transaction logic with MySQL transaction (`BEGIN`, `COMMIT`, `ROLLBACK`)**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**
  `git add backend/src/ backend/tests/ && git commit -m "feat: implement wallets and transactions with personal and family scoping"`

---

### Task 4: Tabungan / Savings Vault Service (Backend TDD)
**Files:**
- Create: `backend/src/services/saving.service.js`
- Create: `backend/src/controllers/saving.controller.js`
- Test: `backend/tests/saving.test.js`

**Interfaces:**
- Produces:
  - `POST /api/v1/savings/goals` (buat target tabungan: nama, target, tanggal)
  - `POST /api/v1/savings/deposit` (potong saldo dompet, tambah saldo tabungan secara atomic)
  - `POST /api/v1/savings/withdraw` (penarikan saldo tabungan kembali ke dompet)
  - `GET /api/v1/savings` (daftar tabungan dengan kalkulasi progress persentase)

- [ ] **Step 1: Write failing test for savings deposit mechanism**
  Uji bahwa deposit tabungan otomatis mendebit dompet dan mengkredit tabungan, mencatat log transaksi, serta membatalkan operasi jika saldo dompet tidak cukup.
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `saving.service.js` dengan MySQL atomic transaction**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**
  `git add backend/src/ backend/tests/ && git commit -m "feat: implement savings vault deposit and goal tracking"`

---

### Task 5: Hutang, Piutang & Sistem Jatuh Tempo (Backend TDD)
**Files:**
- Create: `backend/src/services/debt.service.js`
- Create: `backend/src/controllers/debt.controller.js`
- Test: `backend/tests/debt.test.js`

**Interfaces:**
- Produces:
  - `POST /api/v1/debts` (catat hutang/piutang baru, nama pihak, nominal, tanggal jatuh tempo)
  - `POST /api/v1/debts/:id/pay` (catat cicilan/pelunasan, potong dompet, update sisa hutang)
  - `GET /api/v1/debts` (daftar hutang dengan auto-tag status: `overdue`, `due_soon`, `unpaid`, `paid`)
  - `GET /api/v1/debts/upcoming` (peringatan jatuh tempo dalam N hari)

- [ ] **Step 1: Write failing test for debt status calculation and installment payments**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `debt.service.js` dengan penanganan jatuh tempo dan pembayaran**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**
  `git add backend/src/ backend/tests/ && git commit -m "feat: implement debts and due date management"`

---

### Task 6: Web Admin Dashboard (Node.js)
**Files:**
- Create: `backend/src/routes/admin.routes.js`
- Create: `backend/src/controllers/admin.controller.js`
- Create: `backend/src/views/admin/` (atau HTML/Tailwind SPA untuk admin)
- Test: `backend/tests/admin.test.js`

**Interfaces:**
- Produces:
  - `GET /admin/dashboard`: Ringkasan total pengguna, total keluarga aktif, volume transaksi sistem.
  - `GET /admin/users`: Daftar pengguna sistem, status keluarga, tanggal registrasi.
  - Middleware proteksi: `requireAdmin` (hanya user dengan `role: 'admin'`).

- [ ] **Step 1: Write failing test for admin route access control**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement admin dashboard & management endpoints**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**
  `git add backend/src/ && git commit -m "feat: implement node.js web admin dashboard"`

---

### Task 7: Flutter Frontend Scaffolding, Models & API Client
**Files:**
- Create: `frontend/pubspec.yaml`
- Create: `frontend/lib/core/constants/api_constants.dart`
- Create: `frontend/lib/core/theme/app_theme.dart` (UI/UX Pro Max Fintech Theme)
- Create: `frontend/lib/core/network/api_client.dart`
- Create: `frontend/lib/models/user_model.dart`
- Create: `frontend/lib/models/wallet_model.dart`
- Create: `frontend/lib/models/transaction_model.dart`
- Create: `frontend/lib/models/saving_model.dart`
- Create: `frontend/lib/models/debt_model.dart`
- Test: `frontend/test/models_test.dart`

**UI/UX Pro Max Flutter Guidelines:**
- `ThemeData` berbasis `ColorScheme` Material 3 (Primary `#0F172A`, Secondary Emerald `#10B981`, Error Crimson `#EF4444`, Amber `#F59E0B`).
- Type-safe JSON serialization, penanganan network error, dan interceptor token JWT otomatis.

- [ ] **Step 1: Write test for model JSON serialization/deserialization**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement Flutter models, API client, and theme tokens**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**
  `git add frontend/ && git commit -m "feat: scaffold flutter app with fintech theme and models"`

---

### Task 8: Flutter State Management & Authentication Screens
**Files:**
- Create: `frontend/lib/providers/auth_provider.dart`
- Create: `frontend/lib/screens/auth/login_screen.dart`
- Create: `frontend/lib/screens/auth/register_screen.dart`
- Create: `frontend/lib/screens/splash_screen.dart`
- Test: `frontend/test/auth_provider_test.dart`

- [ ] **Step 1: Write test for AuthProvider state mutations (loading, success, error)**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement Login & Register UI with responsive layout, clear error feedback, and secure token storage**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**
  `git add frontend/lib/ && git commit -m "feat: implement flutter auth provider and screens"`

---

### Task 9: Flutter Financial Dashboard & Family Switcher
**Files:**
- Create: `frontend/lib/providers/finance_provider.dart`
- Create: `frontend/lib/screens/dashboard/dashboard_screen.dart`
- Create: `frontend/lib/widgets/balance_card.dart`
- Create: `frontend/lib/widgets/cashflow_chart.dart`
- Create: `frontend/lib/widgets/family_switcher.dart`

**UI/UX Details:**
- Card Ringkasan: Total Saldo Aktif, Total Masuk, Total Keluar, Saldo Tabungan.
- Switcher: Toggle mudah antara "Keuangan Pribadi" vs "Keuangan Keluarga".
- Visual Chart: Grafik batang/garis pemasukan vs pengeluaran bulanan.

- [ ] **Step 1: Implement FinanceProvider to fetch summary, wallets, and family state**
- [ ] **Step 2: Build Dashboard widgets with const constructors and clean layout**
- [ ] **Step 3: Test dashboard rendering & family toggle state switch**
- [ ] **Step 4: Commit**
  `git add frontend/lib/ && git commit -m "feat: implement flutter dashboard and family switcher"`

---

### Task 10: Flutter Modules: Transaksi, Tabungan (Savings Vault), & Hutang-Piutang
**Files:**
- Create: `frontend/lib/screens/transactions/transactions_screen.dart`
- Create: `frontend/lib/screens/transactions/add_transaction_modal.dart`
- Create: `frontend/lib/screens/savings/savings_screen.dart`
- Create: `frontend/lib/screens/savings/deposit_modal.dart`
- Create: `frontend/lib/screens/debts/debts_screen.dart`
- Create: `frontend/lib/screens/debts/pay_debt_modal.dart`
- Create: `frontend/lib/widgets/due_date_badge.dart`

**Features:**
- **Add Transaction:** Form cepat dengan format Rupiah otomatis, pilih dompet, kategori, dan scope.
- **Savings Screen:** Visual progress bar (0% - 100%), tombol cepat "Setor Tabungan" (saldo dompet berkurang, tabungan bertambah).
- **Debts Screen:** Filter Hutang vs Piutang, indikator warna jatuh tempo (Overdue merah, Due Soon kuning), tombol cicilan/pelunasan.

- [ ] **Step 1: Implement Transactions screen & modal**
- [ ] **Step 2: Implement Savings Vault screen & deposit modal**
- [ ] **Step 3: Implement Debts screen with due date badges & payment modal**
- [ ] **Step 4: Widget testing for touch targets (>= 44px) and form validations**
- [ ] **Step 5: Commit**
  `git add frontend/lib/ && git commit -m "feat: implement transactions, savings vault, and debts screens"`

---

### Task 11: Comprehensive Verification & Delivery (`superpowers:verification-before-completion`)
**Files:**
- Create: `README.md` (Dokumentasi lengkap: cara menjalankan Node.js backend, setup MySQL, dan menjalankan Flutter app)
- Test: Backend integration tests (`npm test`)
- Test: Flutter tests (`flutter test`)

- [ ] **Step 1: Execute all backend unit & integration tests**
  Command: `cd backend && npm test`
  Expected: 100% tests passing.
- [ ] **Step 2: Execute Flutter tests & analyze code**
  Command: `cd frontend && flutter test`
  Expected: Zero warnings/errors.
- [ ] **Step 3: Pre-delivery checklist audit (UI/UX Pro Max)**
  - [ ] Zero emoji icons used (all official SVG / Material icons).
  - [ ] Touch targets $\ge 44\times 44$ px.
  - [ ] Kontras warna mematuhi WCAG AA.
  - [ ] Due date badges responsif dan akurat.
- [ ] **Step 4: Documentation and final commit**
