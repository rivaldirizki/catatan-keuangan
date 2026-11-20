# Aplikasi Catatan Keuangan Pribadi & Keluarga (Personal & Family Finance)

Aplikasi pencatatan keuangan modern multi-user dan keluarga yang dibangun dengan prinsip **Domain-Driven Design (Matt Pocock Skills)**, **TDD & Verification Gate (Superpowers)**, dan **Financial Dashboard Design Standards (UI/UX Pro Max)**.

---

## Arsitektur Sistem

- **Backend & Web Admin:** Node.js (Express.js, JWT, bcryptjs, mysql2)
- **Database:** MySQL (XAMPP MySQL `localhost:3306`)
- **Frontend Client:** Flutter 3.x / Dart 3.x (Material 3, Provider State Management, UI/UX Pro Max Fintech Tokens)

---

## Fitur Utama

1. **Multi-User & Privasi Ketat:**
   - Registrasi & Login dengan enkripsi password yang aman.
   - Setiap pengguna secara *default* hanya dapat mengakses data dompet dan transaksinya sendiri (*tenant isolation*).

2. **Keluarga / Family Sharing:**
   - Pengguna dapat membuat grup keluarga dan mendapatkan **Kode Undangan (Invite Code)** 8-karakter.
   - Anggota keluarga yang bergabung dapat memilih mode tampilan pada aplikasi:
     - **Mode Pribadi:** Hanya menampilkan transaksi dan dompet milik sendiri.
     - **Mode Keluarga:** Menggabungkan dan menampilkan arus kas bersama anggota keluarga.

3. **Tabungan / Savings Vault ("Saldo Dompet Keluar, Tabungan Bertambah"):**
   - Menetapkan target tabungan (misal: *Dana Darurat*, *Beli Rumah*, *Liburan*).
   - Penyetoran tabungan memotong saldo dompet sumber dan menambahkan ke saldo tabungan secara **ACID Database Transaction**.
   - Indikator progress bar pencapaian target tabungan ($0\% - 100\%$).

4. **Catatan Hutang & Piutang dengan Jatuh Tempo:**
   - Mendukung **Hutang** (kewajiban kita ke orang lain) dan **Piutang** (hak kita dari orang lain).
   - Status otomatis berbasis tanggal jatuh tempo:
     - 🔴 **Overdue** (melewati batas jatuh tempo)
     - 🟡 **Due Soon** (jatuh tempo dalam $\le$ 3 hari)
     - ⚪ **Active / Unpaid**
     - 🟢 **Paid / Lunas**
   - Mendukung pembayaran bertahap (cicilan) dan pelunasan dengan pemotongan otomatis ke saldo dompet.

5. **Web Admin Dashboard:**
   - Portal monitoring statistik sistem secara *real-time*: total pengguna, grup keluarga, volume transaksi, dan audit data.

---

## Struktur Folder

```
finance/
├── backend/                   # Node.js + Express + MySQL REST API & Web Admin
│   ├── src/
│   │   ├── config/            # Pool Database MySQL (mysql2/promise)
│   │   ├── controllers/       # Controller Auth, Family, Wallet, Tx, Saving, Debt, Admin
│   │   ├── middleware/        # JWT Authentication & Role Checking
│   │   ├── services/          # Core Business Logic & Database Transactions
│   │   ├── app.js             # Express App Configuration & Routes
│   │   └── server.js          # Server Entrypoint
│   ├── database/              # schema.sql & migrate.js
│   ├── tests/                 # 22 Test Suites (Node.js Test Runner)
│   └── package.json
│
├── frontend/                  # Flutter Multi-Platform Client
│   ├── lib/
│   │   ├── core/              # Theme (Material 3 Fintech Tokens), API Client, Constants
│   │   ├── models/            # UserModel, FamilyModel, WalletModel, TransactionModel, etc.
│   │   ├── providers/         # AuthProvider & FinanceProvider (State Management)
│   │   ├── screens/           # Auth, Dashboard, Savings Vault, Debts & Due Dates
│   │   ├── widgets/           # BalanceCard, DueDateBadge, FamilySwitcher
│   │   └── main.dart          # Flutter Entrypoint
│   └── pubspec.yaml
│
├── skills/                    # Repositori Skills (mattpocock-skills, superpowers, ui-ux-pro-max)
└── PLAN.md                    # Dokumen Rencana & Spesifikasi Implementasi
```

---

## Panduan Menjalankan Aplikasi

### 1. Menjalankan Backend & Web Admin (Node.js & MySQL)

1. Pastikan modul **MySQL** pada panel kontrol XAMPP Anda sudah berjalan (**Running** pada port `3306`).
2. Masuk ke folder backend:
   ```bash
   cd c:\xampp\htdocs\finance\backend
   ```
3. Jalankan migrasi database (opsional, server juga otomatis menginisialisasi skema saat start):
   ```bash
   npm run migrate
   ```
4. Jalankan server:
   ```bash
   npm start
   ```
   Server akan berjalan pada:
   - **REST API:** `http://localhost:3000/api/v1`
   - **Web Admin Portal:** `http://localhost:3000/admin`
   - **Health Check:** `http://localhost:3000/health`

### 2. Menjalankan Pengujian Otomatis (TDD Verification)

Jalankan seluruh test suite di backend:
```bash
cd c:\xampp\htdocs\finance\backend
npm test
```
*Hasil: 22 tests passing across 7 suites.*

### 3. Menjalankan Klien Frontend (Flutter)

1. Masuk ke direktori frontend:
   ```bash
   cd c:\xampp\htdocs\finance\frontend
   ```
2. Ambil paket dependensi:
   ```bash
   flutter pub get
   ```
3. Jalankan aplikasi pada perangkat/emulator atau Chrome:
   ```bash
   flutter run -d chrome
   # atau untuk emulator Android:
   flutter run
   ```

---

## UI/UX Pro Max Compliance Checklist

- [x] **Skema Warna Fintech:** Slate `#0F172A`, Emerald `#10B981` (pemasukan), Crimson `#EF4444` (pengeluaran), Amber `#F59E0B` (jatuh tempo hutang), Blue `#2563EB` (tabungan).
- [x] **Aksesibilitas Kontras:** Memenuhi rasio kontras WCAG AA $\ge 4.5:1$.
- [x] **Touch Target:** Minimal $44 \times 44$ px pada seluruh komponen interaktif.
- [x] **Format Mata Uang:** Format rapi Rupiah (`Rp 1.500.000`) dan tipografi monospace untuk angka.
- [x] **Zero Emoji Icons:** Menggunakan icon resmi Material Icons / SVG secara konsisten.
