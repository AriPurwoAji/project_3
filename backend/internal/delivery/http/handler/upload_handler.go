package handler

import (
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/AriPurwoAji/project_3/backend/internal/infrastructure/storage"
	"github.com/gin-gonic/gin"
)

type UploadHandler struct {
	storage *storage.SupabaseStorage
}

func NewUploadHandler(s *storage.SupabaseStorage) *UploadHandler {
	return &UploadHandler{storage: s}
}

var allowedExts = map[string]string{
	".jpg":  "image/jpeg",
	".jpeg": "image/jpeg",
	".png":  "image/png",
}

const maxFileSize = 5 * 1024 * 1024 // 5 MB

func (h *UploadHandler) UploadFile(c *gin.Context) {
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "File tidak ditemukan"})
		return
	}
	defer file.Close()

	ext := strings.ToLower(filepath.Ext(header.Filename))
	contentType, ok := allowedExts[ext]
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Hanya file JPG dan PNG yang diizinkan",
		})
		return
	}

	if header.Size > maxFileSize {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Ukuran file maksimal 5MB",
		})
		return
	}

	fileBytes, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal membaca file",
		})
		return
	}

	url, err := h.storage.Upload(fileBytes, header.Filename, contentType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": fmt.Sprintf("Gagal upload foto: %v", err),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Upload berhasil",
		"data":    gin.H{"url": url},
	})
}
