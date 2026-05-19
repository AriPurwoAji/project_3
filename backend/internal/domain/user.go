package domain

import (
	"time"
)

type User struct {
	ID        string     `json:"id"`
	Email     string     `json:"email"`
	FullName  string     `json:"full_name"`
	Phone     string     `json:"phone"`
	Role      string     `json:"role"`
	FCMToken  string     `json:"fcm_token"`
	IsActive  bool       `json:"is_active"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	DeletedAt *time.Time `json:"deleted_at,omitempty"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

type LoginResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	User         User   `json:"user"`
}

type UserRepository interface {
	FindByEmail(email string) (*User, string, error)
	FindByID(id string) (*User, error)
	UpdateFCMToken(id, token string) error
}

type AuthUsecase interface {
	Login(req LoginRequest) (*LoginResponse, error)
	GetProfile(id string) (*User, error)
}