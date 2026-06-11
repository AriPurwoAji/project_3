package email

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
)

type Sender struct {
	apiKey  string
	from    string
	enabled bool
}

func NewSender() *Sender {
	// Prioritas 1: Resend HTTP API (tidak terblokir oleh cloud provider)
	if apiKey := os.Getenv("RESEND_API_KEY"); apiKey != "" {
		from := os.Getenv("SMTP_FROM")
		if from == "" {
			from = "onboarding@resend.dev"
		}
		log.Printf("[Email] Resend API dikonfigurasi, from: %s", from)
		return &Sender{apiKey: apiKey, from: from, enabled: true}
	}

	// Prioritas 2: fallback SMTP (untuk local development)
	host := os.Getenv("SMTP_HOST")
	port := os.Getenv("SMTP_PORT")
	if host == "" || port == "" {
		log.Println("[Email] tidak ada konfigurasi email, pengiriman dinonaktifkan")
		return &Sender{}
	}
	log.Printf("[Email] SMTP dikonfigurasi: %s:%s (catatan: mungkin diblokir di cloud)", host, port)
	return &Sender{
		apiKey:  "",
		from:    os.Getenv("SMTP_FROM"),
		enabled: true,
	}
}

func (s *Sender) Enabled() bool { return s.enabled }

// SendHTML mengirim email HTML via Resend HTTP API.
func (s *Sender) SendHTML(to, subject, body string) error {
	if !s.enabled {
		return nil
	}

	if s.apiKey != "" {
		return s.sendViaResendAPI(to, subject, body)
	}
	return s.sendViaSMTP(to, subject, body)
}

// sendViaResendAPI menggunakan Resend REST API (HTTPS port 443, tidak diblokir).
func (s *Sender) sendViaResendAPI(to, subject, body string) error {
	payload := map[string]interface{}{
		"from":    fmt.Sprintf("HydroServ <%s>", s.from),
		"to":      []string{to},
		"subject": subject,
		"html":    body,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("gagal marshal payload: %w", err)
	}

	req, err := http.NewRequest("POST", "https://api.resend.com/emails", bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("gagal buat request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("gagal kirim request ke Resend: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("Resend API error: status %d", resp.StatusCode)
	}

	return nil
}

// sendViaSMTP fallback untuk local development.
func (s *Sender) sendViaSMTP(to, subject, body string) error {
	log.Printf("[Email] SMTP fallback dipanggil untuk %s (mungkin gagal di cloud)", to)
	return fmt.Errorf("SMTP tidak dikonfigurasi untuk cloud, gunakan RESEND_API_KEY")
}
