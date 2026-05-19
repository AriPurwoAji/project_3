package repository

import (
	"context"
	"encoding/json"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/jackc/pgx/v5/pgxpool"
)

type notificationRepository struct {
	db *pgxpool.Pool
}

func NewNotificationRepository(db *pgxpool.Pool) domain.NotificationRepository {
	return &notificationRepository{db: db}
}

func (r *notificationRepository) Create(n *domain.Notification) error {
	payloadJSON, _ := json.Marshal(n.Payload)
	query := `
		INSERT INTO notifications (user_id, booking_id, type, title, body, payload)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at
	`
	return r.db.QueryRow(context.Background(), query,
		n.UserID, n.BookingID, n.Type, n.Title, n.Body, payloadJSON,
	).Scan(&n.ID, &n.CreatedAt)
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