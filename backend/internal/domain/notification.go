package domain

import "time"

type Notification struct {
	ID        string                 `json:"id"`
	UserID    string                 `json:"user_id"`
	BookingID *string                `json:"booking_id,omitempty"`
	Type      string                 `json:"type"`
	Title     string                 `json:"title"`
	Body      string                 `json:"body"`
	IsRead    bool                   `json:"is_read"`
	Payload   map[string]interface{} `json:"payload,omitempty"`
	ReadAt    *time.Time             `json:"read_at,omitempty"`
	CreatedAt time.Time              `json:"created_at"`
}

type NotificationRepository interface {
	Create(notif *Notification) error
	BroadcastToRole(role string, bookingID *string, notifType, title, body string) error
	FindByUserID(userID string) ([]Notification, error)
	MarkAsRead(notifID, userID string) error
	MarkAllAsRead(userID string) error
	CountUnread(userID string) (int, error)
	Delete(notifID, userID string) error
	DeleteAll(userID string) error
}

type NotificationUsecase interface {
	GetMyNotifications(userID string) ([]Notification, error)
	MarkAsRead(notifID, userID string) error
	MarkAllAsRead(userID string) error
	CountUnread(userID string) (int, error)
	Delete(notifID, userID string) error
	DeleteAll(userID string) error
}