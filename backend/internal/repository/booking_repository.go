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
			(company_id, created_by, equipment_id, equipment_id_2, service_type, urgency_level,
			 status, description, site_address, site_city, photo_urls, scheduled_at,
			 latitude, longitude, reference_booking_id)
		VALUES ($1,$2,$3,$4,$5,$6,'open',$7,$8,$9,$10,$11,$12,$13,$14)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRow(context.Background(), query,
		b.CompanyID, b.CreatedBy, b.EquipmentID, b.EquipmentID2, b.ServiceType, b.UrgencyLevel,
		b.Description, b.SiteAddress, b.SiteCity, photoJSON, b.ScheduledAt,
		b.Latitude, b.Longitude, b.ReferenceBookingID,
	).Scan(&b.ID, &b.CreatedAt, &b.UpdatedAt)
}

func (r *bookingRepository) FindAll(filters map[string]string) ([]domain.Booking, error) {
	query := `
		SELECT b.id, b.company_id, b.created_by, b.technician_id, b.equipment_id,
			   b.service_type, b.urgency_level, b.status, b.description,
			   b.site_address, b.site_city, b.photo_urls,
			   b.scheduled_at, b.claimed_at, b.started_at, b.completed_at,
			   b.created_at, b.updated_at,
			   b.latitude, b.longitude,
			   c.name as company_name,
			   COALESCE(u.full_name, '') as technician_name,
			   COALESCE(e.name, '') as equipment_name,
			   COALESCE(cu.full_name, '') as created_by_name,
			   b.reference_booking_id,
			   b.equipment_id_2, b.work_equipment_id,
			   COALESCE(e2.name, '') as equipment_name_2,
			   COALESCE(ew.name, '') as work_equipment_name,
			   COALESCE(b.done_equipment_ids, ARRAY[]::UUID[]) as done_equipment_ids
		FROM bookings b
		LEFT JOIN companies c ON b.company_id = c.id
		LEFT JOIN users u ON b.technician_id = u.id
		LEFT JOIN hydraulic_equipment e ON b.equipment_id = e.id
		LEFT JOIN hydraulic_equipment e2 ON b.equipment_id_2 = e2.id
		LEFT JOIN hydraulic_equipment ew ON b.work_equipment_id = ew.id
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
			   b.latitude, b.longitude,
			   c.name as company_name,
			   COALESCE(u.full_name, '') as technician_name,
			   COALESCE(e.name, '') as equipment_name,
			   COALESCE(cu.full_name, '') as created_by_name,
			   b.reference_booking_id,
			   b.equipment_id_2, b.work_equipment_id,
			   COALESCE(e2.name, '') as equipment_name_2,
			   COALESCE(ew.name, '') as work_equipment_name,
			   COALESCE(b.done_equipment_ids, ARRAY[]::UUID[]) as done_equipment_ids
		FROM bookings b
		LEFT JOIN companies c ON b.company_id = c.id
		LEFT JOIN users u ON b.technician_id = u.id
		LEFT JOIN hydraulic_equipment e ON b.equipment_id = e.id
		LEFT JOIN hydraulic_equipment e2 ON b.equipment_id_2 = e2.id
		LEFT JOIN hydraulic_equipment ew ON b.work_equipment_id = ew.id
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

func (r *bookingRepository) ClaimBooking(bookingID, technicianID string, workEquipmentID *string) error {
	query := `
		UPDATE bookings
		SET technician_id = $1, status = 'in_progress', work_equipment_id = $2,
		    claimed_at = NOW(), updated_at = NOW()
		WHERE id = $3 AND status = 'open' AND deleted_at IS NULL
	`
	result, err := r.db.Exec(context.Background(), query, technicianID, workEquipmentID, bookingID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return errors.New("job sudah diambil oleh teknisi lain")
	}

	r.logStatus(bookingID, technicianID, "open", "in_progress")
	return nil
}

func (r *bookingRepository) UpdateStatus(bookingID, technicianID, status string) error {
	var timeField string
	switch status {
	case "on_site":
		timeField = ", started_at = NOW()"
	case "waiting_confirmation":
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

func (r *bookingRepository) ConfirmJob(bookingID, userID string) error {
	query := `
		UPDATE bookings
		SET status = 'done', updated_at = NOW()
		WHERE id = $1 AND status = 'waiting_confirmation' AND deleted_at IS NULL
	`
	result, err := r.db.Exec(context.Background(), query, bookingID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return errors.New("booking tidak dapat dikonfirmasi (status bukan waiting_confirmation atau tidak ditemukan)")
	}
	r.logStatus(bookingID, userID, "waiting_confirmation", "done")
	return nil
}

func (r *bookingRepository) ForceUpdateStatus(bookingID, status string) error {
	_, err := r.db.Exec(context.Background(),
		`UPDATE bookings SET status = $1, updated_at = NOW() WHERE id = $2`,
		status, bookingID)
	return err
}

func (r *bookingRepository) RejectJob(bookingID string, reportID *string, reason string) error {
	result, err := r.db.Exec(context.Background(), `
		UPDATE bookings
		SET status = 'needs_revision', updated_at = NOW()
		WHERE id = $1 AND status = 'waiting_confirmation' AND deleted_at IS NULL
	`, bookingID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return errors.New("booking tidak dapat ditolak (status bukan waiting_confirmation atau tidak ditemukan)")
	}
	r.logStatus(bookingID, "", "waiting_confirmation", "needs_revision")

	// Update status laporan ke 'rejected' dan simpan alasan penolakan
	if reportID != nil && *reportID != "" {
		_, err = r.db.Exec(context.Background(),
			`UPDATE hydraulic_reports SET status='rejected', rejection_reason=$1 WHERE id=$2`,
			reason, *reportID)
	} else {
		_, err = r.db.Exec(context.Background(),
			`UPDATE hydraulic_reports SET status='rejected', rejection_reason=$1 WHERE booking_id=$2 AND status='submitted'`,
			reason, bookingID)
	}
	return err
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
		var techID, equipID, refBookingID, equipID2, workEquipID *string
		var scheduledAt, claimedAt, startedAt, completedAt *time.Time

		err := rows.Scan(
			&b.ID, &b.CompanyID, &b.CreatedBy, &techID, &equipID,
			&b.ServiceType, &b.UrgencyLevel, &b.Status, &b.Description,
			&b.SiteAddress, &b.SiteCity, &photoJSON,
			&scheduledAt, &claimedAt, &startedAt, &completedAt,
			&b.CreatedAt, &b.UpdatedAt,
			&b.Latitude, &b.Longitude,
			&b.CompanyName, &b.TechnicianName, &b.EquipmentName, &b.CreatedByName,
			&refBookingID,
			&equipID2, &workEquipID,
			&b.EquipmentName2, &b.WorkEquipmentName,
			&b.DoneEquipmentIDs,
		)
		if err != nil {
			return nil, err
		}

		b.TechnicianID       = techID
		b.EquipmentID        = equipID
		b.EquipmentID2       = equipID2
		b.WorkEquipmentID    = workEquipID
		b.ReferenceBookingID = refBookingID
		b.ScheduledAt        = scheduledAt
		b.ClaimedAt          = claimedAt
		b.StartedAt          = startedAt
		b.CompletedAt        = completedAt

		if photoJSON != nil {
			json.Unmarshal(photoJSON, &b.PhotoURLs)
		}
		if b.PhotoURLs == nil {
			b.PhotoURLs = []string{}
		}
		if b.DoneEquipmentIDs == nil {
			b.DoneEquipmentIDs = []string{}
		}

		bookings = append(bookings, b)
	}
	return bookings, rows.Err()
}

func (r *bookingRepository) CreateBookingItems(bookingID string, items []string) error {
	for i, desc := range items {
		if desc == "" {
			continue
		}
		_, err := r.db.Exec(context.Background(),
			`INSERT INTO booking_items (booking_id, description, sort_order) VALUES ($1, $2, $3)`,
			bookingID, desc, i,
		)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *bookingRepository) GetBookingItems(bookingID string) ([]domain.BookingItem, error) {
	rows, err := r.db.Query(context.Background(),
		`SELECT id, booking_id, description, sort_order, is_done, created_at
		 FROM booking_items
		 WHERE booking_id = $1
		 ORDER BY sort_order ASC, created_at ASC`,
		bookingID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []domain.BookingItem
	for rows.Next() {
		var it domain.BookingItem
		if err := rows.Scan(&it.ID, &it.BookingID, &it.Description,
			&it.SortOrder, &it.IsDone, &it.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	if items == nil {
		items = []domain.BookingItem{}
	}
	return items, rows.Err()
}

func (r *bookingRepository) ToggleBookingItem(itemID string, isDone bool) error {
	_, err := r.db.Exec(context.Background(),
		`UPDATE booking_items SET is_done = $1 WHERE id = $2`,
		isDone, itemID,
	)
	return err
}

func (r *bookingRepository) MarkEquipmentDone(bookingID, equipmentID string, done bool) error {
	var query string
	if done {
		query = `
			UPDATE bookings
			SET done_equipment_ids = array_append(
			    COALESCE(done_equipment_ids, ARRAY[]::UUID[]),
			    $2::UUID
			), updated_at = NOW()
			WHERE id = $1
			  AND NOT ($2::UUID = ANY(COALESCE(done_equipment_ids, ARRAY[]::UUID[])))
			  AND deleted_at IS NULL
		`
	} else {
		query = `
			UPDATE bookings
			SET done_equipment_ids = array_remove(
			    COALESCE(done_equipment_ids, ARRAY[]::UUID[]),
			    $2::UUID
			), updated_at = NOW()
			WHERE id = $1 AND deleted_at IS NULL
		`
	}
	_, err := r.db.Exec(context.Background(), query, bookingID, equipmentID)
	return err
}

func (r *bookingRepository) GetAvailableReferences(companyID string) ([]domain.AvailableReference, error) {
	query := `
		SELECT b.id, b.service_type, b.description,
		       COALESCE(e.name, '') as equipment_name, b.created_at
		FROM bookings b
		LEFT JOIN hydraulic_equipment e ON b.equipment_id = e.id
		WHERE b.company_id = $1
		  AND b.status = 'done'
		  AND b.service_type IN ('inspeksi', 'maintenance')
		  AND NOT EXISTS (
		      SELECT 1 FROM bookings b2
		      WHERE b2.reference_booking_id = b.id
		        AND b2.deleted_at IS NULL
		  )
		  AND b.deleted_at IS NULL
		ORDER BY b.created_at DESC
	`
	rows, err := r.db.Query(context.Background(), query, companyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var refs []domain.AvailableReference
	for rows.Next() {
		var ref domain.AvailableReference
		if err := rows.Scan(&ref.ID, &ref.ServiceType, &ref.Description,
			&ref.EquipmentName, &ref.CreatedAt); err != nil {
			return nil, err
		}
		refs = append(refs, ref)
	}
	if refs == nil {
		refs = []domain.AvailableReference{}
	}
	return refs, rows.Err()
}