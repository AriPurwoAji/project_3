package domain

import (
	"time"
)

type User struct {
	ID               string     `json:"id"`
	Email            string     `json:"email"`
	FullName         string     `json:"full_name"`
	Phone            string     `json:"phone"`
	Role             string     `json:"role"`
	CompanyID        string     `json:"company_id"`
	CompanyName      string     `json:"company_name,omitempty"`
	CompanyIndustry  string     `json:"company_industry,omitempty"`
	CompanyCity      string     `json:"company_city,omitempty"`
	AvatarURL        string     `json:"avatar_url,omitempty"`
	FCMToken         string     `json:"fcm_token"`
	IsActive         bool       `json:"is_active"`
	EmailVerifiedAt  *time.Time `json:"email_verified_at,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
	DeletedAt        *time.Time `json:"deleted_at,omitempty"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

type UpdateProfileRequest struct {
	FullName        string `json:"full_name" binding:"required"`
	Phone           string `json:"phone"`
	AvatarURL       string `json:"avatar_url"`
	CompanyName     string `json:"company_name"`
	CompanyIndustry string `json:"company_industry"`
	CompanyCity     string `json:"company_city"`
}

type ChangePasswordRequest struct {
	OldPassword string `json:"old_password" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=6"`
}

type RegisterRequest struct {
	FullName           string `json:"full_name"           binding:"required"`
	Email              string `json:"email"               binding:"required,email"`
	Password           string `json:"password"            binding:"required,min=6"`
	Phone              string `json:"phone"`
	CompanyName        string `json:"company_name"        binding:"required"`
	CompanyIndustry    string `json:"company_industry"`
	CompanyProvince    string `json:"company_province"`
	CompanyCity        string `json:"company_city"        binding:"required"`
	CompanyKecamatan   string `json:"company_kecamatan"`
	CompanyKelurahan   string `json:"company_kelurahan"`
	CompanyAddress     string `json:"company_address"`
	// set by usecase before passing to repository
	PasswordHash string `json:"-"`
}

type LoginResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	User         User   `json:"user"`
}

type CreateUserRequest struct {
	FullName  string `json:"full_name"  binding:"required"`
	Email     string `json:"email"      binding:"required,email"`
	Password  string `json:"password"   binding:"required,min=6"`
	Phone     string `json:"phone"`
	Role      string `json:"role"       binding:"required,oneof=teknisi sales client"`
	CompanyID string `json:"company_id"`
	// set by usecase
	PasswordHash string `json:"-"`
}

type UserRepository interface {
	FindByEmail(email string) (*User, string, error)
	FindByID(id string) (*User, error)
	FindPasswordHashByID(id string) (string, error)
	UpdateFCMToken(id, token string) error
	UpdateProfile(userID, fullName, phone, avatarURL, companyName, companyIndustry, companyCity string) error
	ChangePassword(userID, newHash string) error
	FindAllByRole(role string) ([]User, error)
	Register(req RegisterRequest) (*User, error)
	CreateUser(req CreateUserRequest) (*User, error)
	// FCM helpers
	GetFCMToken(userID string) string
	GetFCMTokensByRole(role string) []string
	// Email verification
	SaveVerificationToken(userID, token string) error
	VerifyEmailToken(token string) error
	// Pending account management
	GetPendingUsers() ([]User, error)
	ActivateUser(userID string) error
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type AuthUsecase interface {
	Login(req LoginRequest) (*LoginResponse, error)
	RefreshToken(refreshToken string) (string, error)
	GetProfile(id string) (*User, error)
	GetTechnicians() ([]User, error)
	GetSales() ([]User, error)
	GetClients() ([]User, error)
	Register(req RegisterRequest) (*User, error)
	UpdateProfile(userID string, req UpdateProfileRequest) (*User, error)
	ChangePassword(userID string, req ChangePasswordRequest) error
	CreateUser(req CreateUserRequest) (*User, error)
	UpdateFCMToken(userID, token string) error
	VerifyEmail(token string) error
	GetPendingUsers() ([]User, error)
	ActivateUser(userID string) error
}

// EmailSender abstraksi pengiriman email
type EmailSender interface {
	Enabled() bool
	SendHTML(to, subject, body string) error
}