-- ============================================================
-- 018_create_booking_items.sql
-- Sub-item / checklist tugas dalam satu booking inspeksi/maintenance
-- ============================================================

CREATE TABLE IF NOT EXISTS booking_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id  UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    is_done     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_booking_items_booking_id ON booking_items(booking_id);
