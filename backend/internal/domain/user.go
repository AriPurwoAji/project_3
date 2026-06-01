package domain

import (
	"time"
)

type User struct {
	ID          string     `json:"id"`
	Email       string     `json:"email"`
	FullName    string     `json:"full_name"`
	Phone       string     `json:"phone"`
	Role        string     `json:"role"`
	CompanyID   string     `json:"company_id"`
	CompanyName string     `json:"company_name,omitempty"`
	FCMToken    string     `json:"fcm_token"`
	IsActive    bool       `json:"is_active"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	DeletedAt   *time.Time `json:"deleted_at,omitempty"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

type UpdateProfileRequest struct {
	FullName string `json:"full_name" binding:"required"`
	Phone    string `json:"phone"`
}

type ChangePasswordRequest struct {
	OldPassword string `json:"old_password" binding:"required"`
	NewPassword string `json:"new_password" binding:"required,min=6"`
}

type RegisterRequest struct {
	FullName    string `json:"full_name"    binding:"required"`
	Email       string `json:"email"        binding:"required,email"`
	Password    string `json:"password"     binding:"required,min=6"`
	Phone       string `json:"phone"`
	CompanyName string `json:"company_name" binding:"required"`
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
	UpdateProfile(userID, fullName, phone string) error
	ChangePassword(userID, newHash string) error
	FindAllByRole(role string) ([]User, error)
	Register(req RegisterRequest) (*User, error)
	CreateUser(req CreateUserRequest) (*User, error)
	// FCM helpers
	GetFCMToken(userID string) string
	GetFCMTokensByRole(role string) []string
}

type AuthUsecase interface {
	Login(req LoginRequest) (*LoginResponse, error)
	GetProfile(id string) (*User, error)
	GetTechnicians() ([]User, error)
	GetSales() ([]User, error)
	GetClients() ([]User, error)
	Register(req RegisterRequest) (*User, error)
	UpdateProfile(userID string, req UpdateProfileRequest) (*User, error)
	ChangePassword(userID string, req ChangePasswordRequest) error
	CreateUser(req CreateUserRequest) (*User, error)
	UpdateFCMToken(userID, token string) error
}