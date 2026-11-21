# Offline-First Sync & Auth Enhancements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Membangun alur autentikasi dan keamanan yang lebih andal (Konfirmasi Logout dengan dialog interaktif, Konfirmasi Kata Sandi ganda pada Registrasi) serta sistem **Offline-First Synchronization** (cache lokal saat login, input data transaksi/hutang/tabungan tanpa sinyal secara offline dengan pembaruan instan, dan sinkronisasi otomatis saat online kembali dengan jaminan zero-duplicate via Idempotency Key).

**Architecture:** 
1. **Frontend Auth UX**: Dialog konfirmasi iOS HIG / Material 3 pada alur logout untuk mencegah ketidaksengajaan keluar akun, serta penambahan kolom dan validasi `confirmPassword` pada `RegisterScreen`.
2. **Offline-First Local Cache**: Layanan `OfflineSyncService` pada Flutter yang secara otomatis mencadangkan data dashboard (dompet, ringkasan, transaksi, tabungan, hutang) ke penyimpanan lokal setiap kali login/fetch berhasil, dan segera menyajikan data dari cache saat koneksi terputus (`ERR_CONNECTION_REFUSED` / no signal).
3. **Optimistic UI & Sync Queue**: Saat input data dalam mode offline, aksi dicatat ke antrean lokal (`OfflineSyncQueue`) dengan `idempotency_key` (UUID unik) dan UI langsung terupdate secara optimistik (saldo disesuaikan, item ditandai sebagai *Pending Sync*).
4. **Backend Idempotency Engine**: Penambahan kolom `idempotency_key` (UNIQUE) pada tabel `transactions`, `debts`, dan `savings` pada database MySQL + Express.js. Jika antrean offline mengirimkan ulang data yang sama, backend mendeteksi kunci idempotensi dan mengembalikan data yang sudah ada tanpa melakukan mutasi ganda (*zero double-input guarantee*).

**Tech Stack:**
- **Backend:** Node.js, Express.js, MySQL / MariaDB (Connection Pool, Transactions, Unique Constraints), `node:test` (TDD)
- **Frontend:** Flutter (Dart 3+), Provider (State Management), `OfflineSyncService` (Local Cache & Queue), Material 3 with Apple iOS Human Interface Guidelines

---

### Task 1: Dialog Konfirmasi Keluar (Logout Confirmation Modal)

**Files:**
- Modify: `frontend/lib/screens/dashboard/dashboard_screen.dart`
- Create: `frontend/test/logout_dialog_test.dart`

**Step 1: Write the failing test**
Buat pengujian `frontend/test/logout_dialog_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finance_app/screens/dashboard/dashboard_screen.dart';
import 'package:finance_app/providers/auth_provider.dart';
import 'package:finance_app/providers/finance_provider.dart';
import 'package:finance_app/core/network/api_client.dart';

void main() {
  testWidgets('Menampilkan dialog konfirmasi saat tombol keluar ditekan', (tester) async {
    // Setup test harness with dummy provider
    // Verify AlertDialog appears with title 'Konfirmasi Keluar' and buttons 'Tidak' and 'Ya, Keluar'
  });
}
```

**Step 2: Run test to verify it fails**
Run: `flutter test test/logout_dialog_test.dart`
Expected: FAIL (dialog belum diimplementasikan pada tombol logout).

**Step 3: Write minimal implementation**
Di `frontend/lib/screens/dashboard/dashboard_screen.dart`:
1. Buat method `Future<void> _showLogoutDialog(BuildContext context, AuthProvider auth)`:
```dart
Future<void> _showLogoutDialog(BuildContext context, AuthProvider auth) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Row(
        children: [
          Icon(Icons.logout_rounded, color: AppTheme.expenseRed, size: 22),
          SizedBox(width: 8),
          Text(
            'Konfirmasi Keluar',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
        ],
      ),
      content: const Text(
        'Apakah Anda yakin ingin keluar dari akun Uangku Anda?',
        style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'Tidak',
            style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.expenseRed,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'Ya, Keluar',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
        ),
      ],
    ),
  );

  if (shouldLogout == true && context.mounted) {
    auth.logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
```
2. Hubungkan tombol logout pada AppBar ke `_showLogoutDialog(context, auth);`.

**Step 4: Run test to verify it passes**
Run: `flutter test test/logout_dialog_test.dart`
Expected: PASS.

**Step 5: Commit**
```bash
git add frontend/lib/screens/dashboard/dashboard_screen.dart frontend/test/logout_dialog_test.dart
git commit -m "feat(ui): add logout confirmation dialog with Ya and Tidak options"
```

---

### Task 2: Konfirmasi Kata Sandi pada Registrasi (Double Password Validation)

**Files:**
- Modify: `frontend/lib/screens/auth/register_screen.dart`
- Create: `frontend/test/register_validation_test.dart`

**Step 1: Write the failing test**
Buat pengujian `frontend/test/register_validation_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/screens/auth/register_screen.dart';

void main() {
  testWidgets('Menolak pendaftaran jika konfirmasi password tidak cocok', (tester) async {
    // Input nama, email, password '123456', confirmPassword '654321'
    // Submit -> SnackBar muncul 'Konfirmasi kata sandi tidak cocok'
  });
}
```

**Step 2: Run test to verify it fails**
Run: `flutter test test/register_validation_test.dart`
Expected: FAIL (input konfirmasi password belum ada).

**Step 3: Write minimal implementation**
Di `frontend/lib/screens/auth/register_screen.dart`:
1. Tambahkan state controller dan visibility flag:
```dart
final _confirmPasswordController = TextEditingController();
bool _obscureConfirmPassword = true;
```
2. Tambahkan pembersihan di `dispose()`:
```dart
_confirmPasswordController.dispose();
```
3. Tambahkan validasi pada `_submitRegister()`:
```dart
final confirmPassword = _confirmPasswordController.text;

if (password != confirmPassword) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Konfirmasi kata sandi tidak cocok. Harap periksa kembali.'),
      backgroundColor: AppTheme.expenseRed,
      behavior: SnackBarBehavior.floating,
    ),
  );
  return;
}
```
4. Tambahkan field ke-4 pada Inset Grouped input card dengan Divider pemisah, placeholder `"Ulangi Kata Sandi"`, ikon `lock_reset_rounded`, dan toggle mata `_obscureConfirmPassword`.
5. Sesuaikan keyboard action: password field `TextInputAction.next`, confirm password `TextInputAction.done` dengan `onSubmitted: (_) => _submitRegister()`.

**Step 4: Run test to verify it passes**
Run: `flutter test test/register_validation_test.dart`
Expected: PASS.

**Step 5: Commit**
```bash
git add frontend/lib/screens/auth/register_screen.dart frontend/test/register_validation_test.dart
git commit -m "feat(auth): add password confirmation input with matching validation on register"
```

---

### Task 3: Backend Anti-Double-Input Engine (Idempotency Key & Schema)

**Files:**
- Modify: `backend/database/schema.sql`
- Modify: `backend/database/migrate.js`
- Modify: `backend/src/config/database.js` (MockDatabase support)
- Modify: `backend/src/services/transaction.service.js`
- Modify: `backend/src/services/debt.service.js`
- Modify: `backend/src/services/saving.service.js`
- Create: `backend/tests/idempotency.test.js`

**Step 1: Write the failing test**
Buat pengujian idempotensi di `backend/tests/idempotency.test.js`:
```javascript
import { describe, it, before } from 'node:test';
import assert from 'node:assert';
import { TransactionService } from '../src/services/transaction.service.js';
import { WalletService } from '../src/services/wallet.service.js';
import { db } from '../src/config/database.js';

describe('Anti-Double-Input Idempotency Engine', () => {
  it('should ignore duplicate requests with identical idempotency_key and not alter balance twice', async () => {
    // 1. Create wallet with balance 100,000
    // 2. Submit transaction with idempotency_key 'idemp_test_123' (amount 30,000)
    // 3. Resubmit same transaction with identical idempotency_key 'idemp_test_123'
    // 4. Assert: Only 1 transaction row exists, wallet balance is exactly 70,000 (not 40,000)
  });
});
```

**Step 2: Run test to verify it fails**
Run: `npm test` di direktori `backend`
Expected: FAIL (`TransactionService` belum mendukung `idempotency_key`).

**Step 3: Write minimal implementation**
1. Di `backend/database/schema.sql` dan `backend/database/migrate.js`:
   - Tambahkan kolom `idempotency_key VARCHAR(64) NULL UNIQUE` pada tabel `transactions`, `debts`, dan `savings`.
2. Di `backend/src/services/transaction.service.js`:
   - Pada method `createTransaction(userId, walletId, type, amount, categoryId, notes, date, scope, companyId, projectId, idempotencyKey)`:
   - Sebelum mutasi saldo, periksa apakah `idempotencyKey` sudah tercatat:
     ```javascript
     if (idempotencyKey) {
       const existing = await db.query(
         'SELECT * FROM transactions WHERE idempotency_key = ? LIMIT 1',
         [idempotencyKey]
       );
       if (existing && existing.length > 0) {
         return { ...existing[0], is_duplicate: true };
       }
     }
     ```
   - Sertakan `idempotencyKey` dalam query `INSERT INTO transactions (...)`.
3. Terapkan pola idempotensi serupa pada `DebtService.createDebt` dan `SavingService.deposit`.
4. Di `backend/src/config/database.js`: Perbarui `MockDatabase` agar menghandle kolom `idempotency_key` dan mencegah duplikasi insert saat mock aktif.

**Step 4: Run test to verify it passes**
Run: `npm test` di direktori `backend`
Expected: PASS (seluruh test backend termasuk `idempotency.test.js` sukses).

**Step 5: Commit**
```bash
git add backend/database/schema.sql backend/database/migrate.js backend/src/config/database.js backend/src/services/ backend/tests/idempotency.test.js
git commit -m "feat(backend): add idempotency key support to prevent double input on offline sync"
```

---

### Task 4: Frontend Offline Storage & Sync Queue Service

**Files:**
- Create: `frontend/lib/services/offline_sync_service.dart`
- Create: `frontend/lib/models/offline_sync_item.dart`
- Create: `frontend/test/offline_sync_service_test.dart`

**Step 1: Write the failing test**
Buat pengujian antrean dan cache lokal di `frontend/test/offline_sync_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/services/offline_sync_service.dart';
import 'package:finance_app/models/offline_sync_item.dart';

void main() {
  test('Menyimpan data dashboard offline dan mengelola antrean sync idempotensi', () async {
    final service = OfflineSyncService();
    await service.cacheDashboardSnapshot({'total_balance': 500000});
    final cached = await service.getCachedDashboardSnapshot();
    expect(cached?['total_balance'], 500000);

    final item = OfflineSyncItem(
      id: 'item_1',
      endpoint: '/transactions',
      method: 'POST',
      body: {'amount': 50000},
      idempotencyKey: 'idemp_abc_123',
    );
    await service.enqueueAction(item);
    final pending = await service.getPendingActions();
    expect(pending.length, 1);
    expect(pending.first.idempotencyKey, 'idemp_abc_123');
  });
}
```

**Step 2: Run test to verify it fails**
Run: `flutter test test/offline_sync_service_test.dart`
Expected: FAIL (`OfflineSyncService` belum dibuat).

**Step 3: Write minimal implementation**
1. Buat model `OfflineSyncItem` di `frontend/lib/models/offline_sync_item.dart`:
   - `id`, `endpoint`, `method`, `body`, `idempotencyKey`, `createdAt`, `status`.
2. Buat `OfflineSyncService` di `frontend/lib/services/offline_sync_service.dart`:
   - Cache dashboard lokal (menyimpan data dompet, transaksi, tabungan, hutang per user).
   - Antrean offline (`enqueueAction`, `getPendingActions`, `removeAction`, `clearQueue`).
   - Helper generator UUID Idempotency Key (`idemp_${timestamp}_${random}`).

**Step 4: Run test to verify it passes**
Run: `flutter test test/offline_sync_service_test.dart`
Expected: PASS.

**Step 5: Commit**
```bash
git add frontend/lib/services/offline_sync_service.dart frontend/lib/models/offline_sync_item.dart frontend/test/offline_sync_service_test.dart
git commit -m "feat(offline): implement local dashboard caching and offline sync queue service"
```

---

### Task 5: Integrasi Offline-First pada FinanceProvider & Optimistic UI

**Files:**
- Modify: `frontend/lib/providers/finance_provider.dart`
- Modify: `frontend/lib/screens/dashboard/dashboard_screen.dart`
- Create: `frontend/test/offline_provider_test.dart`

**Step 1: Write the failing test**
Buat pengujian `frontend/test/offline_provider_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
// Uji bahwa jika network error, FinanceProvider memuat data dari cache lokal dan menyetel flag isOfflineMode = true
```

**Step 2: Run test to verify it fails**
Run: `flutter test test/offline_provider_test.dart`
Expected: FAIL.

**Step 3: Write minimal implementation**
1. Di `frontend/lib/providers/finance_provider.dart`:
   - Tambahkan property `bool _isOffline = false; bool get isOffline => _isOffline;`
   - Tambahkan property `int _pendingSyncCount = 0; int get pendingSyncCount => _pendingSyncCount;`
   - Pada `fetchDashboard()`:
     - Jika request API sukses: panggil `_offlineService.cacheDashboardSnapshot(...)` untuk menyerap data lokal, dan set `_isOffline = false;`.
     - Jika request gagal karena koneksi (`ERR_CONNECTION_REFUSED`, `SocketException`, offline): panggil `_offlineService.getCachedDashboardSnapshot()`, isi ulang state `_wallets`, `_transactions`, `_savings`, `_debts` dari data cache, dan set `_isOffline = true;`.
   - Pada operasi input (`recordTransaction`, `createDebt`, `depositSaving`):
     - Jika online: kirim via API biasa.
     - Jika gagal / offline:
       1. Buat `idempotencyKey = generateIdempotencyKey()`.
       2. Terapkan **Optimistic Update** pada memori lokal (potong/tambah saldo dompet seketika, masukkan transaksi ke daftar riwayat dengan label `(Pending Sync)`).
       3. Simpan ke antrean `_offlineService.enqueueAction(...)`.
       4. Update `_pendingSyncCount`.
   - Buat method `Future<void> syncPendingQueue()`:
     - Mengeksekusi antrean pending secara berurutan dengan menyertakan `idempotency_key` pada header/body.
     - Menghapus item dari antrean jika sukses atau jika backend mengonfirmasi `is_duplicate: true`.
     - Memperbarui data akhir dari server setelah seluruh antrean selesai dikirim.
2. Di `frontend/lib/screens/dashboard/dashboard_screen.dart`:
   - Tambahkan indikator status jaringan halus di bawah AppBar:
     ```dart
     if (finance.isOffline)
       Container(
         color: const Color(0xFFFFFBEB),
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
         child: Row(
           children: [
             const Icon(Icons.cloud_off_rounded, size: 14, color: Color(0xFFD97706)),
             const SizedBox(width: 8),
             Text(
               'Mode Offline • ${finance.pendingSyncCount} transaksi tersimpan lokal',
               style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
             ),
             const Spacer(),
             InkWell(
               onTap: () => finance.syncPendingQueue(),
               child: const Text('Sinkronkan', style: TextStyle(fontSize: 11, color: AppTheme.iosBlue, fontWeight: FontWeight.w700)),
             ),
           ],
         ),
       )
     ```

**Step 4: Run test to verify it passes**
Run: `flutter test test/offline_provider_test.dart`
Expected: PASS.

**Step 5: Commit**
```bash
git add frontend/lib/providers/finance_provider.dart frontend/lib/screens/dashboard/dashboard_screen.dart frontend/test/offline_provider_test.dart
git commit -m "feat(sync): integrate offline-first dashboard cache, optimistic input, and background sync"
```

---

### Task 6: Verifikasi Menyeluruh & Testing Lint End-to-End

**Files:**
- Run: `backend/tests/*.test.js`
- Run: `flutter analyze` & `flutter test`

**Step 1: Jalankan Backend Test Suite**
```bash
npm --prefix backend test
```
Expected: 100% tests pass (termasuk verifikasi idempotensi dan anti-duplikasi).

**Step 2: Jalankan Flutter Analyzer & Unit Tests**
```bash
flutter analyze
flutter test
```
Expected: 0 errors, 100% test pass.

**Step 3: Uji Skenario Offline Nyata**
1. Login akun -> data terserap ke cache lokal.
2. Matikan server backend (simulasi mati sinyal).
3. Input transaksi baru -> saldo langsung berubah di UI, tersimpan sementara di local queue dengan badge *Pending Sync*.
4. Nyalakan kembali server backend.
5. Klik *Sinkronkan* atau biarkan auto-sync berjalan -> data terkirim ke MySQL dengan `idempotency_key`, dan dipastikan **tidak terjadi double input**.

**Step 4: Commit & Push Final**
```bash
git add .
git commit -m "feat: complete offline-first sync engine, register password confirmation, and logout verification dialog"
git push origin master
git push origin main
```
