package repository

import (
	"context"
	"errors"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/jackc/pgx/v5/pgxpool"
)

type userRepository struct {
	db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) domain.UserRepository {
	return &userRepository{db: db}
}

func (r *userRepository) FindByEmail(email string) (*domain.User, string, error) {
	query := `
		SELECT id, email, password_hash, full_name, phone, role, 
		       fcm_token, is_active, created_at, updated_at
		FROM users 
		WHERE email = $1 AND deleted_at IS NULL AND is_active = TRUE
	`
	var user domain.User
	var passwordHash string
	var phone, fcmToken *string

	err := r.db.QueryRow(context.Background(), query, email).Scan(
		&user.ID,
		&user.Email,
		&passwordHash,
		&user.FullName,
		&phone,
		&user.Role,
		&fcmToken,
		&user.IsActive,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		return nil, "", errors.New("user not found")
	}

	if phone != nil {
		user.Phone = *phone
	}
	if fcmToken != nil {
		user.FCMToken = *fcmToken
	}

	return &user, passwordHash, nil
}

func (r *userRepository) FindByID(id string) (*domain.User, error) {
	query := `
		SELECT id, email, full_name, phone, role,
		       fcm_token, is_active, created_at, updated_at
		FROM users 
		WHERE id = $1 AND deleted_at IS NULL
	`
	var user domain.User
	var phone, fcmToken *string

	err := r.db.QueryRow(context.Background(), query, id).Scan(
		&user.ID,
		&user.Email,
		&user.FullName,
		&phone,
		&user.Role,
		&fcmToken,
		&user.IsActive,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		return nil, errors.New("user not found")
	}

	if phone != nil {
		user.Phone = *phone
	}
	if fcmToken != nil {
		user.FCMToken = *fcmToken
	}

	return &user, nil
}

func (r *userRepository) UpdateFCMToken(id, token string) error {
	query := `UPDATE users SET fcm_token = $1, updated_at = NOW() WHERE id = $2`
	_, err := r.db.Exec(context.Background(), query, token, id)
	return err
}