-- ============================================================
-- 007_create_notifications.sql
-- Tabel notifications — riwayat push notification FCM
-- type: job_open | job_claimed | status_changed | job_done | emergency_alert
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    booking_id  UUID REFERENCES bookings(id) ON DELETE SET NULL,
    type        VARCHAR(30) NOT NULL CHECK (type IN (
                    'job_open', 'job_claimed', 'status_changed',
                    'job_done', 'emergency_alert'
                )),
    title       VARCHAR(255) NOT NULL,
    body        TEXT NOT NULL,
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    payload     JSONB DEFAULT '{}'::JSONB,
    read_at     TIMESTAMP WITH TIME ZONE,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
