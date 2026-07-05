# HydroServ — Mobile (Flutter)

Aplikasi Android untuk sistem booking teknisi hydraulic. Dibangun dengan Flutter, berkomunikasi dengan backend Go via REST API.

---

## Prasyarat

- [Flutter SDK](https://docs.flutter.dev/get-started/install) versi 3.10 atau lebih baru
- Android Studio atau VS Code dengan plugin Flutter
- Perangkat Android atau emulator (Android 6.0+)
- Backend HydroServ sudah berjalan (lihat `backend/README.md`)

Cek versi Flutter:
```bash
flutter --version
flutter doctor
```

---

## Setup Pertama Kali

### 1. Clone repository

```bash
git clone https://github.com/AriPurwoAji/project_3.git
cd project_3/mobile
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Buat file environment

Buat file `.env` di dalam folder `mobile/`:

```env
API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Untuk deployment ke Render, cukup ganti nilainya menjadi URL backend Render Anda, misalnya:

```env
API_BASE_URL=https://your-render-backend-url/api/v1
```

Sesuaikan `API_BASE_URL` dengan kondisi berikut:

| Kondisi | Nilai API_BASE_URL |
|---|---|
| Emulator Android (default) | `http://10.0.2.2:8080/api/v1` |
| HP fisik (WiFi/hotspot sama) | `http://<IP_laptop>:8080/api/v1` |
| Backend di Render | `https://your-render-backend-url/api/v1` |

Cara cari IP laptop di Windows:
```powershell
ipconfig
# Lihat "IPv4 Address" pada adapter WiFi yang aktif
```

---

## Menjalankan Aplikasi

### Di Emulator

```bash
# Pastikan emulator sudah berjalan di Android Studio
flutter run
```

### Di HP Fisik

1. Aktifkan **Developer Options** dan **USB Debugging** di HP
2. Sambungkan HP ke laptop via USB
3. Jalankan:

```bash
flutter devices          # cek device terdeteksi
flutter run              # otomatis install ke HP
```

### Hotspot (HP sebagai hotspot, laptop konek ke HP)

1. Aktifkan hotspot di HP
2. Sambungkan laptop ke hotspot HP
3. Cari IP laptop (`ipconfig`) — biasanya `192.168.x.x` atau `10.x.x.x`
4. Isi `.env` dengan IP tersebut:
   ```env
   API_BASE_URL=http://192.168.43.100:8080/api/v1
   ```
5. Jalankan `flutter run`

---

## Build APK

```bash
# APK debug (untuk testing)
flutter build apk --debug

# APK release (untuk distribusi)
flutter build apk --release
```

File APK tersimpan di:
```
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
```

Install APK langsung ke HP yang tersambung:
```bash
flutter install
```

---

## Akun Default untuk Testing

| Email | Password | Role |
|---|---|---|
| `manager@hydraulic.com` | `Admin123!` | Manager |
| `client.ptkai@hydraulic.com` | `Client123!` | Client (PT KAI) |
| `client.pln@hydraulic.com` | `Client123!` | Client (PT PLN) |

> Akun di atas hanya tersedia jika sudah diinsert via Supabase SQL Editor. Lihat `backend/README.md` untuk caranya.

---

## Struktur Folder

```
mobile/lib/
  main.dart                       # Entry point, load .env, setup router
  core/
    constants/app_constants.dart  # API URL, storage keys, roles, enums
    network/api_client.dart       # Singleton Dio + Bearer token interceptor
    router/app_router.dart        # GoRouter + auth redirect per role
    theme/app_theme.dart          # Warna, font, button style
  features/
    auth/          # Login page, profile page
    booking/       # Daftar booking, buat booking baru
    job_board/     # Job board & my jobs (teknisi)
    dashboard/     # Statistik & performa (manager)
    notification/  # Notifikasi in-app
    report/        # Laporan hydraulic (teknisi)
```

---

## Alur Penggunaan

```
Install APK → Login dengan akun sesuai role
  ├── Manager   → Dashboard statistik, lihat semua booking
  ├── Teknisi   → Job Board, ambil job, update status
  └── Client    → Buat booking, lihat status booking milik PT sendiri
```

---

## Troubleshooting

**Tidak bisa konek ke backend:**
- Pastikan backend sudah berjalan (`go run ./cmd/api/main.go` dari folder `backend/`)
- Pastikan IP di `.env` sudah benar sesuai kondisi jaringan
- Pastikan HP dan laptop terhubung ke jaringan yang sama
- Coba akses `http://<IP_laptop>:8080/ping` dari browser HP — harusnya muncul `{"message":"pong"}`

**Login error "terjadi kesalahan":**
- Cek backend sudah jalan dan bisa diakses dari HP
- Pastikan file `.env` ada di folder `mobile/` dan `API_BASE_URL` sudah benar

**Layar putih / loading terus:**
- Jalankan `flutter clean && flutter pub get`, lalu `flutter run` ulang
