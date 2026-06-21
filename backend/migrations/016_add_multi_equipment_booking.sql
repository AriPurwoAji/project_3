ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS equipment_id_2   UUID REFERENCES hydraulic_equipment(id),
    ADD COLUMN IF NOT EXISTS work_equipment_id UUID REFERENCES hydraulic_equipment(id);
