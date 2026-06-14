package fcm

import (
	"bytes"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const (
	fcmV1URL = "https://fcm.googleapis.com/v1/projects/%s/messages:send"
	tokenURL = "https://oauth2.googleapis.com/token"
	fcmScope = "https://www.googleapis.com/auth/firebase.messaging"
)

type serviceAccount struct {
	ProjectID   string `json:"project_id"`
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
}

type Sender struct {
	projectID   string
	clientEmail string
	privateKey  *rsa.PrivateKey

	mu          sync.Mutex
	accessToken string
	tokenExpiry time.Time

	enabled bool
}

func NewSender() *Sender {
	// Prioritas 1: baca dari env var JSON (untuk cloud deployment)
	var data []byte
	if jsonContent := os.Getenv("FCM_SERVICE_ACCOUNT_JSON"); jsonContent != "" {
		data = []byte(jsonContent)
		log.Println("[FCM] memuat service account dari env var FCM_SERVICE_ACCOUNT_JSON")
	} else if credPath := os.Getenv("FCM_SERVICE_ACCOUNT_PATH"); credPath != "" {
		// Prioritas 2: baca dari file (untuk local development)
		var err error
		data, err = os.ReadFile(credPath)
		if err != nil {
			log.Printf("[FCM] gagal baca service account: %v", err)
			return &Sender{}
		}
	} else {
		log.Println("[FCM] FCM tidak dikonfigurasi, push notification dinonaktifkan")
		return &Sender{}
	}

	var sa serviceAccount
	if err := json.Unmarshal(data, &sa); err != nil {
		log.Printf("[FCM] gagal parse service account JSON: %v", err)
		return &Sender{}
	}

	rsaKey, err := parsePrivateKey(sa.PrivateKey)
	if err != nil {
		log.Printf("[FCM] gagal parse private key: %v", err)
		return &Sender{}
	}

	log.Printf("[FCM] service account dimuat: project=%s", sa.ProjectID)
	return &Sender{
		projectID:   sa.ProjectID,
		clientEmail: sa.ClientEmail,
		privateKey:  rsaKey,
		enabled:     true,
	}
}

func (s *Sender) Enabled() bool { return s.enabled }

func parsePrivateKey(pemStr string) (*rsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(pemStr))
	if block == nil {
		return nil, errors.New("gagal decode PEM block")
	}
	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}
	rsaKey, ok := key.(*rsa.PrivateKey)
	if !ok {
		return nil, errors.New("bukan RSA key")
	}
	return rsaKey, nil
}

// getAccessToken mengambil OAuth2 access token dari Google menggunakan JWT assertion.
// Token di-cache selama ~55 menit untuk menghindari request berulang.
func (s *Sender) getAccessToken() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.accessToken != "" && time.Now().Before(s.tokenExpiry.Add(-5*time.Minute)) {
		return s.accessToken, nil
	}

	now := time.Now()
	claims := jwt.MapClaims{
		"iss":   s.clientEmail,
		"scope": fcmScope,
		"aud":   tokenURL,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	signed, err := tok.SignedString(s.privateKey)
	if err != nil {
		return "", fmt.Errorf("gagal sign JWT: %w", err)
	}

	resp, err := http.PostForm(tokenURL, url.Values{
		"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"},
		"assertion":  {signed},
	})
	if err != nil {
		return "", fmt.Errorf("gagal request access token: %w", err)
	}
	defer resp.Body.Close()

	var result struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
		Error       string `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	if result.Error != "" {
		return "", errors.New("OAuth2 error: " + result.Error)
	}

	s.accessToken = result.AccessToken
	s.tokenExpiry = now.Add(time.Duration(result.ExpiresIn) * time.Second)
	return s.accessToken, nil
}

type v1Payload struct {
	Message v1Message `json:"message"`
}

type v1Message struct {
	Token        string            `json:"token"`
	Notification v1Notification    `json:"notification"`
	Data         map[string]string `json:"data,omitempty"`
	Android      *androidConfig    `json:"android,omitempty"`
}

type v1Notification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type androidConfig struct {
	Priority string `json:"priority"`
}

// Send kirim push notification ke satu FCM token via FCM HTTP v1 API.
func (s *Sender) Send(token, title, body string, data map[string]string) error {
	if !s.enabled || token == "" {
		return nil
	}

	accessToken, err := s.getAccessToken()
	if err != nil {
		return err
	}

	payload := v1Payload{
		Message: v1Message{
			Token:        token,
			Notification: v1Notification{Title: title, Body: body},
			Data:         data,
			Android:      &androidConfig{Priority: "high"},
		},
	}
	buf, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	reqURL := fmt.Sprintf(fcmV1URL, s.projectID)
	req, err := http.NewRequest(http.MethodPost, reqURL, bytes.NewBuffer(buf))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("FCM returned %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}
