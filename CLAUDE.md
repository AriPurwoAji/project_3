# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**HydroServ** — a hydraulic technician service booking app. Clients/sales create service bookings, technicians claim and fulfill jobs, and managers oversee operations via a dashboard. The system enforces role-based access at both the API and UI level.

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
  migrations/               # Ordered SQL files (001–009)
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
| `manager` | `/dashboard` | Full read, assign technician, dashboard stats |
| `teknisi` | `/job-board` | Claim open bookings, update status, create/view reports |
| `client` | `/bookings` | Create bookings, view own bookings |
| `sales` | `/bookings` | Create bookings, view own bookings |

The Go router enforces roles via `middleware.RoleMiddleware(...)` per route group. The Flutter router reads `user_role` from `FlutterSecureStorage` and redirects accordingly.

---

## Key Domain Concepts

**Booking status flow**: `open → in_progress → on_the_way → on_site → done` (or `cancelled`)

- A teknisi *claims* an open booking (sets `technician_id`, status → `in_progress`).
- A manager can also *assign* a technician directly.
- Status updates are restricted to the assigned technician.

**HydraulicReport** is created once per booking (after job completion). It includes: pressure readings, oil condition, leak details, parts replaced, photos (before/after/damage), and for `inspeksi` service type, a list of `InspectionItem` records (hose / cylinder / pump with specifications as JSONB).

**Fitting specs** (hose inspections) use controlled vocabularies: standard (ORFS/BSP/NPT/JIC/Metric/SAE_F61/SAE_F62), angle (straight/45/90/90_long), gender (male/female).

---

## API Base URL

- Backend listens on `APP_PORT` (default `8080`).
- All routes are prefixed `/api/v1`.
- From Android emulator, use `10.0.2.2` to reach the host machine's localhost.
- Health check: `GET /ping` → `{ "message": "pong" }`.
