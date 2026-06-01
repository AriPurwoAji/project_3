package email

import (
	"crypto/tls"
	"fmt"
	"log"
	"net/smtp"
	"os"
	"strconv"
)

type Sender struct {
	host     string
	port     int
	username string
	password string
	from     string
	enabled  bool
}

func NewSender() *Sender {
	host    := os.Getenv("SMTP_HOST")
	portStr := os.Getenv("SMTP_PORT")
	if host == "" || portStr == "" {
		log.Println("[Email] SMTP_HOST/SMTP_PORT tidak diset, pengiriman email dinonaktifkan")
		return &Sender{}
	}
	port, _ := strconv.Atoi(portStr)
	from := os.Getenv("SMTP_FROM")
	if from == "" {
		from = os.Getenv("SMTP_USER")
	}
	log.Printf("[Email] SMTP dikonfigurasi: %s:%d", host, port)
	return &Sender{
		host:     host,
		port:     port,
		username: os.Getenv("SMTP_USER"),
		password: os.Getenv("SMTP_PASS"),
		from:     from,
		enabled:  true,
	}
}

func (s *Sender) Enabled() bool { return s.enabled }

// SendHTML mengirim email HTML ke satu penerima.
func (s *Sender) SendHTML(to, subject, body string) error {
	if !s.enabled {
		return nil
	}

	msg := fmt.Sprintf(
		"From: HydroServ <%s>\r\nTo: %s\r\nSubject: %s\r\n"+
			"MIME-Version: 1.0\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n%s",
		s.from, to, subject, body,
	)

	auth := smtp.PlainAuth("", s.username, s.password, s.host)
	addr := fmt.Sprintf("%s:%d", s.host, s.port)

	// Port 465 = SSL langsung; port 587/25 = STARTTLS
	if s.port == 465 {
		return s.sendSSL(addr, auth, to, msg)
	}
	return smtp.SendMail(addr, auth, s.from, []string{to}, []byte(msg))
}

func (s *Sender) sendSSL(addr string, auth smtp.Auth, to, msg string) error {
	tlsConf := &tls.Config{ServerName: s.host}
	conn, err := tls.Dial("tcp", addr, tlsConf)
	if err != nil {
		return err
	}
	client, err := smtp.NewClient(conn, s.host)
	if err != nil {
		return err
	}
	defer client.Quit() //nolint

	if err = client.Auth(auth); err != nil {
		return err
	}
	if err = client.Mail(s.from); err != nil {
		return err
	}
	if err = client.Rcpt(to); err != nil {
		return err
	}
	w, err := client.Data()
	if err != nil {
		return err
	}
	if _, err = fmt.Fprint(w, msg); err != nil {
		return err
	}
	return w.Close()
}
