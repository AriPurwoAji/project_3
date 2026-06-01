package usecase

import "github.com/AriPurwoAji/project_3/backend/internal/domain"

type notificationUsecase struct {
	repo domain.NotificationRepository
}

func NewNotificationUsecase(repo domain.NotificationRepository) domain.NotificationUsecase {
	return &notificationUsecase{repo: repo}
}

func (u *notificationUsecase) GetMyNotifications(userID string) ([]domain.Notification, error) {
	return u.repo.FindByUserID(userID)
}

func (u *notificationUsecase) MarkAsRead(notifID, userID string) error {
	return u.repo.MarkAsRead(notifID, userID)
}

func (u *notificationUsecase) MarkAllAsRead(userID string) error {
	return u.repo.MarkAllAsRead(userID)
}

func (u *notificationUsecase) CountUnread(userID string) (int, error) {
	return u.repo.CountUnread(userID)
}

func (u *notificationUsecase) Delete(notifID, userID string) error {
	return u.repo.Delete(notifID, userID)
}

func (u *notificationUsecase) DeleteAll(userID string) error {
	return u.repo.DeleteAll(userID)
}
