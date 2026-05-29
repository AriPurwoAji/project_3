package handler

import (
	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/AriPurwoAji/project_3/backend/pkg/response"
	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	authUsecase domain.AuthUsecase
}

func NewAuthHandler(authUsecase domain.AuthUsecase) *AuthHandler {
	return &AuthHandler{authUsecase: authUsecase}
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req domain.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, 400, "Request tidak valid: "+err.Error())
		return
	}

	result, err := h.authUsecase.Login(req)
	if err != nil {
		response.Error(c, 401, err.Error())
		return
	}

	response.Success(c, 200, "Login berhasil", result)
}

func (h *AuthHandler) GetProfile(c *gin.Context) {
	userID := c.GetString("user_id")
	user, err := h.authUsecase.GetProfile(userID)
	if err != nil {
		response.Error(c, 404, "User tidak ditemukan")
		return
	}
	response.Success(c, 200, "Success", user)
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req domain.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, 400, "Request tidak valid: "+err.Error())
		return
	}

	user, err := h.authUsecase.Register(req)
	if err != nil {
		response.Error(c, 400, err.Error())
		return
	}
	response.Success(c, 201, "Registrasi berhasil", user)
}

func (h *AuthHandler) GetTechnicians(c *gin.Context) {
	users, err := h.authUsecase.GetTechnicians()
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", users)
}