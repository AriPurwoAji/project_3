-- Tambah kolom description ke hydraulic_equipment
-- Field wajib baru: nama, deskripsi, lokasi/patokan (field lama tetap di DB)
ALTER TABLE hydraulic_equipment
    ADD COLUMN IF NOT EXISTS description TEXT;
