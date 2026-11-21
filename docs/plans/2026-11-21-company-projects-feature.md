# Fitur Perusahaan & Manajemen Proyek (Company & Project Cashflow) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Membangun ruang kerja bisnis "Perusahaan" dengan sistem multi-anggota (Buat & Gabung via Kode ID unik 8 karakter) dan fitur "Project", di mana setiap anggota tim perusahaan dapat mencatat pemasukan (revenue/invoice) dan pengeluaran (operational/vendor cost) per project, memantau anggaran (budget), serta melihat laporan laba/rugi dan riwayat transaksi proyek secara transparan.

**Architecture:** Menerapkan arsitektur 3-Workspace Context (*Pribadi*, *Keluarga*, *Perusahaan*) yang konsisten pada stack MySQL + Express.js backend dan Flutter frontend. Relasi database menghubungkan `companies` ke `users` via `company_id`, memiliki entitas `projects` (anggaran, pemasukan, pengeluaran), serta relasi transaksi multi-scope (`company_id`, `project_id`). Frontend mengadopsi Apple iOS 18 Design System dengan 3-way segmented control, Sapphire Navy corporate theme, kartu metrik laba-rugi proyek, dan modal interaktif yang responsif.

**Tech Stack:** 
- Backend: Node.js (v20+), Express.js, MySQL / MySQL2 with Connection Pooling & Transactions, `node:test` (TDD)
- Frontend: Flutter (Dart 3+), Provider (State Management), Material 3 with Apple iOS HIG (Human Interface Guidelines), Intl (IDR Currency Formatting)

---

### Task 1: Database Schema Migration & Mock Relational Store

**Files:**
- Modify: `backend/database/schema.sql`
- Modify: `backend/src/config/database.js`
- Test: `backend/tests/database.test.js`

**Step 1: Write the failing test**
Tambahkan pengujian relasi skema tabel `companies` dan `projects` di `backend/tests/database.test.js`:
```javascript
it('should verify schema contains companies and projects tables with proper foreign keys', async () => {
  assert.strictEqual(db.hasTable('companies'), true);
  assert.strictEqual(db.hasTable('projects'), true);
});
```

**Step 2: Run test to verify it fails**
Run: `npm test` di direktori `backend`
Expected: FAIL dengan assertion `db.hasTable('companies') === false` atau sejenis.

**Step 3: Write minimal implementation**
- Di `backend/database/schema.sql`:
  1. Buat tabel `companies` (`id`, `name`, `invite_code`, `created_by`, `created_at`).
  2. Tambahkan kolom `company_id` pada tabel `users`.
  3. Buat tabel `projects` (`id`, `company_id`, `created_by`, `name`, `description`, `target_budget`, `current_income`, `current_expense`, `status`, `start_date`, `end_date`, `created_at`).
  4. Tambahkan kolom `company_id` dan `project_id` pada tabel `transactions`.
- Di `backend/src/config/database.js`:
  Tambahkan `companies: []` dan `projects: []` pada `MockDatabase.tables`, auto-increments, dan handling query untuk tabel baru.

**Step 4: Run test to verify it passes**
Run: `npm test` di direktori `backend`
Expected: PASS (seluruh test database sukses).

**Step 5: Commit**
```bash
git add backend/database/schema.sql backend/src/config/database.js backend/tests/database.test.js
git commit -m "feat(db): add companies and projects schema with mock database support"
```

---

### Task 2: Backend CompanyService & TDD Unit Tests

**Files:**
- Create: `backend/src/services/company.service.js`
- Create: `backend/tests/company.test.js`

**Step 1: Write the failing test**
Buat test suite `backend/tests/company.test.js`:
```javascript
import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { CompanyService } from '../src/services/company.service.js';

describe('CompanyService (TDD)', () => {
  beforeEach(() => {
    db.mock.reset();
  });

  it('should create a new company with 8-character invite code and link creator', async () => {
    const user = await AuthService.register('CEO Alice', 'alice@company.com', 'secret123');
    const company = await CompanyService.createCompany(user.user.id, 'PT Maju Bersama');
    assert.ok(company.id);
    assert.strictEqual(company.name, 'PT Maju Bersama');
    assert.strictEqual(company.invite_code.length, 8);

    const updatedUser = await AuthService.getUserById(user.user.id);
    assert.strictEqual(updatedUser.company_id, company.id);
  });

  it('should allow another user to join the company via invite code', async () => {
    const ceo = await AuthService.register('CEO', 'ceo@corp.com', 'secret123');
    const staff = await AuthService.register('Staff', 'staff@corp.com', 'secret123');

    const company = await CompanyService.createCompany(ceo.user.id, 'PT Sukses Mandiri');
    const joinRes = await CompanyService.joinCompany(staff.user.id, company.invite_code);
    assert.strictEqual(joinRes.success, true);

    const members = await CompanyService.getCompanyMembers(company.id);
    assert.strictEqual(members.length, 2);
  });

  it('should reject joining with invalid invite code', async () => {
    const user = await AuthService.register('Staff2', 'staff2@corp.com', 'secret123');
    await assert.rejects(async () => {
      await CompanyService.joinCompany(user.user.id, 'INVALID88');
    }, /invalid invite code/i);
  });
});
```

**Step 2: Run test to verify it fails**
Run: `node --test tests/company.test.js` di direktori `backend`
Expected: FAIL dengan "Cannot find module '../src/services/company.service.js'".

**Step 3: Write minimal implementation**
Buat `backend/src/services/company.service.js`:
- `createCompany(userId, name)`: generate 8-karakter hex uppercase unik, insert ke `companies`, update `users.company_id`.
- `joinCompany(userId, inviteCode)`: validasi kode undangan, update `users.company_id`.
- `getCompanyMembers(companyId)`: fetch anggota user di `company_id`.
- `getCompanyById(companyId)`: fetch detail data perusahaan.

**Step 4: Run test to verify it passes**
Run: `node --test tests/company.test.js` di direktori `backend`
Expected: PASS (semua 3 test suite CompanyService lolos).

**Step 5: Commit**
```bash
git add backend/src/services/company.service.js backend/tests/company.test.js
git commit -m "feat(backend): implement CompanyService with TDD unit tests"
```

---

### Task 3: Backend ProjectService & TDD Unit Tests

**Files:**
- Create: `backend/src/services/project.service.js`
- Create: `backend/tests/project.test.js`

**Step 1: Write the failing test**
Buat test suite `backend/tests/project.test.js`:
```javascript
import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert';
import { db } from '../src/config/database.js';
import { AuthService } from '../src/services/auth.service.js';
import { CompanyService } from '../src/services/company.service.js';
import { ProjectService } from '../src/services/project.service.js';
import { WalletService } from '../src/services/wallet.service.js';

describe('ProjectService (TDD)', () => {
  beforeEach(() => {
    db.mock.reset();
  });

  it('should create a project under company with budget', async () => {
    const ceo = await AuthService.register('CEO', 'ceo@biz.com', 'secret123');
    const comp = await CompanyService.createCompany(ceo.user.id, 'Agensi Digital');

    const project = await ProjectService.createProject(comp.id, ceo.user.id, {
      name: 'Pembuatan Website Klien A',
      description: 'Proyek pengembangan web portal e-commerce',
      target_budget: 25000000
    });

    assert.ok(project.id);
    assert.strictEqual(project.company_id, comp.id);
    assert.strictEqual(project.target_budget, 25000000);
    assert.strictEqual(project.current_income, 0);
    assert.strictEqual(project.current_expense, 0);
  });

  it('should record project income and expense, updating project balances atomically', async () => {
    const ceo = await AuthService.register('CEO', 'ceo2@biz.com', 'secret123');
    const comp = await CompanyService.createCompany(ceo.user.id, 'Tech Studio');
    const wallet = await WalletService.createWallet(ceo.user.id, 'Rekening Operasional', 10000000);

    const proj = await ProjectService.createProject(comp.id, ceo.user.id, {
      name: 'Mobile App Project',
      target_budget: 50000000
    });

    // 1. Catat Pemasukan Klien (Termin 1: Rp 30.000.000)
    await ProjectService.recordTransaction(ceo.user.id, comp.id, proj.id, {
      wallet_id: wallet.id,
      type: 'income',
      amount: 30000000,
      notes: 'Pembayaran DP Termin 1'
    });

    // 2. Catat Pengeluaran Proyek (Sewa Server & Desain: Rp 5.000.000)
    await ProjectService.recordTransaction(ceo.user.id, comp.id, proj.id, {
      wallet_id: wallet.id,
      type: 'expense',
      amount: 5000000,
      notes: 'Pembelian domain dan server cloud'
    });

    const updatedProj = await ProjectService.getProjectById(comp.id, proj.id);
    assert.strictEqual(updatedProj.current_income, 30000000);
    assert.strictEqual(updatedProj.current_expense, 5000000);
    assert.strictEqual(updatedProj.net_profit, 25000000);

    // Dompet rekening juga bertambah bersih +25.000.000 (10jt + 30jt - 5jt = 35jt)
    const updatedWallet = await WalletService.getWalletById(wallet.id);
    assert.strictEqual(updatedWallet.balance, 35000000);
  });
});
```

**Step 2: Run test to verify it fails**
Run: `node --test tests/project.test.js` di direktori `backend`
Expected: FAIL dengan error "Cannot find module '../src/services/project.service.js'".

**Step 3: Write minimal implementation**
Implementasikan `backend/src/services/project.service.js`:
- `createProject(companyId, userId, data)`: insert project baru dengan budget & deskripsi.
- `getProjects(companyId, status)`: list project dengan kalkulasi laba bersih (`current_income - current_expense`) dan persentase utilisasi budget.
- `getProjectById(companyId, projectId)`: detail project beserta list mutasi transaksinya.
- `recordTransaction(userId, companyId, projectId, data)`: eksekusi atomik transaksi (update saldo wallet, update income/expense project, simpan catatan transaksi scope `company`).
- `updateProjectStatus(companyId, projectId, status)`: ubah status (`active`, `completed`, `on_hold`).

**Step 4: Run test to verify it passes**
Run: `node --test tests/project.test.js` di direktori `backend`
Expected: PASS.

**Step 5: Commit**
```bash
git add backend/src/services/project.service.js backend/tests/project.test.js
git commit -m "feat(backend): implement ProjectService with cashflow tracking and TDD tests"
```

---

### Task 4: REST API Integration & End-to-End API Tests

**Files:**
- Modify: `backend/src/app.js`
- Modify: `backend/tests/api.test.js`

**Step 1: Write the failing API test**
Di `backend/tests/api.test.js`:
Tambahkan skenario pengujian endpoint API Perusahaan & Proyek:
```javascript
it('should create company, create project, and record project cashflow via API', async () => {
  const client = request(app);
  // 1. Auth
  const auth = await client.send('POST', '/api/v1/auth/register', {
    body: { name: 'Manager', email: 'manager@corp.com', password: 'password123' }
  });
  const token = auth.body.token;

  // 2. Create Company
  const compRes = await client.send('POST', '/api/v1/company/create', {
    headers: { 'authorization': `Bearer ${token}` },
    body: { name: 'Firma Konsultan' }
  });
  assert.strictEqual(compRes.status, 201);
  assert.strictEqual(compRes.body.name, 'Firma Konsultan');

  // 3. Create Project
  const projRes = await client.send('POST', '/api/v1/projects', {
    headers: { 'authorization': `Bearer ${token}` },
    body: { name: 'Audit Klien X', target_budget: 15000000 }
  });
  assert.strictEqual(projRes.status, 201);
  assert.strictEqual(projRes.body.name, 'Audit Klien X');

  // 4. Get Projects
  const listRes = await client.send('GET', '/api/v1/projects', {
    headers: { 'authorization': `Bearer ${token}` }
  });
  assert.strictEqual(listRes.status, 200);
  assert.strictEqual(listRes.body.length, 1);
});
```

**Step 2: Run test to verify it fails**
Run: `node --test tests/api.test.js`
Expected: FAIL dengan 404 pada route `/api/v1/company/create`.

**Step 3: Write minimal implementation**
Tambahkan route endpoint di `backend/src/app.js`:
- `/api/v1/company/create` [POST]
- `/api/v1/company/join` [POST]
- `/api/v1/company/current` [GET]
- `/api/v1/company/members` [GET]
- `/api/v1/projects` [GET, POST]
- `/api/v1/projects/:id` [GET, PATCH]
- `/api/v1/projects/:id/transaction` [POST]

**Step 4: Run test to verify it passes**
Run: `npm test` di direktori `backend`
Expected: PASS (seluruh test backend 100% lolos).

**Step 5: Commit**
```bash
git add backend/src/app.js backend/tests/api.test.js
git commit -m "feat(api): expose company and project management REST endpoints"
```

---

### Task 5: Frontend Models & Provider Workspace State

**Files:**
- Create: `frontend/lib/models/company_model.dart`
- Create: `frontend/lib/models/project_model.dart`
- Modify: `frontend/lib/models/user_model.dart`
- Modify: `frontend/lib/models/transaction_model.dart`
- Modify: `frontend/lib/providers/auth_provider.dart`
- Modify: `frontend/lib/providers/finance_provider.dart`

**Step 1: Write Dart Models & Serialization**
- `CompanyModel`: `id`, `name`, `inviteCode`, `createdBy`, `createdAt`.
- `ProjectModel`: `id`, `companyId`, `name`, `description`, `targetBudget`, `currentIncome`, `currentExpense`, `netProfit`, `status`, `startDate`, `endDate`.
- Update `UserModel`: tambahkan `int? companyId`.
- Update `TransactionModel`: tambahkan `int? companyId`, `int? projectId`, `String? projectName`.

**Step 2: Update AuthProvider & FinanceProvider**
- Di `AuthProvider`:
  - Tambahkan state `CompanyModel? currentCompany`, `List<Map<String, dynamic>> companyMembers`.
  - Tambahkan fungsi API `createCompany(name)`, `joinCompany(inviteCode)`, `getCurrentCompany()`.
- Di `FinanceProvider`:
  - Tambahkan mode tampilan 3-way: `AppViewMode currentMode` (`AppViewMode.personal`, `AppViewMode.family`, `AppViewMode.company`).
  - Tambahkan getter `bool get isCompanyView => currentMode == AppViewMode.company`.
  - Tambahkan state `List<ProjectModel> projects = []`.
  - Tambahkan fungsi `fetchProjects()`, `createProject()`, `recordProjectTransaction()`, `fetchProjectDetails()`.

**Step 3: Verify with Dart Static Analysis**
Run: MCP `analyze_files` pada file model & provider.
Expected: `No errors`.

**Step 4: Commit**
```bash
git add frontend/lib/models/* frontend/lib/providers/*
git commit -m "feat(frontend): add company and project models with multi-workspace state"
```

---

### Task 6: Apple iOS 18 Three-Way Segmented Switcher (`WorkspaceSwitcher`)

**Files:**
- Modify: `frontend/lib/widgets/family_switcher.dart` (atau refactor menjadi multi-segmented control)
- Modify: `frontend/lib/screens/dashboard/dashboard_screen.dart`

**Step 1: Upgrade Switcher Component**
- Ubah selector pill agar mendukung 3 tab horizontal yang halus dan proporsional:
  - `[ 👤 Pribadi ]` (Theme Blue)
  - `[ 👥 Keluarga ]` (Theme Royal Purple)
  - `[ 🏢 Perusahaan ]` (Theme Corporate Sapphire / Navy)
- Gunakan `FittedBox(fit: BoxFit.scaleDown)` dan `mainAxisSize: MainAxisSize.min` sehingga tidak pernah mengalami overflow di layar mana pun.
- Dilengkapi haptic feedback (`HapticFeedback.lightImpact()`).

**Step 2: Verify with Dart Static Analysis**
Run: MCP `analyze_files`.
Expected: `No errors`.

**Step 3: Commit**
```bash
git add frontend/lib/widgets/family_switcher.dart frontend/lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat(ui): implement Apple iOS 18 three-way workspace switcher"
```

---

### Task 7: Frontend Company Onboarding View (Buat / Gabung Perusahaan)

**Files:**
- Modify: `frontend/lib/screens/dashboard/dashboard_screen.dart`
- Create / Inline: `_buildCompanyOnboardingView(FinanceProvider finance, AuthProvider auth)`

**Step 1: Implementasi Desain Onboarding Perusahaan**
- Ditampilkan saat pengguna memilih tab **Perusahaan** namun belum memiliki perusahaan (`auth.currentUser?.companyId == null`).
- Tampilan elegan Apple iOS 18:
  1. Sapphire Navy Shield Hero Icon (`Icons.domain_rounded`).
  2. Judul *"Ruang Finansial Perusahaan"*.
  3. Feature Highlights:
     - 💼 *Manajemen Proyek*: Buat proyek bisnis dan pantau target anggarannya.
     - 📈 *Input Kas per Proyek*: Setiap anggota tim bisa mencatat pemasukan & pengeluaran proyek.
     - 🔐 *Akses Tim Unik*: ID Perusahaan 8 karakter untuk sinkronisasi seluruh tim kerja.
  4. Tab Segmented *"Buat Perusahaan Baru"* vs *"Masuk Perusahaan"*:
     - Buat: Input Nama Perusahaan -> Generate ID otomatis.
     - Masuk: Input 8 karakter Kode Undangan -> Gabung instan.

**Step 2: Verify with Dart Static Analysis**
Run: MCP `analyze_files`.
Expected: `No errors`.

**Step 3: Commit**
```bash
git add frontend/lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat(ui): add elegant company onboarding view with create and join flows"
```

---

### Task 8: Frontend Company Dashboard View & Projects Management

**Files:**
- Modify: `frontend/lib/screens/dashboard/dashboard_screen.dart`
- Create / Inline Helper Components:
  - `_buildCompanyDashboardView(FinanceProvider finance, AuthProvider auth)`
  - `_showCreateProjectModal(BuildContext context)`
  - `_showRecordProjectTransactionModal(BuildContext context, [ProjectModel? preselected])`
  - `_showProjectDetailModal(BuildContext context, ProjectModel project)`
  - `_showCompanyInfoModal(BuildContext context)`

**Step 1: Implementasi Sapphire Corporate Hero Card**
- Menampilkan nama perusahaan, badge ID Perusahaan (1-tap salin), total proyek aktif, dan total anggota.
- 3 Tombol Quick Action:
  - `[+ Proyek Baru]` (Membuka modal pembuatan proyek)
  - `[Catat Kas]` (Membuka form input pemasukan/pengeluaran proyek)
  - `[Undang Tim]` (Menampilkan kode undangan perusahaan)

**Step 2: Ringkasan Metrik Finansial Proyek (Financial Health Overview)**
- Menampilkan 3 kartu ringkasan eksekutif:
  1. *Total Anggaran Proyek*: Akumulasi target budget seluruh proyek aktif.
  2. *Total Pemasukan (Revenue)*: Akumulasi pemasukan yang dicatat tim pada proyek.
  3. *Total Pengeluaran (Cost)*: Biaya operasional proyek.
  4. *Laba Bersih (Net Profit)*: Laba akumulasi proyek dengan warna hijau (profit) atau merah (defisit).

**Step 3: Daftar Kartu Proyek Interaktif (Project Cards)**
- Setiap kartu proyek memuat:
  - Nama Proyek & Deskripsi singkat.
  - Status Badge (`Aktif`, `Selesai`, `Ditunda`).
  - Progress Bar Budget Utilization (`(Pengeluaran / Budget) * 100%`).
  - Baris Finansial: Pemasukan vs Pengeluaran vs Laba Bersih Proyek.
  - Tombol Aksi Cepat: `[+ Catat Kas]` dan `[Detail Proyek]`.

**Step 4: Modal Detail Proyek & Riwayat Kas**
- Menampilkan daftar mutasi transaksi proyek:
  - Siapa anggota tim yang mencatat (`tx.userName`).
  - Tanggal transaksi, nominal (`+ Rp` atau `- Rp`), dan catatan pengeluaran/pemasukan.

**Step 5: Verify with Dart Static Analysis**
Run: MCP `analyze_files`.
Expected: `No errors`.

**Step 6: Commit**
```bash
git add frontend/lib/screens/dashboard/dashboard_screen.dart
git commit -m "feat(ui): add complete company dashboard with interactive project cards and cashflow tracking"
```

---

### Task 9: Full Regression Verification & GitHub Sync

**Files:**
- Test backend: `npm test`
- Static Analysis: `analyze_files`
- Git sync: Push to `origin/master` and `origin/main`

**Step 1: Run complete backend test suite**
Run: `npm test` di direktori `backend`
Expected: Semua unit tests & integration tests lulus (100% pass).

**Step 2: Run Dart Analyzer across entire codebase**
Run: MCP `analyze_files` pada semua file Flutter yang diubah.
Expected: `No errors`.

**Step 3: Push changes to GitHub**
Run: `git push origin master` & `git push origin main`.
Expected: Sukses ter-push ke repository GitHub.

---

## Execution Choice
Plan telah selesai dirancang secara lengkap dan tersimpan di `docs/plans/2026-11-21-company-projects-feature.md`.
Bagaimana Anda ingin mengeksekusi implementasi ini?
1. **Langsung dieksekusi sekarang di sesi ini secara bertahap (TDD & Validasi tiap task)**.
2. **Review dan diskusikan penyesuaian detail tertentu terlebih dahulu**.
