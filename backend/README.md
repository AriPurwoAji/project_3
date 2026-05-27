# HydroServ — Backend (Go)

REST API untuk aplikasi booking teknisi hydraulic. Dibangun dengan Go + Gin, database PostgreSQL via Supabase.

---

## Prasyarat

- [Go](https://go.dev/dl/) versi 1.21 atau lebih baru
- Akun [Supabase](https://supabase.com) dengan project yang sudah dibuat
- Git

Cek versi Go:
```bash
go version
```

---

## Setup Pertama Kali

### 1. Clone repository

```bash
git clone https://github.com/AriPurwoAji/project_3.git
cd project_3/backend
```

### 2. Install dependencies

```bash
go mod tidy
```

### 3. Buat file environment

Buat file `.env` di dalam folder `backend/`:

```env
APP_PORT=8080

DB_HOST=db.xxxxxxxxxxxx.supabase.co
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=your_supabase_password

JWT_SECRET=your_random_secret_key_min_32_chars

SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_SERVICE_KEY=your_supabase_service_role_key
SUPABASE_STORAGE_BUCKET=hydraulic-photos
```

> Nilai `DB_HOST`, `DB_PASSWORD`, `SUPABASE_URL`, dan `SUPABASE_SERVICE_KEY` bisa didapat dari dashboard Supabase → Settings → Database / API.

### 4. Jalankan migrasi database

Buka **Supabase SQL Editor**, lalu jalankan file SQL berikut secara berurutan:

```
migrations/001_create_users.sql
migrations/002_create_companies.sql
migrations/003_create_hydraulic_equipment.sql
migrations/004_create_bookings.sql
migrations/005_create_hydraulic_reports.sql
migrations/006_create_inspection_items.sql
migrations/007_create_notifications.sql
migrations/008_create_booking_status_logs.sql
migrations/009_create_indexes.sql
```

Setelah itu jalankan query ini untuk menambahkan kolom `company_id` ke tabel users:

```sql
ALTER TABLE users
ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES companies(id);
```

### 5. Buat akun pertama (Manager)

Jalankan di Supabase SQL Editor:

```sql
INSERT INTO users (email, password_hash, full_name, role)
VALUES (
    'manager@hydraulic.com',
    crypt('Admin123!', gen_salt('bf', 12)),
    'Manager Admin',
    'manager'
) ON CONFLICT (email) DO NOTHING;
```

---

## Menjalankan Server

```bash
go run ./cmd/api/main.go
```

Server berjalan di `http://localhost:8080`

Health check:
```bash
curl http://localhost:8080/ping
# Response: {"message":"pong"}
```

## Build Binary

```bash
go build -o bin/api ./cmd/api/main.go
./bin/api
```

---

## Struktur Folder

```
backend/
  cmd/api/main.go           # Entry point
  internal/
    domain/                 # Entity & interface (tidak ada dependensi eksternal)
    usecase/                # Business logic
    repository/             # Query SQL via pgx
    delivery/http/
      handler/              # Gin handler
      middleware/           # JWT & role middleware
      router/               # Registrasi route
    infrastructure/
      database/             # Koneksi pgxpool
      jwt/                  # Generate & validasi token
  pkg/
    response/               # Format JSON response
  migrations/               # File SQL migrasi (jalankan berurutan)
```

---

## Role & Akses

| Role | Kemampuan |
|---|---|
| `manager` | Lihat semua booking, assign teknisi, dashboard statistik |
| `teknisi` | Claim job, update status, buat laporan |
| `client` | Buat booking, lihat booking milik perusahaannya |
| `sales` | Sama seperti client |

---

## API Endpoint Utama

| Method | Path | Deskripsi |
|---|---|---|
| POST | `/api/v1/auth/login` | Login, dapat JWT token |
| GET | `/api/v1/auth/me` | Profil user login |
| POST | `/api/v1/bookings` | Buat booking baru |
| GET | `/api/v1/bookings` | Daftar booking (filter per role) |
| POST | `/api/v1/bookings/:id/claim` | Teknisi ambil job |
| PATCH | `/api/v1/bookings/:id/status` | Update status job |
| GET | `/api/v1/equipment` | Daftar equipment (filter per perusahaan) |
| POST | `/api/v1/equipment` | Tambah equipment baru |
| GET | `/api/v1/dashboard/summary` | Statistik (manager only) |
