package storage

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type SupabaseStorage struct {
	url    string
	key    string
	bucket string
	client *http.Client
}

func NewSupabaseStorage() *SupabaseStorage {
	return &SupabaseStorage{
		url:    os.Getenv("SUPABASE_URL"),
		key:    os.Getenv("SUPABASE_SERVICE_KEY"),
		bucket: os.Getenv("SUPABASE_STORAGE_BUCKET"),
		client: &http.Client{Timeout: 30 * time.Second},
	}
}

// Upload uploads bytes to Supabase Storage and returns the public URL.
func (s *SupabaseStorage) Upload(fileBytes []byte, filename, contentType string) (string, error) {
	path := fmt.Sprintf("reports/%d_%s", time.Now().UnixMilli(), filename)
	uploadURL := fmt.Sprintf("%s/storage/v1/object/%s/%s", s.url, s.bucket, path)

	req, err := http.NewRequest(http.MethodPost, uploadURL, bytes.NewReader(fileBytes))
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.key)
	req.Header.Set("Content-Type", contentType)

	resp, err := s.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("upload request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("storage upload failed (%d): %s", resp.StatusCode, string(body))
	}

	publicURL := fmt.Sprintf("%s/storage/v1/object/public/%s/%s", s.url, s.bucket, path)
	return publicURL, nil
}
