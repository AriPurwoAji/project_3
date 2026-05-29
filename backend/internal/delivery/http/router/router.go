package router

import (
	"net/http"

	"github.com/AriPurwoAji/project_3/backend/internal/delivery/http/handler"
	"github.com/AriPurwoAji/project_3/backend/internal/delivery/http/middleware"
	"github.com/gin-gonic/gin"
)

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Authorization")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

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
	r.Use(corsMiddleware())

	api := r.Group("/api/v1")

	// Public
	auth := api.Group("/auth")
	{
		auth.POST("/register", authHandler.Register)
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
			booking.PATCH("/:id/cancel", middleware.RoleMiddleware("client", "sales", "manager"), bookingHandler.CancelBooking)
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
			equipment.PATCH("/:id", middleware.RoleMiddleware("client", "sales", "manager"), equipmentHandler.Update)
			equipment.DELETE("/:id", middleware.RoleMiddleware("client", "sales", "manager"), equipmentHandler.Delete)
		}

		// Notifications
		notif := protected.Group("/notifications")
		{
			notif.GET("", notifHandler.GetMyNotifications)
			notif.GET("/unread-count", notifHandler.CountUnread)
			notif.PATCH("/:id/read", notifHandler.MarkAsRead)
			notif.PATCH("/read-all", notifHandler.MarkAllAsRead)
		}

		// Auth — protected
		protected.PATCH("/auth/profile", authHandler.UpdateProfile)
		protected.POST("/auth/change-password", authHandler.ChangePassword)

		// Users
		users := protected.Group("/users")
		{
			users.GET("/teknisi", middleware.RoleMiddleware("manager"), authHandler.GetTechnicians)
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