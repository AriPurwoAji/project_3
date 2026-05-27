package usecase

import (
	"errors"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/AriPurwoAji/project_3/backend/internal/infrastructure/jwt"
	"golang.org/x/crypto/bcrypt"
)

type authUsecase struct {
	userRepo domain.UserRepository
}

func NewAuthUsecase(userRepo domain.UserRepository) domain.AuthUsecase {
	return &authUsecase{userRepo: userRepo}
}

func (u *authUsecase) Login(req domain.LoginRequest) (*domain.LoginResponse, error) {
	user, passwordHash, err := u.userRepo.FindByEmail(req.Email)
	if err != nil {
		return nil, errors.New("email atau password salah")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		return nil, errors.New("email atau password salah")
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