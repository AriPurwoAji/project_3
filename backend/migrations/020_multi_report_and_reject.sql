-- ============================================================
-- 020_multi_report_and_reject.sql
-- Mendukung multi-laporan per booking (equipment) dan fitur reject
-- ============================================================

-- 1. Hapus UNIQUE constraint lama (satu laporan per booking)
ALTER TABLE hydraulic_reports DROP CONSTRAINT IF EXISTS hydraulic_reports_booking_id_key;

-- 2. Tambah kolom baru ke hydraulic_reports
ALTER TABLE hydraulic_reports
    ADD COLUMN IF NOT EXISTS equipment_id     UUID REFERENCES hydraulic_equipment(id),
    ADD COLUMN IF NOT EXISTS status           VARCHAR(20) DEFAULT 'submitted'
        CHECK (status IN ('submitted', 'rejected')),
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 3. Unique index per (booking, equipment) — NULL equipment_id dikecualikan
--    agar booking single-equipment tetap bisa pakai equipment_id = NULL
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_booking_equipment
    ON hydraulic_reports(booking_id, equipment_id)
    WHERE equipment_id IS NOT NULL;

-- 4. Tambah status needs_revision ke tabel bookings
--    Hapus constraint lama dulu (nama otomatis dari PostgreSQL)
DO $$
DECLARE cname TEXT;
BEGIN
    SELECT conname INTO cname FROM pg_constraint
    WHERE conrelid = 'bookings'::regclass AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%status%'
    LIMIT 1;
    IF cname IS NOT NULL THEN
        EXECUTE 'ALTER TABLE bookings DROP CONSTRAINT ' || quote_ident(cname);
    END IF;
END $$;

ALTER TABLE bookings ADD CONSTRAINT bookings_status_check
    CHECK (status IN (
        'open', 'in_progress', 'on_the_way', 'on_site',
        'waiting_confirmation', 'needs_revision', 'done', 'cancelled'
    ));
