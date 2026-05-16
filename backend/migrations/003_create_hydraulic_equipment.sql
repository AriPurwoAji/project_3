-- ============================================================
-- 003_create_hydraulic_equipment.sql
-- Tabel hydraulic_equipment untuk peralatan milik klien
-- Type: pump | cylinder | hose | valve | accumulator | other
-- ============================================================

CREATE TABLE IF NOT EXISTS hydraulic_equipment (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          UUID NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
    name                VARCHAR(255) NOT NULL,
    type                VARCHAR(50) NOT NULL CHECK (type IN (
                            'pump', 'cylinder', 'hose',
                            'valve', 'accumulator', 'power_pack', 'other'
                        )),
    brand               VARCHAR(100),
    model               VARCHAR(100),
    serial_number       VARCHAR(100) UNIQUE,
    rated_pressure_bar  INTEGER,
    location_detail     TEXT,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMP WITH TIME ZONE
);

CREATE TRIGGER hydraulic_equipment_updated_at
    BEFORE UPDATE ON hydraulic_equipment
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();
