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
| `sales` | Daftar Booking | Sama seperti client |

---

## Alur Kerja

```
1. Client login → buat booking (pilih equipment, lokasi, jenis servis)
2. Teknisi login → lihat job terbuka → ambil (claim) job
3. Teknisi update status: in_progress → on_the_way → on_site → done
4. Manager pantau semua aktivitas via dashboard
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
cp .env.example .env   # isi nilai sesuai Supabase project kamu
go mod tidy
go run ./cmd/api/main.go
```

### 3. Setup mobile

```bash
cd mobile
# buat file .env berisi:
# API_BASE_URL=http://<IP_laptop>:8080/api/v1
flutter pub get
flutter run
```

---

## Akun Default untuk Testing

| Email | Password | Role |
|---|---|---|
| `manager@hydraulic.com` | `Manager123!` | Manager |
| `teknisi@hydraulic.com` | `Teknisi123!` | Teknisi |
| `client.ptkai@hydraulic.com` | `Client123!` | Client (PT KAI) |
| `client.pln@hydraulic.com` | `Client123!` | Client (PT PLN) |

> Akun harus diinsert manual via Supabase SQL Editor. Lihat [backend/README.md](backend/README.md) untuk langkah lengkapnya.

---

## Status Fitur

### Selesai ✅
- Login & autentikasi JWT per role (manager / teknisi / client / sales)
- Registrasi akun mandiri untuk client
- Buat booking + upload foto kerusakan + jadwal servis (scheduled_at)
- Isolasi data per perusahaan (booking & equipment)
- Sales: lihat semua booking perusahaan + badge nama pembuat
- Job board teknisi: Tab Open & Selesai; My Jobs terpisah dengan update status
- Paginasi infinite scroll (booking list & job board)
- Manager: assign teknisi, daftar teknisi, search teknisi
- Dashboard statistik manager (summary, performa teknisi, tren servis)
- Form laporan hydraulic lengkap (repair / inspeksi / maintenance) + foto before/after/damage
- Generate PDF laporan otomatis dengan foto → upload ke Supabase Storage
- Share PDF laporan via native share sheet (WhatsApp, Drive, dll)
- Search & filter di semua halaman daftar (booking, laporan, job board, teknisi)
- Fullscreen photo viewer dengan swipe & pinch-to-zoom
- Notifikasi in-app otomatis (booking, claim, assign, update status)
- Bell icon dengan badge unread count; mark single / baca semua
- Edit profil, ganti password, equipment CRUD
- Profil per role: stats teknisi, daftar equipment untuk client
- Batalkan booking (client/manager, status open saja)

### Belum Diimplementasi
- FCM push notification (perlu `google-services.json` + Firebase setup)
- Fitur lokasi / GPS / Maps
