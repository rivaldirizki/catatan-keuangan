# Catatan Keuangan Multi-User & Keluarga - Implementation Plan
## Stack: Node.js + MySQL (Backend & Admin) & Flutter (Frontend Client)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun ekosistem aplikasi catatan keuangan (*Personal & Family Finance Tracker*) multi-user modern dengan **Backend & Admin Web berbasis Node.js & MySQL**, serta **Frontend Client berbasis Flutter** (Cross-Platform Mobile/Web). Mendukung isolasi data user, fitur Keluarga (*Family Group Sharing*), pencatatan Pemasukan, Pengeluaran, Tabungan (*savings vault*: saldo keluar dompet namun tabungan bertambah), serta Manajemen Hutang & Piutang dengan sistem tanggal jatuh tempo (*due date alert*).

**Architecture:**
- **Backend & Admin:** Arsitektur modular REST API berbasis Express.js / Node.js dengan database MySQL (`mysql2/promise` pool & ACID transaction). Menyediakan autentikasi JWT untuk Flutter client dan session/dashboard untuk Web Admin.
- **Frontend App:** Aplikasi Flutter berbasis Material 3 dengan *State Management* (Provider / Riverpod), menerapkan prinsip *UI/UX Pro Max* (Fintech design token, palet warna berstandar WCAG AA, navigasi deklaratif, dan performa widget optimal).

**Tech Stack:**
- **Backend:** Node.js (Express.js, JWT, bcryptjs, mysql2)
- **Database:** MySQL (XAMPP MySQL `localhost:3306`)
- **Admin Panel:** Web Admin terintegrasi pada Node.js
- **Frontend:** Flutter 3.x / Dart 3.x (Material 3, Provider/Riverpod, FL Chart, Lucide/Material Icons)
- **Testing:** Jest / Supertest (Backend TDD) & Flutter Test (Frontend TDD)
- **Design & Skills Reference:**
  - `skills/mattpocock-skills`: `domain-modeling`, `codebase-design`, `tdd`
  - `skills/superpowers`: `writing-plans`, `test-driven-development`, `verification-before-completion`
  - `skills/ui-ux-pro-max-skill`: `Financial Dashboard` tokens & `flutter.csv` best practices

**Spec:** `PLAN.md`

## Global Constraints

- **Stack Boundary:** Backend dan Admin wajib menggunakan **Node.js & MySQL**. Frontend klien wajib menggunakan **Flutter**.
- **Multi-Tenancy & Data Privacy:** Setiap query data pada API diproteksi oleh middleware JWT dan scoped oleh `user_id`, kecuali entitas dengan `family_id` sama dan bertipe `family_shared`.
- **Presisi Nilai Mata Uang:** Nominal uang disimpan dalam format Integer Rupiah (`BIGINT` di MySQL, `int` di Dart).
- **Integritas Mutasi Tabungan:** Penyetoran dan penarikan tabungan wajib atomic menggunakan MySQL `START TRANSACTION`, `COMMIT`, dan `ROLLBACK`.
- **Status Jatuh Tempo Hutang:** Status hutang dihitung secara dinamis (`unpaid`, `partially_paid`, `paid`, `overdue` jika `due_date < CURRENT_DATE`).
- **UI/UX Pro Max Flutter Standard:** Standar Material 3, `const constructor`, pemisahan widget, touch targets $\ge 44\times 44$ px, zero emoji.

---

### Task 1: Backend Scaffolding & MySQL Database Schema Setup
**Files:**
- Create: `backend/package.json`
- Create: `backend/src/config/database.js`
- Create: `backend/database/schema.sql`
- Create: `backend/database/migrate.js`
- Test: `backend/tests/database.test.js`

- [ ] **Step 1: Write failing database connection & schema test**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `backend/src/config/database.js` & `backend/database/schema.sql`**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Write failing unit & API tests for Auth and Family invite logic**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement AuthService, FamilyService, dan JWT Auth Middleware**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 3: Wallets & Transaction Service with Family Scope (Backend TDD)
**Files:**
- Create: `backend/src/services/wallet.service.js`
- Create: `backend/src/services/transaction.service.js`
- Create: `backend/src/controllers/wallet.controller.js`
- Create: `backend/src/controllers/transaction.controller.js`
- Test: `backend/tests/transaction.test.js`

- [ ] **Step 1: Write failing test for wallet balance updates and data isolation**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement transaction logic with MySQL ACID transaction**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 4: Tabungan / Savings Vault Service (Backend TDD)
**Files:**
- Create: `backend/src/services/saving.service.js`
- Create: `backend/src/controllers/saving.controller.js`
- Test: `backend/tests/saving.test.js`

- [ ] **Step 1: Write failing test for savings deposit mechanism**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `saving.service.js` dengan MySQL atomic transaction**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 5: Hutang, Piutang & Sistem Jatuh Tempo (Backend TDD)
**Files:**
- Create: `backend/src/services/debt.service.js`
- Create: `backend/src/controllers/debt.controller.js`
- Test: `backend/tests/debt.test.js`

- [ ] **Step 1: Write failing test for debt status calculation and installment payments**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `debt.service.js` dengan penanganan jatuh tempo dan pembayaran**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 6: Web Admin Dashboard (Node.js)
**Files:**
- Create: `backend/src/routes/admin.routes.js`
- Create: `backend/src/controllers/admin.controller.js`
- Create: `backend/src/views/admin/`
- Test: `backend/tests/admin.test.js`

- [ ] **Step 1: Write failing test for admin route access control**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement admin dashboard & management endpoints**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 7: Flutter Frontend Scaffolding, Models & API Client
**Files:**
- Create: `frontend/pubspec.yaml`
- Create: `frontend/lib/core/constants/api_constants.dart`
- Create: `frontend/lib/core/theme/app_theme.dart`
- Create: `frontend/lib/core/network/api_client.dart`
- Create: `frontend/lib/models/` (User, Wallet, Transaction, Saving, Debt)
- Test: `frontend/test/models_test.dart`

- [ ] **Step 1: Write test for model JSON serialization/deserialization**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement Flutter models, API client, and theme tokens**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 8: Flutter State Management & Authentication Screens
**Files:**
- Create: `frontend/lib/providers/auth_provider.dart`
- Create: `frontend/lib/screens/auth/login_screen.dart`
- Create: `frontend/lib/screens/auth/register_screen.dart`
- Create: `frontend/lib/screens/splash_screen.dart`
- Test: `frontend/test/auth_provider_test.dart`

- [ ] **Step 1: Write test for AuthProvider state mutations**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement Login & Register UI with responsive layout**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 9: Flutter Financial Dashboard & Family Switcher
**Files:**
- Create: `frontend/lib/providers/finance_provider.dart`
- Create: `frontend/lib/screens/dashboard/dashboard_screen.dart`
- Create: `frontend/lib/widgets/balance_card.dart`
- Create: `frontend/lib/widgets/cashflow_chart.dart`
- Create: `frontend/lib/widgets/family_switcher.dart`

- [ ] **Step 1: Implement FinanceProvider to fetch summary, wallets, and family state**
- [ ] **Step 2: Build Dashboard widgets with const constructors and clean layout**
- [ ] **Step 3: Test dashboard rendering & family toggle state switch**
- [ ] **Step 4: Commit**

---

### Task 10: Flutter Modules: Transaksi, Tabungan, & Hutang-Piutang
**Files:**
- Create: `frontend/lib/screens/transactions/`
- Create: `frontend/lib/screens/savings/`
- Create: `frontend/lib/screens/debts/`
- Create: `frontend/lib/widgets/due_date_badge.dart`

- [ ] **Step 1: Implement Transactions screen & modal**
- [ ] **Step 2: Implement Savings Vault screen & deposit modal**
- [ ] **Step 3: Implement Debts screen with due date badges & payment modal**
- [ ] **Step 4: Widget testing for touch targets (>= 44px) and form validations**
- [ ] **Step 5: Commit**

---

### Task 11: Comprehensive Verification & Delivery
**Files:**
- Create: `README.md`
- Test: Backend integration tests (`npm test`) & Flutter tests (`flutter test`)

- [ ] **Step 1: Execute all backend unit & integration tests**
- [ ] **Step 2: Execute Flutter tests & analyze code**
- [ ] **Step 3: Pre-delivery checklist audit (UI/UX Pro Max)**
- [ ] **Step 4: Documentation and final commit**
