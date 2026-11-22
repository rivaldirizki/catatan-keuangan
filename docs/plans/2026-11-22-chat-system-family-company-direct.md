# 💬 Sistem Grup Chat Multi-Konteks (Keluarga, Perusahaan, & Pribadi dengan Sistem Undangan) - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Membangun sistem perpesanan (chat) terintegrasi di Dompet Linc yang mendukung 3 jenis ruang obrolan: Grup Chat Keluarga otomatis, Grup Chat Perusahaan otomatis, dan Chat Pribadi 1-on-1 dengan sistem undangan (*invite & accept/reject*) sebelum obrolan dapat dimulai.

**Architecture:** 
- Backend REST API dengan Node.js/Express dan skema relasional MySQL (`chat_rooms`, `chat_members`, `chat_messages`).
- Otorisasi berbasis anggota (*Membership-based authorization*) dengan validasi status undangan (`pending` / `accepted`).
- Sinkronisasi otomatis anggota keluarga dan perusahaan saat bergabung atau membuat organisasi.
- Frontend Flutter mobile dengan `ChatProvider`, timer-controlled smart polling saat layar chat aktif, dan UI bergaya Apple iOS 18 (*bubble chat*, banner undangan interaktif, badge unread).

**Tech Stack:** 
- Backend: Node.js (ES Modules), Express.js, MySQL / MockDatabase, JWT, Node native test runner (`node:test`).
- Frontend: Flutter 3.x, Dart, Provider state management, Google Fonts (Inter), HapticFeedback.

---

## 1. Analisis Kebutuhan & Alur Kerja (Workflow Analysis)

```mermaid
flowchart TD
    subgraph Grup Keluarga & Perusahaan
        A[User Bergabung ke Family / Company] --> B[Sistem Otomatis Mendaftarkan ke Room Chat]
        B --> C[Status Member Langsung: 'accepted']
        C --> D[Semua Anggota Dapat Mengirim & Membaca Pesan]
    end

    subgraph Chat Pribadi (Direct Chat)
        E[User A Masukkan Kode Undangan Personal User B] --> F[Room Direct Dibuat]
        F --> G[User A: 'accepted' | User B: 'pending']
        G --> H{User B Menanggapi Undangan?}
        H -- Tolak (Reject) --> I[Status 'rejected' - Chat Dibatalkan]
        H -- Terima (Accept) --> J[Status 'accepted' - Room Aktif]
        J --> K[User A dan User B Dapat Saling Mengirim Pesan & Berbagi Finansial]
    end
```

### Rincian Aturan Bisnis (Business Rules)
1. **Grup Chat Keluarga (`type: 'family'`)**:
   - Terikat langsung ke `family_id`.
   - Hanya anggota keluarga yang sama yang dapat membaca dan mengirim pesan.
   - Ketika ada anggota baru yang bergabung via invite code keluarga, sistem secara otomatis memasukkan anggota tersebut ke room chat keluarga.
2. **Grup Chat Perusahaan (`type: 'company'`)**:
   - Terikat langsung ke `company_id`.
   - Hanya anggota perusahaan yang sama yang dapat membaca dan mengirim pesan.
   - Anggota baru otomatis menjadi partisipan saat bergabung ke perusahaan.
3. **Chat Pribadi 1-on-1 (`type: 'direct'`)**:
   - Memerlukan **Kode Undangan Personal** unik milik masing-masing user (misal 8 karakter, contoh: `CHAT-8F3A2B`).
   - Setiap pengguna memiliki menu "Salin Kode Chat Saya" untuk dibagikan ke teman/rekan.
   - User penerima (User B) akan melihat kartu undangan masuk di tab "Pribadi" dengan dua opsi: **Terima (Accept)** dan **Tolak (Reject)**.
   - Sebelum User B menerima undangan, tidak ada pesan yang dapat dikirim oleh kedua pihak (*Forbidden / 403 Room Not Active*).
   - Mencegah spam undangan ganda: Jika sudah ada undangan berstatus `pending` atau `accepted` antara User A dan User B, sistem menolak pembuatan undangan duplikat.
4. **Berbagi Catatan Finansial (Financial Sharing Card)**:
   - Pengguna dapat mengirimkan ringkasan transaksi, laporan pengeluaran, atau reminder hutang langsung ke dalam chat room sebagai kartu interaktif.
5. **Indikator Pengiriman & Pembacaan Pesan (WhatsApp/Telegram Style)**:
   - **Jam Merah (Pending / Gagal)**: Pesan sedang dikirim atau offline/gagal kirim (`Icons.access_time_rounded`, warna merah `#FF3B30`).
   - **Centang 1 Abu-abu (`sent`)**: Pesan tersimpan di server, belum dibaca siapa pun (`Icons.check_rounded`, abu-abu `#8E8E93`).
   - **Centang 2 Abu-abu (`partially_read`)**: Khusus grup chat (keluarga/perusahaan), dibaca oleh sebagian anggota namun belum seluruhnya (`Icons.done_all_rounded`, abu-abu `#8E8E93`).
   - **Centang 2 Biru (`read`)**:
     - Pada Chat Pribadi: Sudah dibaca oleh lawan bicara (`Icons.done_all_rounded`, warna biru `#34B7F1`).
     - Pada Chat Grup (Keluarga/Perusahaan): Sudah dibaca oleh **seluruh anggota aktif lainnya** dalam grup.

---

## 2. Desain Database & Skema Relasional

### Tabel `chat_rooms`
```sql
CREATE TABLE IF NOT EXISTS chat_rooms (
  id INT AUTO_INCREMENT PRIMARY KEY,
  type ENUM('family', 'company', 'direct') NOT NULL,
  family_id INT NULL,
  company_id INT NULL,
  name VARCHAR(255) NULL,
  created_by INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE CASCADE,
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);
```

### Tabel `chat_members`
```sql
CREATE TABLE IF NOT EXISTS chat_members (
  id INT AUTO_INCREMENT PRIMARY KEY,
  room_id INT NOT NULL,
  user_id INT NOT NULL,
  role ENUM('admin', 'member') DEFAULT 'member',
  status ENUM('pending', 'accepted', 'rejected') DEFAULT 'accepted',
  last_read_message_id INT NOT NULL DEFAULT 0,
  last_read_at TIMESTAMP NULL,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY unique_room_user (room_id, user_id)
);
```

### Tabel `chat_messages`
```sql
CREATE TABLE IF NOT EXISTS chat_messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  room_id INT NOT NULL,
  user_id INT NOT NULL,
  message TEXT NOT NULL,
  message_type ENUM('text', 'system', 'financial_share') DEFAULT 'text',
  metadata JSON NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

---

## 3. Algoritma Kalkulasi Centang Pesan
Pada saat `GET /api/v1/chat/rooms/:id/messages`:
- $N$ = jumlah anggota lain yang `accepted` di dalam room selain pengirim.
- $R$ = jumlah anggota lain yang memiliki `last_read_message_id >= message.id`.
- Jika $N = 1$ (Direct):
  - $R = 0 \to$ `delivery_status: 'sent'` (Centang 1)
  - $R = 1 \to$ `delivery_status: 'read'` (Centang 2 Biru)
- Jika $N > 1$ (Grup Keluarga/Perusahaan):
  - $R = 0 \to$ `delivery_status: 'sent'` (Centang 1)
  - $0 < R < N \to$ `delivery_status: 'partially_read'` (Centang 2 Abu-abu)
  - $R = N \to$ `delivery_status: 'read'` (Centang 2 Biru)
- Sisi Flutter Client:
  - Pesan belum menerima response ID dari server $\to$ `pending` (Jam Merah ⏱️).

---

## 3. Desain REST API Endpoints

| Metode | Endpoint | Deskripsi | Otorisasi & Validasi |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/chat/rooms` | Mengambil semua ruang chat aktif user (keluarga, perusahaan, direct) | JWT (Hanya room berstatus `accepted`) |
| `GET` | `/api/v1/chat/invitations` | Mengambil daftar undangan chat masuk untuk user ini | JWT (Hanya member dengan status `pending`) |
| `POST` | `/api/v1/chat/direct/invite` | Mengirim undangan chat pribadi ke user lain via email | JWT (Validasi user target ada & bukan diri sendiri) |
| `POST` | `/api/v1/chat/invitations/:id/accept` | Menerima undangan chat pribadi | JWT (Hanya user target yang diundang) |
| `POST` | `/api/v1/chat/invitations/:id/reject` | Menolak undangan chat pribadi | JWT (Hanya user target yang diundang) |
| `GET` | `/api/v1/chat/rooms/:id/messages` | Mengambil pesan obrolan (dukungan query `after_id` untuk polling efisien) | JWT (Harus member room dengan status `accepted`) |
| `POST` | `/api/v1/chat/rooms/:id/messages` | Mengirim pesan teks baru ke room | JWT (Harus member room dengan status `accepted`) |
| `POST` | `/api/v1/chat/rooms/:id/read` | Menandai seluruh pesan di room telah dibaca | JWT |

---

## 4. Rencana Implementasi Bertahap (Bite-Sized Tasks)

### Task 1: Skema Database & MockDatabase Support
- **Berkas yang dimodifikasi:**
  - `backend/src/config/database.js`:
    - Tambahkan DDL tabel `chat_rooms`, `chat_members`, dan `chat_messages` pada inisialisasi MySQL.
    - Tambahkan mock tables `chat_rooms: []`, `chat_members: []`, `chat_messages: []` di `MockDatabase`.
    - Tambahkan penanganan query join pesan dan member di `MockDatabase`.
- **Langkah Kerja:**
  1. Perbarui `backend/src/config/database.js` untuk membuat tabel-tabel chat jika belum ada.
  2. Tambahkan mock store di `MockDatabase` agar unit test dapat berjalan tanpa dependensi koneksi MySQL fisik.
  3. Verifikasi dengan menjalankan `node --test backend/tests/db.test.js`.

### Task 2: ChatService & Logika Bisnis (TDD)
- **Berkas yang dibuat / dimodifikasi:**
  - Buat: `backend/src/services/chat.service.js`
  - Buat: `backend/tests/chat.test.js`
- **Langkah Kerja:**
  1. Tulis failing test di `backend/tests/chat.test.js`:
     - Test auto-create / retrieve grup chat keluarga saat user bergabung.
     - Test auto-create / retrieve grup chat perusahaan saat user bergabung.
     - Test direct chat invitation (User A undang User B → status User B adalah `pending`).
     - Test penolakan pengiriman pesan jika room direct masih `pending`.
     - Test User B menerima undangan (`accept`) → kedua user dapat saling bertukar pesan.
     - Test User B menolak undangan (`reject`).
     - Test penolakan akses (BOLA) dari user pihak ketiga yang bukan anggota room.
  2. Implementasikan fungsi-fungsi di `backend/src/services/chat.service.js`:
     - `getOrCreateFamilyRoom(familyId, userId)`
     - `getOrCreateCompanyRoom(companyId, userId)`
     - `sendDirectInvite(senderUserId, targetEmail)`
     - `respondToInvitation(invitationMemberId, userId, action)` ('accept' / 'reject')
     - `getUserRooms(userId, familyId, companyId)`
     - `getPendingInvitations(userId)`
     - `getRoomMessages(roomId, userId, afterId = null)`
     - `sendMessage(roomId, userId, message, type = 'text')`
     - `markRoomAsRead(roomId, userId)`
  3. Jalankan test: `node --test backend/tests/chat.test.js` hingga seluruh skenario lolos.
  4. Lakukan commit berkas backend service dan test.

### Task 3: REST API Routes & Integrasi Server
- **Berkas yang dimodifikasi:**
  - `backend/src/app.js`
- **Langkah Kerja:**
  1. Registrasikan rute chat di `backend/src/app.js`:
     - `GET /api/v1/chat/rooms`
     - `GET /api/v1/chat/invitations`
     - `POST /api/v1/chat/direct/invite`
     - `POST /api/v1/chat/invitations/:id/accept`
     - `POST /api/v1/chat/invitations/:id/reject`
     - `GET /api/v1/chat/rooms/:id/messages`
     - `POST /api/v1/chat/rooms/:id/messages`
     - `POST /api/v1/chat/rooms/:id/read`
  2. Hubungkan event saat keluarga dibuat (`FamilyService.createFamily`) atau bergabung (`FamilyService.joinFamily`) agar otomatis mendaftarkan ke room chat keluarga.
  3. Hubungkan event saat perusahaan dibuat (`CompanyService.createCompany`) atau bergabung (`CompanyService.joinCompany`) agar otomatis mendaftarkan ke room chat perusahaan.
  4. Jalankan seluruh backend test suite: `node --test backend/tests/*.test.js`.

### Task 4: Flutter Models & Provider State Management
- **Berkas yang dibuat / dimodifikasi:**
  - Buat: `frontend/lib/models/chat_room_model.dart`
  - Buat: `frontend/lib/models/chat_message_model.dart`
  - Buat: `frontend/lib/models/chat_invitation_model.dart`
  - Buat: `frontend/lib/providers/chat_provider.dart`
  - Modifikasi: `frontend/lib/core/constants/api_constants.dart`
  - Modifikasi: `frontend/lib/main.dart` (daftarkan `ChatProvider` di `MultiProvider`)
- **Langkah Kerja:**
  1. Tambahkan endpoint chat di `ApiConstants`.
  2. Definisikan `ChatRoomModel`, `ChatMessageModel`, dan `ChatInvitationModel` dengan serialisasi JSON yang aman dan toleran tipe data.
  3. Buat `ChatProvider`:
     - Memuat daftar room aktif dan undangan pending.
     - Fungsi `inviteUser(String email)`.
     - Fungsi `acceptInvitation(int invitationId)` dan `rejectInvitation(int invitationId)`.
     - Fungsi `fetchMessages(int roomId)` dan `sendMessage(int roomId, String message)`.
     - Smart polling timer (berjalan setiap 3 detik hanya saat user sedang membuka room tertentu, langsung berhenti begitu user keluar dari layar obrolan).
  4. Daftarkan `ChatProvider` di `main.dart`.

### Task 5: Flutter UI Screens & Bottom Navigation Bar Integration
- **Berkas yang dibuat / dimodifikasi:**
  - Buat: `frontend/lib/screens/chat/chat_list_screen.dart` (Daftar nama user chat pribadi, grup keluarga, & grup perusahaan)
  - Buat: `frontend/lib/screens/chat/chat_room_screen.dart` (Layar ruang obrolan)
  - Buat: `frontend/lib/screens/chat/widgets/chat_bubble.dart` (Bubble pesan dengan ikon jam merah, centang 1, centang 2 abu-abu, dan centang 2 biru)
  - Buat: `frontend/lib/screens/chat/widgets/invitation_card.dart`
  - Modifikasi: `frontend/lib/screens/dashboard/dashboard_screen.dart` (Menambahkan tab ke-5 "Pesan" pada `bottomNavigationBar` dan `IndexedStack`)
- **Langkah Kerja:**
  1. Perluas `bottomNavigationBar` pada `dashboard_screen.dart` menjadi 5 tab:
     - 0: Ringkasan
     - 1: Riwayat
     - 2: Celengan / Proyek & Kas
     - 3: Hutang
     - 4: **Pesan 💬** (`Icons.chat_bubble_outline_rounded`) dengan badge jumlah unread.
  2. Bangun `chat_list_screen.dart`:
     - Bagian Pribadi: Daftar nama-nama user yang chat dengan kita. Klik nama user $\to$ langsung masuk ke `ChatRoomScreen` user tersebut.
     - Bagian Keluarga: Menampilkan grup chat keluarga. Klik $\to$ masuk ke ruang obrolan keluarga.
     - Bagian Perusahaan: Menampilkan grup chat perusahaan. Klik $\to$ masuk ke ruang obrolan perusahaan.
     - Banner permohonan obrolan masuk dengan tombol Terima/Tolak.
     - Dialog "Salin Kode Chat Saya" dan input kode teman untuk memulai obrolan baru.
  3. Bangun `chat_room_screen.dart`:
     - Header nama lawan bicara / grup dengan foto profil & status online/member.
     - Bubble pesan dengan visualisasi jam merah (pending), centang 1 (sent), centang 2 abu-abu (dibaca sebagian), dan centang 2 biru (dibaca semua).
     - Text field pengiriman pesan dengan tombol share kartu finansial.
  4. Pasang `ChatListScreen` sebagai child ke-4 di `IndexedStack` dashboard.

### Task 6: Verifikasi, Analisis Dart, & Release APK
- **Langkah Kerja:**
  1. Jalankan `flutter_dart-mcp-server:analyze_files` untuk memastikan 0 warning / errors.
  2. Jalankan seluruh unit test backend `node --test backend/tests/*.test.js`.
  3. Kompilasi ulang APK Release: `flutter build apk --release`.
  4. Git commit dan push ke remote repository `origin/master` dan `origin/main`.

---

## 5. Pertanyaan & Keputusan Desain (Decisions & Inputs)

1. **Penyampaian Undangan Chat Pribadi**:
   - *Opsi A (Rekomendasi)*: Menggunakan alamat email akun terdaftar. Sistem mencari user berdasarkan email dan mengirimkan undangan chat.
   - *Opsi B*: Menggunakan kode unik (misal 6 digit kode invite perorangan).
2. **Konteks Transaksi Finansial dalam Chat (Fitur Tambahan Nilai)**:
   - Apakah diinginkan tombol "Bagikan Catatan Finansial" di dalam chat (misalnya membagikan rincian pengeluaran bersama atau tagihan kas langsung ke grup keluarga/perusahaan)?
