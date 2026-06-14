package repository

import (
	"context"
	"encoding/json"
	"log"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/AriPurwoAji/project_3/backend/internal/infrastructure/fcm"
	"github.com/jackc/pgx/v5/pgxpool"
)

type notificationRepository struct {
	db  *pgxpool.Pool
	fcm *fcm.Sender
}

func NewNotificationRepository(db *pgxpool.Pool, fcmSender *fcm.Sender) domain.NotificationRepository {
	return &notificationRepository{db: db, fcm: fcmSender}
}

// lookupFCMToken mengambil fcm_token user dari tabel users
func (r *notificationRepository) lookupFCMToken(userID string) string {
	var token *string
	r.db.QueryRow(context.Background(),
		`SELECT fcm_token FROM users WHERE id = $1 AND fcm_token IS NOT NULL`,
		userID,
	).Scan(&token)
	if token == nil {
		return ""
	}
	return *token
}

// sendPush mengirim FCM push — best-effort, tidak gagalkan proses utama
func (r *notificationRepository) sendPush(token, title, body string, bookingID *string) {
	if !r.fcm.Enabled() || token == "" {
		return
	}
	data := map[string]string{}
	if bookingID != nil {
		data["booking_id"] = *bookingID
	}
	if err := r.fcm.Send(token, title, body, data); err != nil {
		log.Printf("[FCM] gagal kirim push ke %s: %v", token[:min(8, len(token))], err)
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func (r *notificationRepository) Create(n *domain.Notification) error {
	payloadJSON, _ := json.Marshal(n.Payload)
	query := `
		INSERT INTO notifications (user_id, booking_id, type, title, body, payload)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at
	`
	err := r.db.QueryRow(context.Background(), query,
		n.UserID, n.BookingID, n.Type, n.Title, n.Body, payloadJSON,
	).Scan(&n.ID, &n.CreatedAt)
	if err == nil {
		// Kirim FCM push best-effort
		go r.sendPush(r.lookupFCMToken(n.UserID), n.Title, n.Body, n.BookingID)
	}
	return err
}

func (r *notificationRepository) BroadcastToRole(role string, bookingID *string, notifType, title, body string) error {
	query := `
		INSERT INTO notifications (user_id, booking_id, type, title, body, payload)
		SELECT id, $1, $2, $3, $4, '{}'::JSONB
		FROM users
		WHERE role = $5 AND deleted_at IS NULL AND is_active = TRUE
	`
	_, err := r.db.Exec(context.Background(), query,
		bookingID, notifType, title, body, role,
	)
	if err == nil {
		// Kirim FCM push ke semua token yang terdaftar untuk role ini
		go func() {
			rows, e := r.db.Query(context.Background(),
				`SELECT fcm_token FROM users WHERE role = $1 AND fcm_token IS NOT NULL AND deleted_at IS NULL AND is_active = TRUE`,
				role,
			)
			if e != nil {
				return
			}
			defer rows.Close()
			for rows.Next() {
				var token string
				if rows.Scan(&token) == nil && token != "" {
					r.sendPush(token, title, body, bookingID)
				}
			}
		}()
	}
	return err
}

func (r *notificationRepository) FindByUserID(userID string) ([]domain.Notification, error) {
	query := `
		SELECT id, user_id, booking_id, type, title, body,
			   is_read, payload, read_at, created_at
		FROM notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT 50
	`
	rows, err := r.db.Query(context.Background(), query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifs []domain.Notification
	for rows.Next() {
		var n domain.Notification
		var payloadJSON []byte
		err := rows.Scan(
			&n.ID, &n.UserID, &n.BookingID, &n.Type,
			&n.Title, &n.Body, &n.IsRead,
			&payloadJSON, &n.ReadAt, &n.CreatedAt,
		)
		if err != nil {
			continue
		}
		if payloadJSON != nil {
			json.Unmarshal(payloadJSON, &n.Payload)
		}
		notifs = append(notifs, n)
	}
	if notifs == nil {
		notifs = []domain.Notification{}
	}
	return notifs, nil
}

func (r *notificationRepository) MarkAsRead(notifID, userID string) error {
	query := `
		UPDATE notifications 
		SET is_read = TRUE, read_at = NOW()
		WHERE id = $1 AND user_id = $2
	`
	_, err := r.db.Exec(context.Background(), query, notifID, userID)
	return err
}

func (r *notificationRepository) MarkAllAsRead(userID string) error {
	query := `
		UPDATE notifications 
		SET is_read = TRUE, read_at = NOW()
		WHERE user_id = $1 AND is_read = FALSE
	`
	_, err := r.db.Exec(context.Background(), query, userID)
	return err
}

func (r *notificationRepository) CountUnread(userID string) (int, error) {
	var count int
	query := `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE`
	err := r.db.QueryRow(context.Background(), query, userID).Scan(&count)
	return count, err
}

func (r *notificationRepository) Delete(notifID, userID string) error {
	_, err := r.db.Exec(context.Background(),
		`DELETE FROM notifications WHERE id = $1 AND user_id = $2`,
		notifID, userID,
	)
	return err
}

func (r *notificationRepository) DeleteAll(userID string) error {
	_, err := r.db.Exec(context.Background(),
		`DELETE FROM notifications WHERE user_id = $1`,
		userID,
	)
	return err
}