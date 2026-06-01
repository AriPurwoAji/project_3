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
		       u.fcm_token, u.is_active, u.email_verified_at,
		       u.created_at, u.updated_at,
		       COALESCE(u.avatar_url, '')      AS avatar_url,
		       COALESCE(u.company_id::text, '') AS company_id,
		       COALESCE(c.name, '')            AS company_name,
		       COALESCE(c.industry, '')        AS company_industry,
		       COALESCE(c.city, '')            AS company_city
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
		&fcmToken, &user.IsActive, &user.EmailVerifiedAt,
		&user.CreatedAt, &user.UpdatedAt,
		&user.AvatarURL,
		&user.CompanyID, &user.CompanyName,
		&user.CompanyIndustry, &user.CompanyCity,
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
		       COALESCE(u.avatar_url, '')      AS avatar_url,
		       COALESCE(u.company_id::text, '') AS company_id,
		       COALESCE(c.name, '')            AS company_name,
		       COALESCE(c.industry, '')        AS company_industry,
		       COALESCE(c.city, '')            AS company_city
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
		&user.AvatarURL,
		&user.CompanyID, &user.CompanyName,
		&user.CompanyIndustry, &user.CompanyCity,
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

func (r *userRepository) UpdateProfile(userID, fullName, phone, avatarURL, companyName, companyIndustry, companyCity string) error {
	ctx := context.Background()

	_, err := r.db.Exec(ctx,
		`UPDATE users SET full_name = $1, phone = NULLIF($2,''),
		 avatar_url = CASE WHEN $3 = '' THEN avatar_url ELSE $3 END,
		 updated_at = NOW() WHERE id = $4`,
		fullName, phone, avatarURL, userID,
	)
	if err != nil {
		return err
	}

	// Update info perusahaan jika ada data yang dikirim
	if companyName != "" || companyIndustry != "" || companyCity != "" {
		r.db.Exec(ctx, `
			UPDATE companies SET
				name     = CASE WHEN $1 = '' THEN name     ELSE $1 END,
				industry = CASE WHEN $2 = '' THEN industry ELSE $2 END,
				city     = CASE WHEN $3 = '' THEN city     ELSE $3 END,
				updated_at = NOW()
			WHERE id = (SELECT company_id FROM users WHERE id = $4 AND company_id IS NOT NULL)
		`, companyName, companyIndustry, companyCity, userID)
	}
	return nil
}

func (r *userRepository) ChangePassword(userID, newHash string) error {
	_, err := r.db.Exec(context.Background(),
		`UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`,
		newHash, userID,
	)
	return err
}

func (r *userRepository) UpdateFCMToken(id, token string) error {
	// Lepas token dari user lain yang pakai device yang sama (ganti akun di HP)
	r.db.Exec(context.Background(),
		`UPDATE users SET fcm_token = NULL WHERE fcm_token = $1 AND id != $2`,
		token, id,
	)
	_, err := r.db.Exec(context.Background(),
		`UPDATE users SET fcm_token = $1, updated_at = NOW() WHERE id = $2`,
		token, id,
	)
	return err
}

func (r *userRepository) GetFCMToken(userID string) string {
	var token string
	r.db.QueryRow(context.Background(),
		`SELECT COALESCE(fcm_token,'') FROM users WHERE id = $1 AND deleted_at IS NULL`,
		userID).Scan(&token)
	return token
}

func (r *userRepository) GetFCMTokensByRole(role string) []string {
	rows, err := r.db.Query(context.Background(),
		`SELECT fcm_token FROM users
		 WHERE role = $1 AND deleted_at IS NULL AND is_active = TRUE
		 AND fcm_token IS NOT NULL AND fcm_token != ''`, role)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var tokens []string
	for rows.Next() {
		var t string
		if rows.Scan(&t) == nil && t != "" {
			tokens = append(tokens, t)
		}
	}
	return tokens
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
		`INSERT INTO companies (name, industry, city, pic_name, pic_phone)
		 VALUES ($1, NULLIF($2,''), NULLIF($3,''), $4, NULLIF($5,''))
		 RETURNING id`,
		req.CompanyName, req.CompanyIndustry, req.CompanyCity, req.FullName, req.Phone,
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
	user.Phone           = req.Phone
	user.CompanyID       = companyID
	user.CompanyName     = req.CompanyName
	user.CompanyIndustry = req.CompanyIndustry
	user.CompanyCity     = req.CompanyCity

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *userRepository) CreateUser(req domain.CreateUserRequest) (*domain.User, error) {
	ctx := context.Background()
	var user domain.User
	companyID := req.CompanyID
	if companyID == "" {
		companyID = "NULL"
	}
	var companyIDArg interface{}
	if req.CompanyID != "" {
		companyIDArg = req.CompanyID
	}
	err := r.db.QueryRow(ctx,
		`INSERT INTO users (email, password_hash, full_name, phone, role, company_id)
		 VALUES ($1, $2, $3, NULLIF($4,''), $5, $6)
		 RETURNING id, email, full_name, role, is_active, created_at, updated_at`,
		req.Email, req.PasswordHash, req.FullName, req.Phone, req.Role, companyIDArg,
	).Scan(
		&user.ID, &user.Email, &user.FullName, &user.Role,
		&user.IsActive, &user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	user.Phone     = req.Phone
	user.CompanyID = req.CompanyID
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

func (r *userRepository) SaveVerificationToken(userID, token string) error {
	_, err := r.db.Exec(context.Background(), `
		INSERT INTO email_verification_tokens (user_id, token, expires_at)
		VALUES ($1, $2, NOW() + INTERVAL '24 hours')
	`, userID, token)
	return err
}

func (r *userRepository) VerifyEmailToken(token string) error {
	var userID string
	err := r.db.QueryRow(context.Background(), `
		SELECT user_id FROM email_verification_tokens
		WHERE token = $1
		  AND used_at IS NULL
		  AND expires_at > NOW()
	`, token).Scan(&userID)
	if err != nil {
		return errors.New("token tidak valid atau sudah kadaluarsa")
	}

	tx, err := r.db.Begin(context.Background())
	if err != nil {
		return err
	}
	defer tx.Rollback(context.Background()) //nolint

	tx.Exec(context.Background(),
		`UPDATE email_verification_tokens SET used_at = NOW() WHERE token = $1`, token)
	tx.Exec(context.Background(),
		`UPDATE users SET email_verified_at = NOW() WHERE id = $1`, userID)

	return tx.Commit(context.Background())
}