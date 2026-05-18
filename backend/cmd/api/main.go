package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/AriPurwoAji/project_3/backend/internal/infrastructure/database"
)

func main() {
	// Load .env
	if err := godotenv.Load(`C:\androidlanjutan\project_3\backend\.env`); err != nil {
    log.Fatal("Error loading .env file:", err)
}

	// Connect database
	db, err := database.Connect()
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer database.Close(db)

	// Setup gin
	r := gin.Default()

	// Health check
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message": "pong",
			"status":  "Hydraulic Service API is running",
		})
	})

	// Start server
	port := os.Getenv("APP_PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server running on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}