-- ============================================================
-- 005_create_hydraulic_reports.sql
-- Tabel hydraulic_reports — laporan hasil pekerjaan teknisi
-- oil_condition : good | contaminated | critical
-- oil_level     : low | normal | overfill
-- leak_severity : none | minor | moderate | severe
-- ============================================================

CREATE TABLE IF NOT EXISTS hydraulic_reports (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id          UUID NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE RESTRICT,
    technician_id       UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    -- Field untuk repair (nullable karena inspeksi tidak butuh ini)
    pressure_before_bar INTEGER,
    pressure_after_bar  INTEGER,
    oil_condition       VARCHAR(20) CHECK (oil_condition IN ('good', 'contaminated', 'critical')),
    oil_level           VARCHAR(20) CHECK (oil_level IN ('low', 'normal', 'overfill')),
    leak_location       TEXT,
    leak_severity       VARCHAR(20) CHECK (leak_severity IN ('none', 'minor', 'moderate', 'severe')),
    parts_replaced      JSONB DEFAULT '[]'::JSONB,

    -- Field umum semua jenis laporan
    photo_urls          JSONB DEFAULT '[]'::JSONB,
    pdf_url             VARCHAR(500),
    work_description    TEXT,
    recommendations     TEXT,

    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TRIGGER hydraulic_reports_updated_at
    BEFORE UPDATE ON hydraulic_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();
