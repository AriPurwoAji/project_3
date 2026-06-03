package main

import (
	"log"
	"os"

	"github.com/AriPurwoAji/project_3/backend/internal/delivery/http/handler"
	"github.com/AriPurwoAji/project_3/backend/internal/delivery/http/router"
	"github.com/AriPurwoAji/project_3/backend/internal/infrastructure/database"
	"github.com/AriPurwoAji/project_3/backend/internal/infrastructure/pdf"
	"github.com/AriPurwoAji/project_3/backend/internal/infrastructure/storage"
	"github.com/AriPurwoAji/project_3/backend/internal/repository"
	"github.com/AriPurwoAji/project_3/backend/internal/usecase"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	if err := godotenv.Load(".env"); err != nil {
		log.Println("No .env file found, using system env")
	}

	db, err := database.Connect()
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer database.Close(db)

	// Repositories
	userRepo      := repository.NewUserRepository(db)
	bookingRepo   := repository.NewBookingRepository(db)
	reportRepo    := repository.NewReportRepository(db)
	notifRepo     := repository.NewNotificationRepository(db)
	dashboardRepo := repository.NewDashboardRepository(db)
	equipmentRepo := repository.NewEquipmentRepository(db)

	// Infrastructure
	supabaseStorage := storage.NewSupabaseStorage()
	pdfGenerator    := pdf.NewReportGenerator()

	// Usecases
	authUsecase      := usecase.NewAuthUsecase(userRepo)
	bookingUsecase   := usecase.NewBookingUsecase(bookingRepo, notifRepo)
	reportUsecase    := usecase.NewReportUsecase(reportRepo, bookingRepo, pdfGenerator, supabaseStorage, notifRepo)
	notifUsecase     := usecase.NewNotificationUsecase(notifRepo)
	dashboardUsecase := usecase.NewDashboardUsecase(dashboardRepo)
	equipmentUsecase := usecase.NewEquipmentUsecase(equipmentRepo)

	// Handlers
	authHandler      := handler.NewAuthHandler(authUsecase)
	bookingHandler   := handler.NewBookingHandler(bookingUsecase)
	reportHandler    := handler.NewReportHandler(reportUsecase)
	notifHandler     := handler.NewNotificationHandler(notifUsecase)
	dashboardHandler := handler.NewDashboardHandler(dashboardUsecase)
	equipmentHandler := handler.NewEquipmentHandler(equipmentUsecase)
	uploadHandler    := handler.NewUploadHandler(supabaseStorage)

	// Router
	r := gin.Default()
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{"message": "pong"})
	})

	router.Setup(
		r,
		authHandler,
		bookingHandler,
		reportHandler,
		notifHandler,
		dashboardHandler,
		equipmentHandler,
		uploadHandler,
	)

	// Railway menyuntikkan env PORT secara otomatis
	port := os.Getenv("APP_PORT")
	if port == "" {
		port = os.Getenv("PORT")
	}
	if port == "" {
		port = "8080"
	}

	log.Printf("Server running on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
