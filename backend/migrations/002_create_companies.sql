-- ============================================================
-- 002_create_companies.sql
-- Tabel companies untuk data perusahaan klien
-- ============================================================

CREATE TABLE IF NOT EXISTS companies (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(255) NOT NULL,
    industry    VARCHAR(100),
    address     TEXT,
    city        VARCHAR(100),
    pic_name    VARCHAR(255),
    pic_phone   VARCHAR(20),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at  TIMESTAMP WITH TIME ZONE
);

CREATE TRIGGER companies_updated_at
    BEFORE UPDATE ON companies
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Seed: data klien aktual
INSERT INTO companies (name, industry, city, pic_name) VALUES
    ('PT Kereta Api Indonesia DAOP 5',    'Transportasi',         'Purwokerto', 'Hendra Pratama'),
    ('PT Elnusa Tbk',                     'Minyak & Gas',         'Jakarta',    'Rina Sari'),
    ('PT Indonesia Power UP Suralaya',    'Pembangkit Listrik',   'Cilegon',    'Bambang Wijaya'),
    ('PT Bumimulia Indah Lestari',        'Manufaktur',           'Bekasi',     'Dewi Anggraini'),
    ('PT Petrodril Manufaktur Indonesia', 'Minyak & Gas',         'Bekasi',     'Rudi Hartono')
ON CONFLICT DO NOTHING;
