package router

import (
	"github.com/AriPurwoAji/project_3/backend/internal/delivery/http/handler"
	"github.com/AriPurwoAji/project_3/backend/internal/delivery/http/middleware"
	"github.com/gin-gonic/gin"
)

func Setup(
	r *gin.Engine,
	authHandler      *handler.AuthHandler,
	bookingHandler   *handler.BookingHandler,
	reportHandler    *handler.ReportHandler,
	notifHandler     *handler.NotificationHandler,
	dashboardHandler *handler.DashboardHandler,
	equipmentHandler *handler.EquipmentHandler,
	uploadHandler    *handler.UploadHandler,
) {
	api := r.Group("/api/v1")

	// Public
	auth := api.Group("/auth")
	{
		auth.POST("/login", authHandler.Login)
		auth.GET("/me", middleware.AuthMiddleware(), authHandler.GetProfile)
	}

	// Protected
	protected := api.Group("")
	protected.Use(middleware.AuthMiddleware())
	{
		// Bookings
		booking := protected.Group("/bookings")
		{
			booking.POST("", middleware.RoleMiddleware("client", "sales", "manager"), bookingHandler.CreateBooking)
			booking.GET("", bookingHandler.GetAllBookings)
			booking.GET("/:id", bookingHandler.GetBookingByID)
			booking.POST("/:id/claim", middleware.RoleMiddleware("teknisi"), bookingHandler.ClaimBooking)
			booking.PATCH("/:id/status", middleware.RoleMiddleware("teknisi"), bookingHandler.UpdateStatus)
			booking.POST("/:id/assign", middleware.RoleMiddleware("manager"), bookingHandler.AssignTechnician)
		}

		// Job board & my jobs
		protected.GET("/job-board", middleware.RoleMiddleware("teknisi"), bookingHandler.GetOpenBookings)
		protected.GET("/my-jobs", middleware.RoleMiddleware("teknisi"), bookingHandler.GetMyJobs)

		// Reports
		reports := protected.Group("/reports")
		{
			reports.POST("/:booking_id", middleware.RoleMiddleware("teknisi"), reportHandler.CreateReport)
			reports.GET("/:booking_id", reportHandler.GetReportByBookingID)
			reports.GET("/my-reports", middleware.RoleMiddleware("teknisi"), reportHandler.GetMyReports)
		}

		// Equipment
		equipment := protected.Group("/equipment")
		{
			equipment.GET("", equipmentHandler.GetAll)
			equipment.POST("", middleware.RoleMiddleware("client", "sales", "manager"), equipmentHandler.Create)
		}

		// Notifications
		notif := protected.Group("/notifications")
		{
			notif.GET("", notifHandler.GetMyNotifications)
			notif.GET("/unread-count", notifHandler.CountUnread)
			notif.PATCH("/:id/read", notifHandler.MarkAsRead)
			notif.PATCH("/read-all", notifHandler.MarkAllAsRead)
		}

		// Dashboard — manager only
		dashboard := protected.Group("/dashboard")
		dashboard.Use(middleware.RoleMiddleware("manager"))
		{
			dashboard.GET("/summary", dashboardHandler.GetSummary)
			dashboard.GET("/technician-performance", dashboardHandler.GetTechnicianPerformance)
			dashboard.GET("/service-trend", dashboardHandler.GetServiceTypeTrend)
		}

		// Upload foto
		protected.POST("/upload", uploadHandler.UploadFile)
	}
}