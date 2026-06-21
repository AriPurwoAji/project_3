ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS done_equipment_ids UUID[] DEFAULT ARRAY[]::UUID[];
