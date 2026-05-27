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
		SELECT u.id, u.email, u.password_hash, u.full_name, u.phone, u.role,
		       u.fcm_token, u.is_active, u.created_at, u.updated_at,
		       COALESCE(u.company_id::text, '') AS company_id,
		       COALESCE(c.name, '') AS company_name
		FROM users u
		LEFT JOIN companies c ON u.company_id = c.id
		WHERE u.email = $1 AND u.deleted_at IS NULL AND u.is_active = TRUE
	`
	var user domain.User
	var passwordHash string
	var phone, fcmToken *string

	err := r.db.QueryRow(context.Background(), query, email).Scan(
		&user.ID, &user.Email, &passwordHash,
		&user.FullName, &phone, &user.Role,
		&fcmToken, &user.IsActive,
		&user.CreatedAt, &user.UpdatedAt,
		&user.CompanyID, &user.CompanyName,
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
		SELECT u.id, u.email, u.full_name, u.phone, u.role,
		       u.fcm_token, u.is_active, u.created_at, u.updated_at,
		       COALESCE(u.company_id::text, '') AS company_id,
		       COALESCE(c.name, '') AS company_name
		FROM users u
		LEFT JOIN companies c ON u.company_id = c.id
		WHERE u.id = $1 AND u.deleted_at IS NULL
	`
	var user domain.User
	var phone, fcmToken *string

	err := r.db.QueryRow(context.Background(), query, id).Scan(
		&user.ID, &user.Email, &user.FullName,
		&phone, &user.Role, &fcmToken,
		&user.IsActive, &user.CreatedAt, &user.UpdatedAt,
		&user.CompanyID, &user.CompanyName,
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