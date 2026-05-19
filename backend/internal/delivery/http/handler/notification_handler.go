package handler

import (
	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/AriPurwoAji/project_3/backend/pkg/response"
	"github.com/gin-gonic/gin"
)

type NotificationHandler struct {
	uc domain.NotificationUsecase
}

func NewNotificationHandler(uc domain.NotificationUsecase) *NotificationHandler {
	return &NotificationHandler{uc: uc}
}

func (h *NotificationHandler) GetMyNotifications(c *gin.Context) {
	userID := c.GetString("user_id")
	notifs, err := h.uc.GetMyNotifications(userID)
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", notifs)
}

func (h *NotificationHandler) MarkAsRead(c *gin.Context) {
	userID := c.GetString("user_id")
	notifID := c.Param("id")
	if err := h.uc.MarkAsRead(notifID, userID); err != nil {
		response.Error(c, 400, err.Error())
		return
	}
	response.Success(c, 200, "Notifikasi ditandai sudah dibaca", nil)
}

func (h *NotificationHandler) MarkAllAsRead(c *gin.Context) {
	userID := c.GetString("user_id")
	if err := h.uc.MarkAllAsRead(userID); err != nil {
		response.Error(c, 400, err.Error())
		return
	}
	response.Success(c, 200, "Semua notifikasi ditandai sudah dibaca", nil)
}

func (h *NotificationHandler) CountUnread(c *gin.Context) {
	userID := c.GetString("user_id")
	count, err := h.uc.CountUnread(userID)
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", gin.H{"unread_count": count})
}