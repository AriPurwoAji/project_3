# HydroServ — Hydraulic Service Booking App

Aplikasi manajemen booking teknisi hydraulic berbasis mobile. Client membuat booking servis, teknisi mengambil dan menyelesaikan job, manager memantau operasional melalui dashboard.

---

## Tech Stack

| Komponen | Teknologi |
|---|---|
| Mobile | Flutter (Android) |
| Backend | Go + Gin (Clean Architecture) |
| Database | Supabase (PostgreSQL) |
| Auth | JWT (HS256) |
| Storage | Supabase Storage |
| Notifikasi | Firebase Cloud Messaging (FCM) |
| Maps | OpenStreetMap (flutter_map + Nominatim) |

---

## Struktur Project

```
project_3/
  backend/   → REST API (Go)
  mobile/    → Aplikasi Android (Flutter)
```

---

## Role & Akses

| Role | Halaman Utama | Kemampuan |
|---|---|---|
| `manager` | Dashboard | Lihat semua booking, assign teknisi, statistik |
| `teknisi` | Job Board | Ambil job, update status, buat laporan |
| `client` | Daftar Booking | Buat booking, lihat booking milik PT sendiri |
| `sales` | Daftar Booking | Monitoring booking perusahaan |

---

## Alur Kerja

```
1. Client registrasi → verifikasi email → login
2. Client buat booking (pilih equipment, lokasi GPS/cari nama tempat, jenis servis)
3. Teknisi login → lihat job terbuka di Job Board → ambil (claim) job
4. Teknisi update status: in_progress → on_the_way → on_site → done
5. Teknisi buat laporan hydraulic → PDF otomatis digenerate
6. Manager pantau semua aktivitas via dashboard
```

---

## Cara Menjalankan

Ikuti panduan lengkap di masing-masing folder:

- **Backend (Go)** → [backend/README.md](backend/README.md)
- **Mobile (Flutter)** → [mobile/README.md](mobile/README.md)

---

## Setup Cepat

### 1. Clone repository

```bash
git clone https://github.com/AriPurwoAji/project_3.git
cd project_3
```

### 2. Setup backend

```bash
cd backend
# Buat file .env (lihat backend/README.md untuk semua variabel)
go mod tidy
go run ./cmd/api/main.go
```

### 3. Setup mobile

```bash
cd mobile
# Buat file .env berisi:
# API_BASE_URL=http://<IP_laptop>:8080/api/v1
flutter pub get
flutter run
```

---

## Akun untuk Testing

> **Catatan:**
> - Akun **Manager** diinsert manual via Supabase SQL Editor (demi keamanan sistem)
> - Akun **Teknisi** dan **Sales** dibuat oleh Manager melalui fitur manajemen tim di dalam aplikasi
> - Akun **Client** bisa dibuat sendiri via form registrasi — wajib verifikasi email sebelum bisa login

| Email | Password | Role | Keterangan |
|---|---|---|---|
| `manager@hydraulic.com` | `Manager123!` | Manager | Akses penuh + dashboard |
| `teknisi@hydraulic.com` | `Teknisi123!` | Teknisi | Job board + laporan |
| `sales@hydraulic.com` | `Sales123!` | Sales | Monitoring booking |
| `client.halliburton@hydraulic.com` | `Client123!` | Client | PT Halliburton |
| `client.ptkai@hydraulic.com` | `Client123!` | Client | PT KAI |
| `client.pln@hydraulic.com` | `Client123!` | Client | PT PLN |
| `aripurwo02@gmail.com` | `Client123!` | Client | PT DAHANA |

---

## Status Fitur

### Selesai ✅
- [x] Login & autentikasi JWT per role (manager / teknisi / client / sales)
- [x] Registrasi akun mandiri untuk client + **verifikasi email otomatis**
- [x] Buat booking + upload foto kerusakan + jadwal servis (scheduled_at)
- [x] **Pencarian lokasi site** — ketik nama tempat (Nominatim/OSM) atau gunakan GPS
- [x] **Mini-map** di detail booking + tombol navigasi ke Google Maps
- [x] **Push notification (FCM)** — notif real-time saat booking dibuat, diklaim, status berubah
- [x] Notifikasi in-app + badge unread count; mark single / baca semua
- [x] Isolasi data per perusahaan (booking & equipment)
- [x] Sales: monitoring booking perusahaan
- [x] Job board teknisi: Tab Open & Selesai; My Jobs terpisah dengan update status
- [x] Manager: assign teknisi, daftar teknisi
- [x] Dashboard statistik manager (summary, performa teknisi, tren servis)
- [x] Form laporan hydraulic lengkap (repair / inspeksi / maintenance) + foto before/after/damage
- [x] Generate PDF laporan otomatis dengan foto → upload ke Supabase Storage
- [x] Share PDF laporan via native share sheet (WhatsApp, Drive, dll)
- [x] Search & filter di semua halaman daftar
- [x] Fullscreen photo viewer dengan swipe & pinch-to-zoom
- [x] Edit profil, ganti password, equipment CRUD
- [x] Batalkan booking (client/manager, status open saja)

- [x] Refresh token otomatis — access token expired di-refresh tanpa logout
- [x] Notifikasi push + in-app saat job selesai (`done`) ke client
- [x] Filter dashboard berdasarkan rentang tanggal (dari / sampai)

### Belum Diimplementasi
> Semua fitur utama sudah diimplementasi.

---

## Environment Variables Backend

| Variabel | Keterangan |
|---|---|
| `APP_PORT` | Port server (default 8080) |
| `APP_URL` | URL publik backend (untuk link verifikasi email) |
| `DB_*` | Koneksi Supabase PostgreSQL |
| `JWT_SECRET` | Secret key JWT |
| `SUPABASE_*` | Konfigurasi Supabase Storage |
| `FCM_SERVICE_ACCOUNT_PATH` | Path ke file service account Firebase |
| `SMTP_HOST/PORT/USER/PASS/FROM` | Konfigurasi SMTP untuk email verifikasi |

> File `firebase-service-account.json` dan `.env` tidak disertakan di repository karena berisi credentials sensitif. Minta ke maintainer proyek.
