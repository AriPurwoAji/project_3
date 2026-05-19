package repository

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/jackc/pgx/v5/pgxpool"
)

type reportRepository struct {
	db *pgxpool.Pool
}

func NewReportRepository(db *pgxpool.Pool) domain.ReportRepository {
	return &reportRepository{db: db}
}

func (r *reportRepository) Create(report *domain.HydraulicReport) error {
	partsJSON, _ := json.Marshal(report.PartsReplaced)
	photosJSON, _ := json.Marshal(report.PhotoURLs)

	query := `
		INSERT INTO hydraulic_reports
			(booking_id, technician_id, pressure_before_bar, pressure_after_bar,
			 oil_condition, oil_level, leak_location, leak_severity,
			 parts_replaced, photo_urls, work_description, recommendations)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRow(context.Background(), query,
		report.BookingID, report.TechnicianID,
		report.PressureBeforeBar, report.PressureAfterBar,
		report.OilCondition, report.OilLevel,
		report.LeakLocation, report.LeakSeverity,
		partsJSON, photosJSON,
		report.WorkDescription, report.Recommendations,
	).Scan(&report.ID, &report.CreatedAt, &report.UpdatedAt)
}

func (r *reportRepository) CreateInspectionItems(items []domain.InspectionItem) error {
	for _, item := range items {
		specsJSON, _ := json.Marshal(item.Specifications)
		query := `
			INSERT INTO inspection_items
				(report_id, item_type, item_code, location_desc,
				 specifications, condition, recommendation, photo_url, notes)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
		`
		_, err := r.db.Exec(context.Background(), query,
			item.ReportID, item.ItemType, item.ItemCode, item.LocationDesc,
			specsJSON, item.Condition, item.Recommendation,
			item.PhotoURL, item.Notes,
		)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *reportRepository) FindByBookingID(bookingID string) (*domain.HydraulicReport, error) {
	query := `
		SELECT r.id, r.booking_id, r.technician_id,
			   r.pressure_before_bar, r.pressure_after_bar,
			   r.oil_condition, r.oil_level, r.leak_location, r.leak_severity,
			   r.parts_replaced, r.photo_urls, r.pdf_url,
			   r.work_description, r.recommendations,
			   r.created_at, r.updated_at,
			   COALESCE(u.full_name, '') as technician_name
		FROM hydraulic_reports r
		LEFT JOIN users u ON r.technician_id = u.id
		WHERE r.booking_id = $1
	`
	report, err := r.scanReport(query, bookingID)
	if err != nil {
		return nil, errors.New("laporan tidak ditemukan")
	}

	// Load inspection items
	items, _ := r.findInspectionItems(report.ID)
	report.InspectionItems = items

	return report, nil
}

func (r *reportRepository) FindByID(id string) (*domain.HydraulicReport, error) {
	query := `
		SELECT r.id, r.booking_id, r.technician_id,
			   r.pressure_before_bar, r.pressure_after_bar,
			   r.oil_condition, r.oil_level, r.leak_location, r.leak_severity,
			   r.parts_replaced, r.photo_urls, r.pdf_url,
			   r.work_description, r.recommendations,
			   r.created_at, r.updated_at,
			   COALESCE(u.full_name, '') as technician_name
		FROM hydraulic_reports r
		LEFT JOIN users u ON r.technician_id = u.id
		WHERE r.id = $1
	`
	report, err := r.scanReport(query, id)
	if err != nil {
		return nil, errors.New("laporan tidak ditemukan")
	}

	items, _ := r.findInspectionItems(report.ID)
	report.InspectionItems = items

	return report, nil
}

func (r *reportRepository) FindByTechnicianID(technicianID string) ([]domain.HydraulicReport, error) {
	query := `
		SELECT r.id, r.booking_id, r.technician_id,
			   r.pressure_before_bar, r.pressure_after_bar,
			   r.oil_condition, r.oil_level, r.leak_location, r.leak_severity,
			   r.parts_replaced, r.photo_urls, r.pdf_url,
			   r.work_description, r.recommendations,
			   r.created_at, r.updated_at,
			   COALESCE(u.full_name, '') as technician_name
		FROM hydraulic_reports r
		LEFT JOIN users u ON r.technician_id = u.id
		WHERE r.technician_id = $1
		ORDER BY r.created_at DESC
	`
	rows, err := r.db.Query(context.Background(), query, technicianID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reports []domain.HydraulicReport
	for rows.Next() {
		report := &domain.HydraulicReport{}
		if err := r.scanReportRow(rows, report); err != nil {
			continue
		}
		items, _ := r.findInspectionItems(report.ID)
		report.InspectionItems = items
		reports = append(reports, *report)
	}
	return reports, nil
}

func (r *reportRepository) UpdatePDFUrl(reportID, pdfURL string) error {
	query := `UPDATE hydraulic_reports SET pdf_url = $1, updated_at = NOW() WHERE id = $2`
	_, err := r.db.Exec(context.Background(), query, pdfURL, reportID)
	return err
}

func (r *reportRepository) findInspectionItems(reportID string) ([]domain.InspectionItem, error) {
	query := `
		SELECT id, report_id, item_type, item_code, location_desc,
			   specifications, condition, recommendation, photo_url, notes, created_at
		FROM inspection_items
		WHERE report_id = $1
		ORDER BY created_at ASC
	`
	rows, err := r.db.Query(context.Background(), query, reportID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []domain.InspectionItem
	for rows.Next() {
		var item domain.InspectionItem
		var specsJSON []byte
		err := rows.Scan(
			&item.ID, &item.ReportID, &item.ItemType, &item.ItemCode,
			&item.LocationDesc, &specsJSON, &item.Condition,
			&item.Recommendation, &item.PhotoURL, &item.Notes, &item.CreatedAt,
		)
		if err != nil {
			continue
		}
		if specsJSON != nil {
			json.Unmarshal(specsJSON, &item.Specifications)
		}
		items = append(items, item)
	}
	return items, nil
}

func (r *reportRepository) scanReport(query, arg string) (*domain.HydraulicReport, error) {
	row := r.db.QueryRow(context.Background(), query, arg)
	report := &domain.HydraulicReport{}
	return report, r.scanReportRow(row, report)
}

func (r *reportRepository) scanReportRow(row interface{ Scan(...interface{}) error }, report *domain.HydraulicReport) error {
	var partsJSON, photosJSON []byte
	err := row.Scan(
		&report.ID, &report.BookingID, &report.TechnicianID,
		&report.PressureBeforeBar, &report.PressureAfterBar,
		&report.OilCondition, &report.OilLevel,
		&report.LeakLocation, &report.LeakSeverity,
		&partsJSON, &photosJSON, &report.PDFUrl,
		&report.WorkDescription, &report.Recommendations,
		&report.CreatedAt, &report.UpdatedAt,
		&report.TechnicianName,
	)
	if err != nil {
		return err
	}
	if partsJSON != nil {
		json.Unmarshal(partsJSON, &report.PartsReplaced)
	}
	if photosJSON != nil {
		json.Unmarshal(photosJSON, &report.PhotoURLs)
	}
	if report.PartsReplaced == nil {
		report.PartsReplaced = []domain.PartReplaced{}
	}
	if report.PhotoURLs == nil {
		report.PhotoURLs = []domain.ReportPhoto{}
	}
	if report.InspectionItems == nil {
		report.InspectionItems = []domain.InspectionItem{}
	}
	return nil
}