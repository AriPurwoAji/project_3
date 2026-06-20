ALTER TABLE bookings
    ADD COLUMN IF NOT EXISTS reference_booking_id UUID REFERENCES bookings(id);
