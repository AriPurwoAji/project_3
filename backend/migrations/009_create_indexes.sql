-- ============================================================
-- 009_create_indexes.sql
-- Index untuk optimasi query yang sering dipakai
-- ============================================================

-- users
CREATE INDEX IF NOT EXISTS idx_users_email       ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_role         ON users(role) WHERE deleted_at IS NULL AND is_active = TRUE;

-- companies
CREATE INDEX IF NOT EXISTS idx_companies_active   ON companies(is_active) WHERE deleted_at IS NULL;

-- hydraulic_equipment
CREATE INDEX IF NOT EXISTS idx_equipment_company  ON hydraulic_equipment(company_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_equipment_type     ON hydraulic_equipment(type) WHERE deleted_at IS NULL;

-- bookings — paling sering di-query
CREATE INDEX IF NOT EXISTS idx_bookings_status        ON bookings(status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_company       ON bookings(company_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_technician    ON bookings(technician_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_urgency       ON bookings(urgency_level) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_open          ON bookings(status, created_at DESC)
                                                        WHERE status = 'open' AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_bookings_created_at    ON bookings(created_at DESC) WHERE deleted_at IS NULL;

-- hydraulic_reports
CREATE INDEX IF NOT EXISTS idx_reports_booking        ON hydraulic_reports(booking_id);
CREATE INDEX IF NOT EXISTS idx_reports_technician     ON hydraulic_reports(technician_id);

-- inspection_items
CREATE INDEX IF NOT EXISTS idx_inspection_report      ON inspection_items(report_id);
CREATE INDEX IF NOT EXISTS idx_inspection_type        ON inspection_items(item_type);

-- notifications
CREATE INDEX IF NOT EXISTS idx_notif_user             ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_unread           ON notifications(user_id, is_read)
                                                        WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notif_booking          ON notifications(booking_id);

-- booking_status_logs
CREATE INDEX IF NOT EXISTS idx_status_logs_booking    ON booking_status_logs(booking_id, created_at ASC);
