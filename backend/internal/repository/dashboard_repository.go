package repository

import (
	"context"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/jackc/pgx/v5/pgxpool"
)

type dashboardRepository struct {
	db *pgxpool.Pool
}

func NewDashboardRepository(db *pgxpool.Pool) domain.DashboardRepository {
	return &dashboardRepository{db: db}
}

func (r *dashboardRepository) GetSummary(filters map[string]string) (*domain.DashboardSummary, error) {
	query := `
		SELECT
			COUNT(*) as total,
			COUNT(*) FILTER (WHERE status = 'done') as completed,
			COUNT(*) FILTER (WHERE status = 'open') as open,
			COUNT(*) FILTER (WHERE status IN ('in_progress','on_the_way','on_site')) as in_progress,
			COALESCE(
				ROUND(AVG(
					EXTRACT(EPOCH FROM (completed_at - claimed_at)) / 3600
				) FILTER (WHERE status = 'done' AND completed_at IS NOT NULL), 0
				), 0
			) as avg_hours
		FROM bookings
		WHERE deleted_at IS NULL
	`
	var s domain.DashboardSummary
	var avgHours float64
	err := r.db.QueryRow(context.Background(), query).Scan(
		&s.TotalBookings,
		&s.CompletedBookings,
		&s.OpenBookings,
		&s.InProgressBookings,
		&avgHours,
	)
	if err != nil {
		return nil, err
	}
	s.AvgCompletionHours = avgHours
	if s.TotalBookings > 0 {
		s.CompletionRate = float64(s.CompletedBookings) / float64(s.TotalBookings) * 100
	}
	return &s, nil
}

func (r *dashboardRepository) GetTechnicianPerformance() ([]domain.TechnicianPerformance, error) {
	query := `
		SELECT 
			u.id, u.full_name,
			COUNT(b.id) as total_jobs,
			COUNT(b.id) FILTER (WHERE b.status = 'done') as completed_jobs
		FROM users u
		LEFT JOIN bookings b ON u.id = b.technician_id AND b.deleted_at IS NULL
		WHERE u.role = 'teknisi' AND u.is_active = TRUE AND u.deleted_at IS NULL
		GROUP BY u.id, u.full_name
		ORDER BY completed_jobs DESC
	`
	rows, err := r.db.Query(context.Background(), query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []domain.TechnicianPerformance
	for rows.Next() {
		var p domain.TechnicianPerformance
		rows.Scan(&p.TechnicianID, &p.TechnicianName, &p.TotalJobs, &p.CompletedJobs)
		result = append(result, p)
	}
	if result == nil {
		result = []domain.TechnicianPerformance{}
	}
	return result, nil
}

func (r *dashboardRepository) GetServiceTypeTrend(filters map[string]string) ([]domain.ServiceTypeTrend, error) {
	query := `
		SELECT service_type, COUNT(*) as total
		FROM bookings
		WHERE deleted_at IS NULL
		GROUP BY service_type
		ORDER BY total DESC
	`
	rows, err := r.db.Query(context.Background(), query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []domain.ServiceTypeTrend
	for rows.Next() {
		var t domain.ServiceTypeTrend
		rows.Scan(&t.ServiceType, &t.Total)
		result = append(result, t)
	}
	if result == nil {
		result = []domain.ServiceTypeTrend{}
	}
	return result, nil
}