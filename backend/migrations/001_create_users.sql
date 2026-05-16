-- ============================================================
-- 001_create_users.sql
-- Tabel users untuk semua aktor sistem
-- Role: client | sales | teknisi | manager
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(255) NOT NULL,
    phone           VARCHAR(20),
    role            VARCHAR(20) NOT NULL CHECK (role IN ('client', 'sales', 'teknisi', 'manager')),
    fcm_token       VARCHAR(500),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMP WITH TIME ZONE
);

-- Auto update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Seed: default manager account
INSERT INTO users (email, password_hash, full_name, role)
VALUES (
    'manager@hydraulic.com',
    '$2a$12$placeholder_hash_change_this',
    'Manager Default',
    'manager'
) ON CONFLICT DO NOTHING;
