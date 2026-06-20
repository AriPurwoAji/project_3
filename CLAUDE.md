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
  migrations/               # Ordered SQL files (001–013)
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

**Booking status flow**: `open → in_progress → on_the_way → on_site → done` (or `cancelled`)

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

### Akan Dikerjakan

- [ ] Laporan skripsi — format sesuai panduan Revisi Juli 2025 ITB BSG (file sudah diterima)
- [ ] Multi-user per perusahaan — beberapa akun client dalam 1 perusahaan yang sama

---

## Revisi Batch 1 (Masukan Dosen)

Kerjakan di branch `develop_trial`. Tandai `[x]` saat selesai.

### Role & Akun
- [ ] Sembunyikan role `sales` dari UI/routes (frontend + backend middleware) — **JANGAN hapus dari DB**
- [ ] Fitur lupa password — reset via email (Resend API sudah tersedia)
- [ ] Akun baru status `pending` — hanya bisa login setelah Manager konfirmasi/aktivasi

### Registrasi ✅ (selesai di develop_trial, belum merge ke develop)
- [x] Semua field registrasi force-uppercase via `TextInputFormatter` (bukan hanya auto-cap kata)
- [x] Dropdown industri: tambah opsi "Lainnya" yang memunculkan field teks bebas
- [x] Cascade lokasi perusahaan: Provinsi (static) → Kota/Kabupaten → Kecamatan → Desa (emsifa API) + Alamat Detail
  - Data disimpan ke: `company_province`, `company_city` (kota), `company_kecamatan`, `company_kelurahan`, `address`
  - **Migration 013 harus dijalankan di Supabase** (tambah kolom `province`, `kecamatan`, `kelurahan` ke tabel `companies`)
  - Lokasi ini digunakan untuk cek eligibilitas Emergency (Jabodetabek)

### Equipment
- [ ] Form tambah equipment disederhanakan — hanya 3 field wajib: nama, deskripsi, lokasi/patokan
- [ ] Hapus field lama yang tidak relevan dari form dan tabel DB jika ada
- [ ] Satu booking support hingga 2 equipment (`equipment_ids[]` array di DB)
- [ ] Saat teknisi claim job multi-equipment, tampilkan pilihan equipment mana yang dikerjakan dulu
- [ ] Tambah checklist progress per equipment di halaman teknisi

### Booking ✅ (sebagian selesai)
- [x] Dialog syarat wajib baca & setujui saat pilih urgensi Emergency: _"Hanya Jabodetabek, tempuh < 4 jam"_ — batal = revert ke Standard
- [ ] Satu booking bisa punya lebih dari 1 item inspeksi atau maintenance
- [ ] Layanan `repair` hanya aktif jika ada riwayat inspeksi/maintenance yang belum dipakai:
  - Tambah kolom `reference_booking_id` di tabel `bookings`
  - Endpoint baru: `GET /bookings/available-references`
  - Dropdown riwayat muncul saat Repair dipilih; setelah dipakai tidak bisa dipilih lagi
  - Jika tidak ada riwayat → opsi Repair disabled + keterangan alasan

### Teknisi ✅ (sebagian selesai)
- [ ] Halaman detail job tampilkan info booking dari client (deskripsi, foto) sebagai referensi
- [x] Field Catatan/Rekomendasi di form submit laporan wajib diisi (tidak boleh kosong)

### Penyelesaian Job (Alur Baru)
- [ ] Setelah teknisi submit laporan → status berubah ke `waiting_confirmation` (bukan langsung `done`)
- [ ] Client menerima notifikasi untuk konfirmasi hasil kerja
- [ ] Client buka app → validasi/setujui hasil kerja
- [ ] Setelah client konfirmasi → teknisi bisa set status `done`

---

## Database Migrations — Status

| File | Status | Keterangan |
|---|---|---|
| 001–012 | ✅ Sudah di Supabase | — |
| 013 | ⚠️ **Belum dijalankan** | Tambah kolom `province`, `kecamatan`, `kelurahan` ke tabel `companies` |

SQL migration 013 (jalankan di Supabase SQL Editor):
```sql
ALTER TABLE companies
    ADD COLUMN IF NOT EXISTS province   VARCHAR(100),
    ADD COLUMN IF NOT EXISTS kecamatan  VARCHAR(100),
    ADD COLUMN IF NOT EXISTS kelurahan  VARCHAR(100);
```
