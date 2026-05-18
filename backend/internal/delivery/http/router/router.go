package router

import (
	"github.com/AriPurwoAji/project_3/backend/internal/delivery/http/handler"
	"github.com/AriPurwoAji/project_3/backend/internal/delivery/http/middleware"
	"github.com/gin-gonic/gin"
)

func Setup(
	r *gin.Engine,
	authHandler *handler.AuthHandler,
	bookingHandler *handler.BookingHandler,
) {
	api := r.Group("/api/v1")

	// Auth routes — public
	auth := api.Group("/auth")
	{
		auth.POST("/login", authHandler.Login)
		auth.GET("/me", middleware.AuthMiddleware(), authHandler.GetProfile)
	}

	// Protected routes
	protected := api.Group("")
	protected.Use(middleware.AuthMiddleware())
	{
		// Booking — Client & Sales bisa buat
		booking := protected.Group("/bookings")
		{
			booking.POST("", middleware.RoleMiddleware("client", "sales", "manager"), bookingHandler.CreateBooking)
			booking.GET("", bookingHandler.GetAllBookings)
			booking.GET("/:id", bookingHandler.GetBookingByID)
			booking.POST("/:id/claim", middleware.RoleMiddleware("teknisi"), bookingHandler.ClaimBooking)
			booking.PATCH("/:id/status", middleware.RoleMiddleware("teknisi"), bookingHandler.UpdateStatus)
			booking.POST("/:id/assign", middleware.RoleMiddleware("manager"), bookingHandler.AssignTechnician)
		}

		// Job board — teknisi
		protected.GET("/job-board", middleware.RoleMiddleware("teknisi"), bookingHandler.GetOpenBookings)
		protected.GET("/my-jobs", middleware.RoleMiddleware("teknisi"), bookingHandler.GetMyJobs)
	}
}