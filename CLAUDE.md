# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HydroServ** — a hydraulic technician service booking app for **PT Besttoflow System** (distributor resmi Parker & mitra Moog, berdiri 2008). Clients create service bookings, technicians claim and fulfill jobs, and managers oversee operations via a dashboard. The system enforces role-based access at both the API and UI level.

Tech stack: Flutter (mobile) + Go/Gin (REST API) + Supabase PostgreSQL (via pgx connection pool) + JWT auth.

---

## Backend (Go)

All commands run from the `backend/` directory.

```bash
# Run the server
go run ./cmd/api/main.go

# Build binary
go build -o bin/api ./cmd/api/main.go

# Run all tests
go test ./...

# Run tests for a specific package
go test ./internal/usecase/...

# Tidy dependencies
go mod tidy
```

**Environment** — copy `backend/.env` and set real values:
```
APP_PORT, DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
JWT_SECRET, SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_STORAGE_BUCKET
```

Database migrations are in `backend/migrations/` as numbered `.sql` files; run them manually against Supabase in order.

---

## Mobile (Flutter)

All commands run from the `mobile/` directory.

```bash
# Get dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Run on specific device
flutter run -d <device-id>

# Build APK (debug)
flutter build apk --debug

# Build APK (release)
flutter build apk --release

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze code
flutter analyze
```

**Environment** — `mobile/.env` is loaded at runtime via `flutter_dotenv`:
```
API_BASE_URL=http://10.0.2.2:8080/api/v1   # 10.0.2.2 = host machine from Android emulator
```

---

## Architecture

### Backend — Clean Architecture

Dependency direction: `handler → usecase → repository → domain`

```
backend/
  cmd/api/main.go           # Entry point: wires DB → repo → usecase → handler → router
  internal/
    domain/                 # Interfaces (Repository, Usecase) + entity structs. No external deps.
    usecase/                # Business logic. Depends only on domain interfaces.
    repository/             # SQL queries via pgx. Implements domain repository interfaces.
    delivery/http/
      handler/              # Gin handlers — parse request, call usecase, return response
      middleware/           # AuthMiddleware (JWT claims → gin context), RoleMiddleware
      router/               # Route registration with role guards
    infrastructure/
      database/             # pgxpool connection
      jwt/                  # Token generation & validation (HS256, 24h access / 720h refresh)
      storage/              # Supabase Storage (photo uploads)
      pdf/                  # PDF generation for reports
      fcm/                  # Firebase Cloud Messaging notifications
  pkg/
    response/               # Unified JSON envelope: { success, message, data }
    validator/              # Custom validation helpers
  migrations/               # Ordered SQL files (001–014)
```

The `domain/` package defines interfaces that both `usecase/` and `repository/` depend on — never the reverse.

### Mobile — Feature-first Flutter

No BLoC state management is wired up yet in pages; pages call `ApiClient.instance` directly with Dio.

```
mobile/lib/
  main.dart                  # Loads .env, sets up MaterialApp.router with GoRouter
  core/
    constants/app_constants.dart  # API base URL, storage keys, roles, enums (service types, urgency, status)
    network/api_client.dart        # Singleton Dio with Bearer token interceptor; clears storage on 401
    router/app_router.dart         # GoRouter with auth redirect; role → home route mapping
    theme/app_theme.dart           # AppTheme.lightTheme + color constants
    errors/                        # Error models
  features/
    auth/                    # Login page — POST /auth/login, stores tokens in FlutterSecureStorage
    booking/                 # Booking list — client/sales view
    job_board/               # Open jobs — teknisi view
    dashboard/               # Summary, performance, trends — manager only
    notification/            # In-app notifications
    report/                  # Hydraulic service reports
```

---

## Role-Based Access

| Role | Home Route | Capabilities |
|---|---|---|
| `manager` | `/dashboard` | Full read, assign technician, dashboard stats, konfirmasi akun user baru |
| `teknisi` | `/job-board` | Claim open bookings, update status, create/view reports |
| `client` | `/home` | Create bookings, view own bookings, konfirmasi hasil kerja teknisi |

> **Catatan:** Role `sales` **disembunyikan** dari UI dan routes (keputusan dosen), tetapi **TIDAK dihapus dari database** — sewaktu-waktu bisa diaktifkan kembali. Jangan hapus data role sales dari DB.

The Go router enforces roles via `middleware.RoleMiddleware(...)` per route group. The Flutter router reads `user_role` from `FlutterSecureStorage` and redirects accordingly.

---

## Key Domain Concepts

**Booking status flow**: `open → in_progress → on_the_way → on_site → waiting_confirmation → done` (or `cancelled`)

- A teknisi *claims* an open booking (sets `technician_id`, status → `in_progress`).
- A manager can also *assign* a technician directly.
- Status updates are restricted to the assigned technician.
- **[REVISI]** Sebelum teknisi bisa set status `done`, client harus konfirmasi/validasi hasil kerja terlebih dahulu.

**HydraulicReport** is created once per booking (after job completion). It includes: pressure readings, oil condition, leak details, parts replaced, photos (before/after/damage), and for `inspeksi` service type, a list of `InspectionItem` records (hose / cylinder / pump with specifications as JSONB).

**Fitting specs** (hose inspections) use controlled vocabularies: standard (ORFS/BSP/NPT/JIC/Metric/SAE_F61/SAE_F62), angle (straight/45/90/90_long), gender (male/female).

**Equipment** — setiap equipment milik perusahaan, field wajib: nama, deskripsi, lokasi/patokan (contoh: "Ruang Produksi A"). Satu booking bisa memiliki hingga 2 equipment. Saat teknisi claim job multi-equipment, teknisi memilih equipment mana yang dikerjakan terlebih dahulu.

**Repair prerequisite** — layanan `repair` hanya bisa dipilih jika client sudah memiliki riwayat booking `inspeksi` atau `maintenance` yang sudah selesai (status `done`) dan belum pernah digunakan sebagai referensi repair sebelumnya. Riwayat tersebut ditampilkan sebagai dropdown saat memilih Repair. Setelah dipakai, riwayat tersebut tidak bisa dipilih lagi (`reference_booking_id` di-lock).

---

## API Base URL

- Backend listens on `APP_PORT` (default `8080`).
- All routes are prefixed `/api/v1`.
- From Android emulator, use `10.0.2.2` to reach the host machine's localhost.
- Health check: `GET /ping` → `{ "message": "pong" }`.

---

## Deployment (Production — Railway)

Backend sudah di-deploy ke Railway, auto-deploy dari branch `develop`.

- **URL**: `https://project3-production-c96b.up.railway.app`
- **Health check**: `GET /ping`
- **Email**: Resend HTTP API dengan domain `hydroserv.my.id` (sudah terverifikasi)

Railway environment variables yang diperlukan:
```
APP_PORT          # otomatis dari Railway via PORT
DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD   # Supabase
JWT_SECRET
SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_STORAGE_BUCKET
RESEND_API_KEY    # Resend API key (jangan expose di log/chat)
SMTP_FROM         # noreply@hydroserv.my.id
FCM_SERVICE_ACCOUNT_JSON  # Firebase service account JSON (satu baris tanpa newline)
APP_URL           # https://project3-production-c96b.up.railway.app
```

Mobile `.env` untuk production:
```
API_BASE_URL=https://project3-production-c96b.up.railway.app/api/v1
```

---

## Branch Workflow

- `develop_trial` → branch kerja, push setiap fitur selesai untuk review
- `develop` → branch utama, merge dari `develop_trial` setelah review
- Railway auto-deploy dari `develop`
- **Jangan push langsung ke `develop`** — kerjakan di `develop_trial` dulu

---

## Status Fitur

### Sudah Selesai

- [x] Auth: login, register semua role, JWT access (24h) + refresh token (30h)
- [x] Email verifikasi akun via Resend HTTP API (domain `hydroserv.my.id`)
- [x] Foto profil + info perusahaan lengkap (client)
- [x] Edit profil client (update info perusahaan)
- [x] Booking: buat, lihat daftar (client/sales), claim (teknisi), assign (manager)
- [x] Job board: teknisi lihat & claim open booking
- [x] Status flow: `open → in_progress → on_the_way → on_site → done / cancelled`
- [x] HydraulicReport: buat, lihat, upload foto before/after/damage
- [x] InspectionItem untuk tipe `inspeksi` (hose/cylinder/pump + fitting specs JSONB)
- [x] Dashboard manager: summary stats, performance, trends
- [x] In-app notifications
- [x] PDF generation untuk laporan servis
- [x] Push notification via FCM (Firebase Cloud Messaging v1 HTTP API)
- [x] Railway deployment (Docker multi-stage, auto-deploy dari `develop`)
- [x] PageCache in-memory (TTL 2 menit) — tab-switch tidak spinner ulang
- [x] Token & role cache in-memory di ApiClient — eliminasi Keystore reads per request
- [x] GoRouter fade transition (180ms, CurvedAnimation easeOut)
- [x] Stateful BottomNav — tidak rebuild/flicker saat ganti tab
- [x] Navigasi ke Google Maps via `geo:` URI (muncul app chooser di Android)
- [x] pgxpool pre-warm (MinConns=2) — koneksi DB siap saat request pertama
- [x] **[REVISI]** Semua field registrasi wajib diisi + force-uppercase (inputFormatters) + Lainnya dropdown industri
- [x] **[REVISI]** Cascade dropdown lokasi registrasi: Provinsi (static 38) → Kota/Kab → Kecamatan → Desa (emsifa API) + Alamat Detail
- [x] **[REVISI]** Dialog syarat wajib baca saat pilih Emergency di form booking (Jabodetabek, < 4 jam)
- [x] **[REVISI]** Field Catatan/Rekomendasi di form laporan wajib diisi sebelum submit
- [x] **[REVISI]** Akun baru pending (is_active=FALSE), manager konfirmasi via tab "Menunggu" di TeamPage
- [x] **[REVISI]** Role `sales` disembunyikan dari UI/routes/create-user form (DB tetap intact)
- [x] **[REVISI]** Form equipment disederhanakan ke 3 field: nama, deskripsi, lokasi/patokan
- [x] **[REVISI]** Penyelesaian job alur baru: laporan submit → `waiting_confirmation` → client konfirmasi → `done` (endpoint `POST /bookings/:id/confirm`, notifikasi FCM ke client & teknisi)

### Akan Dikerjakan

- [ ] Laporan skripsi — format sesuai panduan Revisi Juli 2025 ITB BSG (file sudah diterima)
- [ ] Multi-user per perusahaan — beberapa akun client dalam 1 perusahaan yang sama

---

## Rekap Revisi HydroServ (Masukan Dosen)

Kerjakan di branch `develop_trial`. Tandai `[x]` saat selesai. Merge ke `develop` untuk deploy ke Railway.

### Role & Akun
- [x] **#1** Role `sales` disembunyikan dari seluruh UI/routes/form — **TIDAK dihapus dari DB**, backend middleware tetap mendukung akun sales lama
- [ ] **#2** Fitur lupa password — reset via email (Resend API sudah tersedia, kerjakan paling akhir)
- [x] **#3** Akun baru tidak langsung bisa login — status `is_active=FALSE` saat register, login ditolak dengan pesan khusus; manager konfirmasi via tab "Menunggu" di TeamPage (`GET /users/pending` + `PATCH /users/:id/activate`), email notifikasi ke client saat diaktifkan

### Registrasi ✅
- [x] **#4** Semua field input registrasi force-uppercase via `TextInputFormatter` (kecuali email & password)
- [x] **#5** Tambah opsi "Lainnya" di dropdown jenis industri — memunculkan field teks bebas
- [x] **#6** Field alamat/lokasi perusahaan dipindahkan ke form registrasi: cascade Provinsi (static 38) → Kota/Kab → Kecamatan → Desa (emsifa API) + Alamat Detail; disimpan ke `company_province`, `company_city`, `company_kecamatan`, `company_kelurahan`, `address`; digunakan untuk cek eligibilitas Emergency (Jabodetabek)
- [x] **#7** Field kota/alamat diubah menjadi dropdown bertingkat (tidak lagi teks bebas)

### Equipment
- [x] **#8** Form tambah/edit equipment disederhanakan — 3 field wajib: Nama Equipment, Deskripsi/keterangan mesin, Lokasi/patokan (contoh: "Ruang Produksi A")
- [x] **#9** Satu booking dapat memilih hingga 2 equipment sekaligus (`equipment_id_2` kolom di tabel `bookings`, migration 016)
- [x] **#10** Saat teknisi claim job dengan 2 equipment, tampilkan bottom sheet pilihan equipment mana yang dikerjakan terlebih dahulu (`work_equipment_id` disimpan saat claim)

### Booking
- [x] **#11** Tambah dialog syarat wajib baca & setujui saat memilih urgensi Emergency: _"Emergency hanya untuk area Jabodetabek dengan waktu tempuh di bawah 4 jam"_ — batal = revert ke Standard
- [x] **#12** Satu booking bisa memiliki lebih dari 1 item Inspeksi atau Maintenance

### Aturan Repair (Perubahan Besar)
- [x] **#13** Pilihan layanan Repair hanya aktif jika client sudah memiliki riwayat booking Inspeksi/Maintenance berstatus `done` yang belum pernah dipakai sebagai referensi — kolom `reference_booking_id` di tabel `bookings` (migration 015), endpoint `GET /bookings/available-references`
- [x] **#14** Saat memilih Repair, muncul dropdown riwayat inspeksi/maintenance yang tersedia sebagai referensi
- [x] **#15** Riwayat yang sudah digunakan sebagai referensi tidak akan muncul lagi di pilihan berikutnya (query excludes bookings already referenced)
- [x] **#16** Jika tidak ada riwayat tersedia → chip Repair disabled (opacity 0.45 + label "tidak tersedia") + banner keterangan alasan

### Teknisi
- [x] **#17** Halaman detail job menampilkan info booking dari client (deskripsi, foto) sebagai referensi validasi
- [x] **#18** Tambah checklist equipment mana saja yang sudah dikerjakan (terkait #9 & #10)

### Penyelesaian Job ✅
- [x] **#19** Field Catatan/Rekomendasi di form submit laporan wajib diisi (tidak boleh kosong)
- [x] **#20** Setelah laporan dikirim → status berubah ke `waiting_confirmation`; client menerima notifikasi FCM untuk konfirmasi/validasi hasil kerja
- [x] **#21** Setelah client konfirmasi → status `done` (backend: `POST /bookings/:id/confirm`, role: client/manager; teknisi tidak bisa set `done` secara langsung)

---

## Database Migrations — Status

| File | Status | Keterangan |
|---|---|---|
| 001–012 | ✅ Sudah di Supabase | — |
| 013 | ✅ Sudah di Supabase | Tambah kolom `province`, `kecamatan`, `kelurahan` ke tabel `companies` |
| 014 | ✅ Sudah di Supabase | Tambah kolom `description` ke tabel `hydraulic_equipment` |
| 015 | ✅ Sudah di Supabase | Tambah kolom `reference_booking_id` ke tabel `bookings` |
| 016 | ✅ Sudah di Supabase | Tambah kolom `equipment_id_2` + `work_equipment_id` ke tabel `bookings` |
| 017 | ⚠️ **Belum dijalankan** | Tambah kolom `done_equipment_ids` ke tabel `bookings` |
| 018 | ⚠️ **Belum dijalankan** | Buat tabel `booking_items` — sub-item/checklist per booking |

SQL migration 013 (jalankan di Supabase SQL Editor):
```sql
ALTER TABLE companies
    ADD COLUMN IF NOT EXISTS province   VARCHAR(100),
    ADD COLUMN IF NOT EXISTS kecamatan  VARCHAR(100),
    ADD COLUMN IF NOT EXISTS kelurahan  VARCHAR(100);
```

SQL migration 014 (jalankan di Supabase SQL Editor):
```sql
ALTER TABLE hydraulic_equipment
    ADD COLUMN IF NOT EXISTS description TEXT;
```

SQL migration 015 (jalankan di Supabase SQL Editor):
```sql
ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS reference_booking_id UUID REFERENCES bookings(id);
```

SQL migration 016 (jalankan di Supabase SQL Editor):
```sql
ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS equipment_id_2   UUID REFERENCES hydraulic_equipment(id),
    ADD COLUMN IF NOT EXISTS work_equipment_id UUID REFERENCES hydraulic_equipment(id);
```

SQL migration 017 (jalankan di Supabase SQL Editor):
```sql
ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS done_equipment_ids UUID[] DEFAULT ARRAY[]::UUID[];
```

SQL migration 018 (jalankan di Supabase SQL Editor):
```sql
CREATE TABLE IF NOT EXISTS booking_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id  UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    is_done     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_booking_items_booking_id ON booking_items(booking_id);
```
