package router

import (
	"github.com/AriPurwoAji/project_3/backend/internal/delivery/http/handler"
	"github.com/AriPurwoAji/project_3/backend/internal/delivery/http/middleware"
	"github.com/gin-gonic/gin"
)

func Setup(
	r *gin.Engine,
	authHandler *handler.AuthHandler,
) {
	api := r.Group("/api/v1")

	// Auth routes
	auth := api.Group("/auth")
	{
		auth.POST("/login", authHandler.Login)
		auth.GET("/me", middleware.AuthMiddleware(), authHandler.GetProfile)
	}
}