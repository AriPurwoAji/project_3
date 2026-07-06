package repository

import (
	"context"
	"errors"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/jackc/pgx/v5/pgxpool"
)

type equipmentRepository struct {
	db *pgxpool.Pool
}

func NewEquipmentRepository(db *pgxpool.Pool) domain.EquipmentRepository {
	return &equipmentRepository{db: db}
}

func (r *equipmentRepository) FindAll() ([]domain.Equipment, error) {
	query := `
		SELECT e.id, e.company_id, e.name,
		       COALESCE(e.description,'') as description,
		       COALESCE(e.location_detail,'') as location_detail,
		       e.is_active, e.created_at,
		       COALESCE(c.name,'') as company_name
		FROM hydraulic_equipment e
		LEFT JOIN companies c ON e.company_id = c.id
		WHERE e.deleted_at IS NULL AND e.is_active = TRUE
		ORDER BY e.name ASC
	`
	return r.scanEquipments(query)
}

func (r *equipmentRepository) FindByCompanyID(companyID string) ([]domain.Equipment, error) {
	query := `
		SELECT e.id, e.company_id, e.name,
		       COALESCE(e.description,'') as description,
		       COALESCE(e.location_detail,'') as location_detail,
		       e.is_active, e.created_at,
		       COALESCE(c.name,'') as company_name
		FROM hydraulic_equipment e
		LEFT JOIN companies c ON e.company_id = c.id
		WHERE e.company_id = $1 AND e.deleted_at IS NULL AND e.is_active = TRUE
		ORDER BY e.name ASC
	`
	rows, err := r.db.Query(context.Background(), query, companyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return r.scan(rows)
}

func (r *equipmentRepository) Create(e *domain.Equipment) error {
	query := `
		INSERT INTO hydraulic_equipment
			(company_id, name, description, location_detail, type, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, 'General', TRUE, NOW(), NOW())
		RETURNING id, created_at
	`
	return r.db.QueryRow(context.Background(), query,
		e.CompanyID, 
		e.Name, 
		e.Description, 
		e.LocationDetail,
	).Scan(&e.ID, &e.CreatedAt)
}

func (r *equipmentRepository) FindByID(id string) (*domain.Equipment, error) {
	query := `
		SELECT e.id, e.company_id, e.name,
		       COALESCE(e.description,'') as description,
		       COALESCE(e.location_detail,'') as location_detail,
		       e.is_active, e.created_at,
		       COALESCE(c.name,'') as company_name
		FROM hydraulic_equipment e
		LEFT JOIN companies c ON e.company_id = c.id
		WHERE e.id = $1 AND e.deleted_at IS NULL
	`
	rows, err := r.db.Query(context.Background(), query, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	list, err := r.scan(rows)
	if err != nil || len(list) == 0 {
		return nil, errors.New("equipment tidak ditemukan")
	}
	return &list[0], nil
}

func (r *equipmentRepository) Delete(id string) error {
	_, err := r.db.Exec(context.Background(),
		`UPDATE hydraulic_equipment SET deleted_at = NOW(), is_active = FALSE WHERE id = $1`,
		id,
	)
	return err
}

func (r *equipmentRepository) Update(e *domain.Equipment) error {
	query := `
		UPDATE hydraulic_equipment
		SET name=$1, description=$2, location_detail=$3, updated_at=NOW()
		WHERE id=$4
	`
	_, err := r.db.Exec(context.Background(), query,
		e.Name, e.Description, e.LocationDetail, e.ID,
	)
	return err
}

func (r *equipmentRepository) scanEquipments(query string) ([]domain.Equipment, error) {
	rows, err := r.db.Query(context.Background(), query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return r.scan(rows)
}

func (r *equipmentRepository) scan(rows interface {
	Next() bool
	Scan(...interface{}) error
	Err() error
}) ([]domain.Equipment, error) {
	var equipments []domain.Equipment
	for rows.Next() {
		var e domain.Equipment
		err := rows.Scan(
			&e.ID, &e.CompanyID, &e.Name,
			&e.Description, &e.LocationDetail,
			&e.IsActive, &e.CreatedAt, &e.CompanyName,
		)
		if err != nil {
			return nil, err
		}
		equipments = append(equipments, e)
	}
	if equipments == nil {
		equipments = []domain.Equipment{}
	}
	return equipments, rows.Err()
}
