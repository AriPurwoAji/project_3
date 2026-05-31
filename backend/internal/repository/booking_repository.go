package repository

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/jackc/pgx/v5/pgxpool"
)

type bookingRepository struct {
	db *pgxpool.Pool
}

func NewBookingRepository(db *pgxpool.Pool) domain.BookingRepository {
	return &bookingRepository{db: db}
}

func (r *bookingRepository) Create(b *domain.Booking) error {
	photoJSON, _ := json.Marshal(b.PhotoURLs)
	query := `
		INSERT INTO bookings 
			(company_id, created_by, equipment_id, service_type, urgency_level,
			 status, description, site_address, site_city, photo_urls, scheduled_at)
		VALUES ($1,$2,$3,$4,$5,'open',$6,$7,$8,$9,$10)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRow(context.Background(), query,
		b.CompanyID, b.CreatedBy, b.EquipmentID, b.ServiceType, b.UrgencyLevel,
		b.Description, b.SiteAddress, b.SiteCity, photoJSON, b.ScheduledAt,
	).Scan(&b.ID, &b.CreatedAt, &b.UpdatedAt)
}

func (r *bookingRepository) FindAll(filters map[string]string) ([]domain.Booking, error) {
	query := `
		SELECT b.id, b.company_id, b.created_by, b.technician_id, b.equipment_id,
			   b.service_type, b.urgency_level, b.status, b.description,
			   b.site_address, b.site_city, b.photo_urls,
			   b.scheduled_at, b.claimed_at, b.started_at, b.completed_at,
			   b.created_at, b.updated_at,
			   c.name as company_name,
			   COALESCE(u.full_name, '') as technician_name,
			   COALESCE(e.name, '') as equipment_name,
			   COALESCE(cu.full_name, '') as created_by_name
		FROM bookings b
		LEFT JOIN companies c ON b.company_id = c.id
		LEFT JOIN users u ON b.technician_id = u.id
		LEFT JOIN hydraulic_equipment e ON b.equipment_id = e.id
		LEFT JOIN users cu ON b.created_by = cu.id
		WHERE b.deleted_at IS NULL
	`
	args := []interface{}{}
	i := 1

	if status, ok := filters["status"]; ok && status != "" {
		query += ` AND b.status = $` + itoa(i)
		args = append(args, status)
		i++
	}
	if companyID, ok := filters["company_id"]; ok && companyID != "" {
		query += ` AND b.company_id = $` + itoa(i)
		args = append(args, companyID)
		i++
	}
	if techID, ok := filters["technician_id"]; ok && techID != "" {
		query += ` AND b.technician_id = $` + itoa(i)
		args = append(args, techID)
		i++
	}
	if createdBy, ok := filters["created_by"]; ok && createdBy != "" {
		query += ` AND b.created_by = $` + itoa(i)
		args = append(args, createdBy)
		i++
	}
	if serviceType, ok := filters["service_type"]; ok && serviceType != "" {
		query += ` AND b.service_type = $` + itoa(i)
		args = append(args, serviceType)
		i++
	}

	query += ` ORDER BY b.created_at DESC`

	if limit, ok := filters["limit"]; ok && limit != "" {
		query += ` LIMIT $` + itoa(i)
		args = append(args, limit)
		i++
	}
	if offset, ok := filters["offset"]; ok && offset != "" {
		query += ` OFFSET $` + itoa(i)
		args = append(args, offset)
		i++
	}
	_ = i

	rows, err := r.db.Query(context.Background(), query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanBookings(rows)
}

func (r *bookingRepository) FindByID(id string) (*domain.Booking, error) {
	query := `
		SELECT b.id, b.company_id, b.created_by, b.technician_id, b.equipment_id,
			   b.service_type, b.urgency_level, b.status, b.description,
			   b.site_address, b.site_city, b.photo_urls,
			   b.scheduled_at, b.claimed_at, b.started_at, b.completed_at,
			   b.created_at, b.updated_at,
			   c.name as company_name,
			   COALESCE(u.full_name, '') as technician_name,
			   COALESCE(e.name, '') as equipment_name,
			   COALESCE(cu.full_name, '') as created_by_name
		FROM bookings b
		LEFT JOIN companies c ON b.company_id = c.id
		LEFT JOIN users u ON b.technician_id = u.id
		LEFT JOIN hydraulic_equipment e ON b.equipment_id = e.id
		LEFT JOIN users cu ON b.created_by = cu.id
		WHERE b.id = $1 AND b.deleted_at IS NULL
	`
	rows, err := r.db.Query(context.Background(), query, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	bookings, err := scanBookings(rows)
	if err != nil || len(bookings) == 0 {
		return nil, errors.New("booking tidak ditemukan")
	}
	return &bookings[0], nil
}

func (r *bookingRepository) FindByTechnicianID(technicianID string) ([]domain.Booking, error) {
	return r.FindAll(map[string]string{"technician_id": technicianID})
}

func (r *bookingRepository) FindOpenBookings() ([]domain.Booking, error) {
	return r.FindAll(map[string]string{"status": "open"})
}

func (r *bookingRepository) ClaimBooking(bookingID, technicianID string) error {
	query := `
		UPDATE bookings 
		SET technician_id = $1, status = 'in_progress', 
		    claimed_at = NOW(), updated_at = NOW()
		WHERE id = $2 AND status = 'open' AND deleted_at IS NULL
	`
	result, err := r.db.Exec(context.Background(), query, technicianID, bookingID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return errors.New("job sudah diambil oleh teknisi lain")
	}

	// Log status change
	r.logStatus(bookingID, technicianID, "open", "in_progress")
	return nil
}

func (r *bookingRepository) UpdateStatus(bookingID, technicianID, status string) error {
	var timeField string
	switch status {
	case "on_site":
		timeField = ", started_at = NOW()"
	case "done":
		timeField = ", completed_at = NOW()"
	}

	query := `
		UPDATE bookings 
		SET status = $1, updated_at = NOW()` + timeField + `
		WHERE id = $2 AND technician_id = $3 AND deleted_at IS NULL
	`
	_, err := r.db.Exec(context.Background(), query, status, bookingID, technicianID)
	if err != nil {
		return err
	}

	r.logStatus(bookingID, technicianID, "", status)
	return nil
}

func (r *bookingRepository) AssignTechnician(bookingID, technicianID string) error {
	query := `
		UPDATE bookings 
		SET technician_id = $1, status = 'in_progress',
		    claimed_at = NOW(), updated_at = NOW()
		WHERE id = $2 AND deleted_at IS NULL
	`
	_, err := r.db.Exec(context.Background(), query, technicianID, bookingID)
	if err != nil {
		return err
	}
	r.logStatus(bookingID, technicianID, "open", "in_progress")
	return nil
}

func (r *bookingRepository) CancelBooking(bookingID string) error {
	query := `
		UPDATE bookings SET status = 'cancelled', updated_at = NOW()
		WHERE id = $1 AND status = 'open' AND deleted_at IS NULL
	`
	result, err := r.db.Exec(context.Background(), query, bookingID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return errors.New("booking tidak dapat dibatalkan (sudah diproses atau tidak ditemukan)")
	}
	r.logStatus(bookingID, "", "open", "cancelled")
	return nil
}

func (r *bookingRepository) logStatus(bookingID, changedBy, from, to string) {
	query := `
		INSERT INTO booking_status_logs (booking_id, changed_by, from_status, to_status)
		VALUES ($1, $2, $3, $4)
	`
	r.db.Exec(context.Background(), query, bookingID, changedBy, from, to)
}

// helpers
func itoa(i int) string {
	return string(rune('0' + i))
}

func scanBookings(rows interface{ Next() bool; Scan(...interface{}) error; Err() error }) ([]domain.Booking, error) {
	var bookings []domain.Booking
	for rows.Next() {
		var b domain.Booking
		var photoJSON []byte
		var techID, equipID *string
		var scheduledAt, claimedAt, startedAt, completedAt *time.Time

		err := rows.Scan(
			&b.ID, &b.CompanyID, &b.CreatedBy, &techID, &equipID,
			&b.ServiceType, &b.UrgencyLevel, &b.Status, &b.Description,
			&b.SiteAddress, &b.SiteCity, &photoJSON,
			&scheduledAt, &claimedAt, &startedAt, &completedAt,
			&b.CreatedAt, &b.UpdatedAt,
			&b.CompanyName, &b.TechnicianName, &b.EquipmentName, &b.CreatedByName,
		)
		if err != nil {
			return nil, err
		}

		b.TechnicianID = techID
		b.EquipmentID = equipID
		b.ScheduledAt = scheduledAt
		b.ClaimedAt = claimedAt
		b.StartedAt = startedAt
		b.CompletedAt = completedAt

		if photoJSON != nil {
			json.Unmarshal(photoJSON, &b.PhotoURLs)
		}
		if b.PhotoURLs == nil {
			b.PhotoURLs = []string{}
		}

		bookings = append(bookings, b)
	}
	return bookings, rows.Err()
}