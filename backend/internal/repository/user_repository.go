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

func (r *userRepository) FindPasswordHashByID(id string) (string, error) {
	var hash string
	err := r.db.QueryRow(context.Background(),
		`SELECT password_hash FROM users WHERE id = $1 AND deleted_at IS NULL`, id,
	).Scan(&hash)
	return hash, err
}

func (r *userRepository) UpdateProfile(userID, fullName, phone string) error {
	_, err := r.db.Exec(context.Background(),
		`UPDATE users SET full_name = $1, phone = NULLIF($2,''), updated_at = NOW() WHERE id = $3`,
		fullName, phone, userID,
	)
	return err
}

func (r *userRepository) ChangePassword(userID, newHash string) error {
	_, err := r.db.Exec(context.Background(),
		`UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`,
		newHash, userID,
	)
	return err
}

func (r *userRepository) UpdateFCMToken(id, token string) error {
	query := `UPDATE users SET fcm_token = $1, updated_at = NOW() WHERE id = $2`
	_, err := r.db.Exec(context.Background(), query, token, id)
	return err
}

func (r *userRepository) Register(req domain.RegisterRequest) (*domain.User, error) {
	ctx := context.Background()

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx) //nolint

	// 1. Buat company baru
	var companyID string
	err = tx.QueryRow(ctx,
		`INSERT INTO companies (name) VALUES ($1) RETURNING id`,
		req.CompanyName,
	).Scan(&companyID)
	if err != nil {
		return nil, err
	}

	// 2. Buat user dengan role client
	var user domain.User
	err = tx.QueryRow(ctx,
		`INSERT INTO users (email, password_hash, full_name, phone, role, company_id)
		 VALUES ($1, $2, $3, NULLIF($4,''), 'client', $5)
		 RETURNING id, email, full_name, role, is_active, created_at, updated_at`,
		req.Email, req.PasswordHash, req.FullName, req.Phone, companyID,
	).Scan(
		&user.ID, &user.Email, &user.FullName, &user.Role,
		&user.IsActive, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	user.Phone       = req.Phone
	user.CompanyID   = companyID
	user.CompanyName = req.CompanyName

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) FindAllByRole(role string) ([]domain.User, error) {
	query := `
		SELECT u.id, u.email, u.full_name, u.phone, u.role,
		       u.fcm_token, u.is_active, u.created_at, u.updated_at,
		       COALESCE(u.company_id::text, '') AS company_id,
		       COALESCE(c.name, '') AS company_name
		FROM users u
		LEFT JOIN companies c ON u.company_id = c.id
		WHERE u.role = $1 AND u.deleted_at IS NULL AND u.is_active = TRUE
		ORDER BY u.full_name ASC
	`
	rows, err := r.db.Query(context.Background(), query, role)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []domain.User
	for rows.Next() {
		var u domain.User
		var phone, fcmToken *string
		if err := rows.Scan(
			&u.ID, &u.Email, &u.FullName,
			&phone, &u.Role, &fcmToken,
			&u.IsActive, &u.CreatedAt, &u.UpdatedAt,
			&u.CompanyID, &u.CompanyName,
		); err != nil {
			return nil, err
		}
		if phone != nil {
			u.Phone = *phone
		}
		if fcmToken != nil {
			u.FCMToken = *fcmToken
		}
		users = append(users, u)
	}
	if users == nil {
		users = []domain.User{}
	}
	return users, rows.Err()
}