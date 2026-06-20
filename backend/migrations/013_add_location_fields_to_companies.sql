-- 013_add_location_fields_to_companies.sql
-- Tambah kolom lokasi perusahaan yang lebih terstruktur (untuk Jabodetabek check)

ALTER TABLE companies
    ADD COLUMN IF NOT EXISTS province   VARCHAR(100),
    ADD COLUMN IF NOT EXISTS kecamatan  VARCHAR(100),
    ADD COLUMN IF NOT EXISTS kelurahan  VARCHAR(100);
