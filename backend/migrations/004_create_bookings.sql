-- ============================================================
-- 004_create_bookings.sql
-- Tabel bookings — tabel inti sistem
-- service_type : repair | inspeksi | maintenance | oil_service
-- urgency_level: emergency | standard
-- status       : open | in_progress | on_the_way | on_site | done | cancelled
-- ============================================================

CREATE TABLE IF NOT EXISTS bookings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id      UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    created_by      UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    technician_id   UUID REFERENCES users(id) ON DELETE RESTRICT,
    equipment_id    UUID REFERENCES hydraulic_equipment(id) ON DELETE RESTRICT,
    service_type    VARCHAR(20) NOT NULL CHECK (service_type IN (
                        'repair', 'inspeksi', 'maintenance', 'oil_service'
                    )),
    urgency_level   VARCHAR(20) NOT NULL DEFAULT 'standard' CHECK (urgency_level IN (
                        'emergency', 'standard'
                    )),
    status          VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN (
                        'open', 'in_progress', 'on_the_way',
                        'on_site', 'done', 'cancelled'
                    )),
    description     TEXT,
    site_address    TEXT,
    site_city       VARCHAR(100),
    photo_urls      JSONB DEFAULT '[]'::JSONB,
    scheduled_at    TIMESTAMP WITH TIME ZONE,
    claimed_at      TIMESTAMP WITH TIME ZONE,
    started_at      TIMESTAMP WITH TIME ZONE,
    completed_at    TIMESTAMP WITH TIME ZONE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMP WITH TIME ZONE
);

CREATE TRIGGER bookings_updated_at
    BEFORE UPDATE ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();
