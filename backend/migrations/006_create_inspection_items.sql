-- ============================================================
-- 006_create_inspection_items.sql
-- Tabel inspection_items — item yang diinspeksi per laporan
-- item_type  : hose | cylinder | pump
-- condition  : good | wear | cracked | leaking | critical
-- recommendation: no_action | monitor | schedule_replace | urgent_replace
--
-- Struktur JSONB specifications per item_type:
--
-- HOSE:
-- {
--   "length_m": 2.5,
--   "diameter_inch": "1",
--   "pressure_bar": 200,
--   "material": "rubber",
--   "qty": 1,
--   "fitting_end1": { "standard": "ORFS", "angle": "straight", "gender": "male" },
--   "fitting_end2": { "standard": "BSP",  "angle": "90",       "gender": "female" }
-- }
--
-- CYLINDER:
-- {
--   "bore_mm": 80,
--   "stroke_mm": 500,
--   "pressure_bar": 200,
--   "rod_condition": "good",
--   "seal_condition": "wear"
-- }
--
-- PUMP:
-- {
--   "pump_type": "gear",
--   "flow_lpm": 150,
--   "pressure_bar": 250,
--   "noise_level": "normal",
--   "temperature_c": 45
-- }
--
-- Fitting standards: ORFS | BSP | NPT | JIC | Metric | SAE_F61 | SAE_F62
-- Fitting angles   : straight | 45 | 90 | 90_long
-- Fitting gender   : male | female
-- ============================================================

CREATE TABLE IF NOT EXISTS inspection_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id       UUID NOT NULL REFERENCES hydraulic_reports(id) ON DELETE CASCADE,
    item_type       VARCHAR(20) NOT NULL CHECK (item_type IN ('hose', 'cylinder', 'pump')),
    item_code       VARCHAR(50),
    location_desc   TEXT,
    specifications  JSONB NOT NULL DEFAULT '{}'::JSONB,
    condition       VARCHAR(20) NOT NULL CHECK (condition IN (
                        'good', 'wear', 'cracked', 'leaking', 'critical'
                    )),
    recommendation  VARCHAR(30) NOT NULL CHECK (recommendation IN (
                        'no_action', 'monitor',
                        'schedule_replace', 'urgent_replace'
                    )),
    photo_url       VARCHAR(500),
    notes           TEXT,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
