package usecase

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"os"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/AriPurwoAji/project_3/backend/internal/infrastructure/jwt"
	"golang.org/x/crypto/bcrypt"
)

type authUsecase struct {
	userRepo    domain.UserRepository
	emailSender domain.EmailSender
}

func NewAuthUsecase(userRepo domain.UserRepository, emailSender domain.EmailSender) domain.AuthUsecase {
	return &authUsecase{userRepo: userRepo, emailSender: emailSender}
}

func (u *authUsecase) Login(req domain.LoginRequest) (*domain.LoginResponse, error) {
	user, passwordHash, err := u.userRepo.FindByEmail(req.Email)
	if err != nil {
		return nil, errors.New("email atau password salah")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("email atau password salah")
	}

	// Akun pending — belum dikonfirmasi manager
	if !user.IsActive {
		return nil, errors.New("Akun kamu sedang menunggu konfirmasi manager. Pastikan email sudah diverifikasi terlebih dahulu")
	}

	// Client harus verifikasi email sebelum bisa login
	if user.Role == "client" && user.EmailVerifiedAt == nil {
		return nil, errors.New("email belum diverifikasi. Cek inbox email kamu dan klik link verifikasi")
	}

	accessToken, err := jwt.GenerateAccessToken(user.ID, user.Role, user.CompanyID)
	if err != nil {
		return nil, errors.New("gagal generate token")
	}

	refreshToken, err := jwt.GenerateRefreshToken(user.ID, user.Role, user.CompanyID)
	if err != nil {
		return nil, errors.New("gagal generate refresh token")
	}

	return &domain.LoginResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         *user,
	}, nil
}

func (u *authUsecase) GetProfile(id string) (*domain.User, error) {
	return u.userRepo.FindByID(id)
}

func (u *authUsecase) GetTechnicians() ([]domain.User, error) {
	return u.userRepo.FindAllByRole("teknisi")
}

func (u *authUsecase) GetSales() ([]domain.User, error) {
	return u.userRepo.FindAllByRole("sales")
}

func (u *authUsecase) GetClients() ([]domain.User, error) {
	return u.userRepo.FindAllByRole("client")
}

func (u *authUsecase) UpdateProfile(userID string, req domain.UpdateProfileRequest) (*domain.User, error) {
	if err := u.userRepo.UpdateProfile(userID, req.FullName, req.Phone, req.AvatarURL,
		req.CompanyName, req.CompanyIndustry, req.CompanyCity); err != nil {
		return nil, errors.New("gagal memperbarui profil")
	}
	return u.userRepo.FindByID(userID)
}

func (u *authUsecase) ChangePassword(userID string, req domain.ChangePasswordRequest) error {
	hash, err := u.userRepo.FindPasswordHashByID(userID)
	if err != nil {
		return errors.New("user tidak ditemukan")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.OldPassword)); err != nil {
		return errors.New("password lama tidak sesuai")
	}
	newHash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		return errors.New("gagal memproses password")
	}
	return u.userRepo.ChangePassword(userID, string(newHash))
}

func (u *authUsecase) Register(req domain.RegisterRequest) (*domain.User, error) {
	if _, _, err := u.userRepo.FindByEmail(req.Email); err == nil {
		return nil, errors.New("email sudah terdaftar")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, errors.New("gagal memproses password")
	}
	req.PasswordHash = string(hash)

	user, err := u.userRepo.Register(req)
	if err != nil {
		return nil, err
	}

	// Kirim email verifikasi untuk role client
	if user.Role == "client" {
		go u.sendVerificationEmail(user.ID, user.Email, user.FullName)
	}

	return user, nil
}

func (u *authUsecase) sendVerificationEmail(userID, email, name string) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		log.Printf("[Email] gagal generate token untuk %s: %v", email, err)
		return
	}
	token := hex.EncodeToString(b)

	if err := u.userRepo.SaveVerificationToken(userID, token); err != nil {
		log.Printf("[Email] gagal simpan token untuk %s: %v", email, err)
		return
	}

	appURL := os.Getenv("APP_URL")
	if appURL == "" {
		appURL = fmt.Sprintf("http://localhost:%s", os.Getenv("APP_PORT"))
	}
	verifyLink := fmt.Sprintf("%s/api/v1/auth/verify-email?token=%s", appURL, token)

	subject := "Verifikasi Email Akun HydroServ Kamu"
	body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<body style="font-family:sans-serif;background:#f5f5f5;padding:24px">
  <div style="max-width:480px;margin:0 auto;background:#fff;border-radius:12px;padding:32px">
    <h2 style="color:#1565C0;margin-top:0">HydroServ</h2>
    <p>Halo <strong>%s</strong>,</p>
    <p>Terima kasih sudah mendaftar! Klik tombol di bawah untuk memverifikasi email kamu dan mulai menggunakan akun HydroServ.</p>
    <a href="%s"
       style="display:inline-block;background:#1565C0;color:#fff;padding:12px 24px;
              border-radius:8px;text-decoration:none;font-weight:600;margin:16px 0">
      Verifikasi Email
    </a>
    <p style="color:#888;font-size:12px">Link ini berlaku selama 24 jam.<br>
    Jika kamu tidak mendaftar di HydroServ, abaikan email ini.</p>
  </div>
</body>
</html>`, name, verifyLink)

	if err := u.emailSender.SendHTML(email, subject, body); err != nil {
		log.Printf("[Email] gagal kirim verifikasi ke %s: %v", email, err)
	} else {
		log.Printf("[Email] verifikasi terkirim ke %s", email)
	}
}

func (u *authUsecase) VerifyEmail(token string) error {
	return u.userRepo.VerifyEmailToken(token)
}

func (u *authUsecase) RefreshToken(refreshToken string) (string, error) {
	claims, err := jwt.ValidateToken(refreshToken)
	if err != nil {
		return "", errors.New("refresh token tidak valid atau sudah kadaluarsa")
	}
	accessToken, err := jwt.GenerateAccessToken(claims.UserID, claims.Role, claims.CompanyID)
	if err != nil {
		return "", errors.New("gagal generate token baru")
	}
	return accessToken, nil
}

func (u *authUsecase) UpdateFCMToken(userID, token string) error {
	return u.userRepo.UpdateFCMToken(userID, token)
}

func (u *authUsecase) GetPendingUsers() ([]domain.User, error) {
	return u.userRepo.GetPendingUsers()
}

func (u *authUsecase) ActivateUser(userID string) error {
	// Ambil email user untuk notifikasi
	user, err := u.userRepo.FindByID(userID)
	if err != nil {
		return errors.New("user tidak ditemukan")
	}

	if err := u.userRepo.ActivateUser(userID); err != nil {
		return err
	}

	// Kirim email notifikasi aktivasi (background, tidak block response)
	go func() {
		subject := "Akun HydroServ Kamu Sudah Diaktifkan!"
		body := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<body style="font-family:sans-serif;background:#f5f5f5;padding:24px">
  <div style="max-width:480px;margin:0 auto;background:#fff;border-radius:12px;padding:32px">
    <h2 style="color:#1565C0;margin-top:0">HydroServ</h2>
    <p>Halo <strong>%s</strong>,</p>
    <p>Kabar baik! Akun HydroServ kamu telah <strong>diaktifkan oleh manager</strong>.</p>
    <p>Kamu sekarang bisa login ke aplikasi HydroServ dan mulai membuat booking layanan hydraulic.</p>
    <p style="color:#888;font-size:12px">Jika ada pertanyaan, hubungi tim kami.</p>
  </div>
</body>
</html>`, user.FullName)
		if err := u.emailSender.SendHTML(user.Email, subject, body); err != nil {
			log.Printf("[Email] gagal kirim aktivasi ke %s: %v", user.Email, err)
		}
	}()

	return nil
}

func (u *authUsecase) CreateUser(req domain.CreateUserRequest) (*domain.User, error) {
	if _, _, err := u.userRepo.FindByEmail(req.Email); err == nil {
		return nil, errors.New("email sudah terdaftar")
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, errors.New("gagal memproses password")
	}
	req.PasswordHash = string(hash)
	return u.userRepo.CreateUser(req)
}