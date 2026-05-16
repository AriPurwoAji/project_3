-- ============================================================
-- 008_create_booking_status_logs.sql
-- Tabel booking_status_logs — audit trail perubahan status booking
-- Immutable: tidak ada updated_at, data tidak boleh diubah
-- ============================================================

CREATE TABLE IF NOT EXISTS booking_status_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id  UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    changed_by  UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    from_status VARCHAR(20),
    to_status   VARCHAR(20) NOT NULL,
    note        TEXT,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
