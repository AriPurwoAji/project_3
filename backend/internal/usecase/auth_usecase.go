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

func (u *authUsecase) GetTechnicians() ([]domain.User, error) {
	return u.userRepo.FindAllByRole("teknisi")
}

func (u *authUsecase) UpdateProfile(userID string, req domain.UpdateProfileRequest) (*domain.User, error) {
	if err := u.userRepo.UpdateProfile(userID, req.FullName, req.Phone); err != nil {
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
	// Cek email sudah dipakai
	if _, _, err := u.userRepo.FindByEmail(req.Email); err == nil {
		return nil, errors.New("email sudah terdaftar")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, errors.New("gagal memproses password")
	}
	req.PasswordHash = string(hash)

	return u.userRepo.Register(req)
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