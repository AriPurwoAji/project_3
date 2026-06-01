-- Tambah kolom koordinat GPS ke tabel bookings
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
