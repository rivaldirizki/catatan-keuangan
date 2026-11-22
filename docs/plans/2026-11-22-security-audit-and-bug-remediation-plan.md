# 🛡️ Laporan Audit Keamanan Sistem & Rencana Implementasi Perbaikan
**Aplikasi:** Dompet Linc (*Financial Tracker Platform*)  
**Tanggal:** 22 November 2026  
**Standar Evaluasi:** OWASP API Security Top 10 (2023), Bugcrowd VRT (*Vulnerability Rating Taxonomy*), CWE (*Common Weakness Enumeration*)

---

## 1. Ringkasan Eksekutif (Executive Summary)

Audit komprehensif telah dilakukan pada seluruh basis kode backend (`Node.js/Express/MySQL`) dan frontend aplikasi mobile (`Flutter/Dart`). Audit ini mengevaluasi aspek otentikasi, otorisasi objek (BOLA/IDOR), konkurensi finansial, integritas skema database, serta persistensi sesi mobile.

Hasil audit mengidentifikasi **11 temuan penting**:
- **3 Celah Kritis (P1 - Critical):** *Mass assignment* hak akses administrator saat pendaftaran publik, ketiadaan verifikasi kepemilikan objek (BOLA) pada penarikan tabungan dan pelunasan hutang, serta kebocoran data transaksi pribadi anggota keluarga.
- **2 Celah Tinggi (P2 - High):** Pemindahan dana antar-akun tanpa otorisasi dompet asal (*IDOR Transfer*), dan potensi *race condition* (TOCTOU) pada kalkulasi saldo dompet konkuren.
- **3 Celah Sedang (P3 - Medium):** *Timing attack* dan *fallback secret* pada verifikasi JWT, ketiadaan *rate limiting* pada endpoint autentikasi, serta iterasi hashing kata sandi yang terlalu rendah.
- **3 Isu Fungsional & Klien (P4/P5 - Low):** Sesi pengguna mobile yang tidak tersimpan permanen (*auto logout on restart*), ketiadaan batas waktu request HTTP seluler (*hanging spinner*), dan celah validasi tipe numerik `NaN`.

---

## 2. Matriks Temuan & Klasifikasi Risiko

| ID | Judul Temuan & Deskripsi | Klasifikasi VRT / CWE | Severity | Komponen Terdampak |
| :--- | :--- | :--- | :---: | :--- |
| **SEC-01** | Mass Assignment `role: admin` pada Registrasi Publik | CWE-915 / Server-Side Injection → Privilege Escalation | **P1 (Critical)** | `backend/src/app.js:65-75`<br>`backend/src/services/auth.service.js:45-73` |
| **SEC-02** | BOLA / IDOR pada Penarikan Tabungan & Bayar Hutang | CWE-639 / OWASP API1:2023 Broken Object Level Auth | **P1 (Critical)** | `backend/src/services/saving.service.js:153-177`<br>`backend/src/services/debt.service.js:212-245` |
| **SEC-03** | Kebocoran Transaksi Finansial Pribadi Anggota Keluarga | CWE-200 / Sensitive Data Exposure | **P1 (Critical)** | `backend/src/services/transaction.service.js:198-220`<br>`backend/src/app.js:151-163` |
| **SEC-04** | IDOR Pemindahan Dana (*Transfer*) Tanpa Validasi Pemilik Dompet Asal | CWE-284 / Broken Object Property Level Auth | **P2 (High)** | `backend/src/services/transaction.service.js:107-158` |
| **SEC-05** | Race Condition (TOCTOU) Perhitungan Saldo Dompet | CWE-367 / Time-of-Check to Time-of-Use | **P2 (High)** | `backend/src/services/transaction.service.js:33-53`<br>`backend/src/services/saving.service.js:128-150` |
| **SEC-06** | Timing Attack & Hardcoded Secret Fallback pada JWT | CWE-208 / Cryptographic Failures | **P3 (Medium)** | `backend/src/services/auth.service.js:4-42` |
| **SEC-07** | Ketiadaan Proteksi Brute-Force / Rate Limiting pada Auth & Invite | CWE-307 / Server Security Misconfiguration | **P3 (Medium)** | `backend/src/app.js:65-90, 113-122, 177-186` |
| **SEC-08** | Iterasi PBKDF2 Rendah (1.000 vs Standar OWASP 210.000) | CWE-916 / Insufficient Work Factor | **P3 (Medium)** | `backend/src/services/auth.service.js:9`<br>`backend/database/migrate.js:14` |
| **BUG-01** | Token & Sesi Mobile Tidak Disimpan Permanen (*Always Logout on Relaunch*) | Client State Management / Session Flaw | **P4 (Medium Funct.)** | `frontend/lib/providers/auth_provider.dart:43-48`<br>`frontend/lib/screens/splash/splash_screen.dart:25-29` |
| **BUG-02** | Ketiadaan Timeout pada HTTP Requests Mobile (*Infinite Hanging*) | Network Resilience / Fault Handling | **P4 (Low Funct.)** | `frontend/lib/core/network/api_client.dart:23-51` |
| **BUG-03** | Bypass Pengecekan Angka Nominal dengan `NaN` pada Transaksi | Type Confusion / Input Validation | **P4 (Low)** | `backend/src/services/transaction.service.js:6-7` |

---

## 3. Rencana Implementasi Perbaikan (Implementation Plan)

Rencana aksi berikut dirancang mengikuti metodologi **Test-Driven Development (TDD)** dengan eksekusi bertahap dari prioritas tertinggi ke pengerasan sistem.

### Task 1: Kunci Role Registrasi ke 'user' (SEC-01)
* **Tujuan:** Mencegah pengguna mendaftarkan diri secara ilegal sebagai administrator sistem.
* **Berkas yang dimodifikasi:**
  - `backend/src/app.js` (line 65-75)
  - `backend/tests/auth.test.js` (tambahkan unit test penolakan role injection)
* **Langkah Kerja:**
  1. Buat test di `backend/tests/auth.test.js` yang memverifikasi bahwa registrasi dengan payload `role: 'admin'` tetap menghasilkan akun ber-role `'user'`.
  2. Ubah `backend/src/app.js` agar hanya mengambil `name`, `email`, dan `password` dari `req.body`, serta memanggil `AuthService.register(name, email, password, 'user')`.
  3. Jalankan `node --test backend/tests/auth.test.js`.

### Task 2: Validasi Otorisasi Objek (BOLA/IDOR) pada Tabungan, Hutang, & Transfer (SEC-02, SEC-04)
* **Tujuan:** Memastikan pengguna hanya dapat memanipulasi dompet, tabungan, dan hutang miliknya sendiri.
* **Berkas yang dimodifikasi:**
  - `backend/src/services/saving.service.js` (`withdraw`, `deposit`)
  - `backend/src/services/debt.service.js` (`recordPayment`)
  - `backend/src/services/transaction.service.js` (`transfer`, `recordIncome`, `recordExpense`)
  - `backend/tests/saving.test.js`, `backend/tests/debt.test.js`, `backend/tests/transaction.test.js`
* **Langkah Kerja:**
  1. Tulis unit test yang memverifikasi User B gagal melakukan penarikan dari tabungan User A atau melakukan transfer dari dompet User A.
  2. Tambahkan pengecekan kepemilikan di `SavingService.withdraw`:
     - Verifikasi `goal.user_id === userId` (atau anggota keluarga jika tabungan bersama).
     - Verifikasi `wallet.user_id === userId`.
  3. Tambahkan pengecekan kepemilikan di `DebtService.recordPayment`:
     - Verifikasi `wallet.user_id === userId`.
  4. Tambahkan pengecekan di `TransactionService.transfer`:
     - Verifikasi `fromWallet.user_id === userId`.
  5. Verifikasi seluruh test lolos dengan `node --test backend/tests/*.test.js`.

### Task 3: Perbaikan Scope SQL & Isolasi Data Anggota Keluarga (SEC-03)
* **Tujuan:** Mencegah kebocoran transaksi finansial pribadi anggota keluarga ke anggota lain.
* **Berkas yang dimodifikasi:**
  - `backend/src/app.js` (route `/api/v1/family/members/:id/summary`)
  - `backend/src/services/transaction.service.js` (`getMemberSummary`)
  - `backend/tests/family.test.js`
* **Langkah Kerja:**
  1. Tulis test untuk memverifikasi bahwa endpoint summary anggota hanya mengembalikan transaksi dengan `scope = 'family'`, dan menolak jika anggota bukan dari keluarga yang sama.
  2. Pada `app.js`, periksa apakah target anggota memiliki `family_id` yang cocok dengan pemohon.
  3. Pada `TransactionService.getMemberSummary`, perbaiki query SQL:
     ```sql
     WHERE t.user_id = ? AND t.family_id = ? AND t.scope = 'family'
     ```
  4. Jalankan test untuk memastikan isolasi data pribadi berfungsi sempurna.

### Task 4: Atomisitas Saldo, Pengendalian Konkurensi, & NaN Guard (SEC-05, BUG-03)
* **Tujuan:** Mencegah inkonsistensi saldo akibat race condition dan input numerik invalid (`NaN`).
* **Berkas yang dimodifikasi:**
  - `backend/src/services/transaction.service.js`
  - `backend/src/services/wallet.service.js`
  - `backend/tests/transaction.test.js`
* **Langkah Kerja:**
  1. Ganti pengecekan `if (numAmount <= 0)` menjadi:
     ```javascript
     if (!Number.isFinite(numAmount) || numAmount <= 0) {
       throw new Error('Nominal transaksi harus berupa angka positif yang valid');
     }
     ```
  2. Pada operasi pengurangan saldo, gunakan query atomik bersyarat:
     ```sql
     UPDATE wallets SET balance = balance - ? WHERE id = ? AND balance >= ?
     ```

### Task 5: Timing-Safe Verification & Pengamanan JWT (SEC-06)
* **Tujuan:** Mencegah serangan *timing side-channel* pada verifikasi token dan mengeliminasi kunci rahasia statis.
* **Berkas yang dimodifikasi:**
  - `backend/src/services/auth.service.js`
* **Langkah Kerja:**
  1. Ganti perbandingan string `signature !== expectedSig` dengan buffer comparison yang aman (`crypto.timingSafeEqual`).
  2. Berikan peringatan keras di konsol saat server startup jika `JWT_SECRET` masih default.

### Task 6: Rate Limiting pada Endpoint Sensitif (SEC-07)
* **Tujuan:** Menghentikan serangan *brute force* dan *credential stuffing*.
* **Berkas yang dimodifikasi:**
  - `backend/src/middleware/rate_limit.middleware.js`
  - `backend/src/app.js`
* **Langkah Kerja:**
  1. Buat middleware `rateLimiter({ windowMs: 15 * 60 * 1000, max: 10 })`.
  2. Pasangkan pada route login, register, dan join family/company.

### Task 7: Persistensi Token SharedPreferences & Auto-Login Mobile (BUG-01)
* **Tujuan:** Pengguna tidak perlu login berulang kali setiap kali aplikasi Flutter dibuka kembali.
* **Berkas yang dimodifikasi:**
  - `frontend/lib/providers/auth_provider.dart`
  - `frontend/lib/screens/splash/splash_screen.dart`
* **Langkah Kerja:**
  1. Di `AuthProvider`, simpan `_token` dan data user ke `SharedPreferences` saat login sukses.
  2. Tambahkan metode `tryAutoLogin()` di `AuthProvider`.
  3. Di `SplashScreen`, panggil `await auth.tryAutoLogin()`. Jika valid, arahkan langsung ke `DashboardScreen`; jika tidak, ke `LoginScreen`.

### Task 8: Request Timeout & Fault Resilience pada Mobile (BUG-02)
* **Tujuan:** Menghindari aplikasi macet (*infinite loading*) saat jaringan seluler tidak stabil.
* **Berkas yang dimodifikasi:**
  - `frontend/lib/core/network/api_client.dart`
* **Langkah Kerja:**
  1. Tambahkan `.timeout(const Duration(seconds: 15))` pada setiap pemanggilan HTTP di `ApiClient`.

### Task 9: Verifikasi Regresi Menyeluruh & Build Release APK
* **Langkah Kerja:**
  1. Jalankan test suite backend: `node --test backend/tests/*.test.js`.
  2. Jalankan static analyzer Dart: `flutter_dart-mcp-server` / `analyze_files`.
  3. Kompilasi ulang APK Release Flutter: `flutter build apk --release`.
