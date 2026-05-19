package domain

type DashboardSummary struct {
	TotalBookings     int     `json:"total_bookings"`
	CompletedBookings int     `json:"completed_bookings"`
	OpenBookings      int     `json:"open_bookings"`
	InProgressBookings int    `json:"in_progress_bookings"`
	CompletionRate    float64 `json:"completion_rate"`
	AvgCompletionHours float64 `json:"avg_completion_hours"`
}

type TechnicianPerformance struct {
	TechnicianID   string  `json:"technician_id"`
	TechnicianName string  `json:"technician_name"`
	TotalJobs      int     `json:"total_jobs"`
	CompletedJobs  int     `json:"completed_jobs"`
}

type ServiceTypeTrend struct {
	ServiceType string `json:"service_type"`
	Total       int    `json:"total"`
}

type DashboardRepository interface {
	GetSummary(filters map[string]string) (*DashboardSummary, error)
	GetTechnicianPerformance() ([]TechnicianPerformance, error)
	GetServiceTypeTrend(filters map[string]string) ([]ServiceTypeTrend, error)
}

type DashboardUsecase interface {
	GetSummary(filters map[string]string) (*DashboardSummary, error)
	GetTechnicianPerformance() ([]TechnicianPerformance, error)
	GetServiceTypeTrend(filters map[string]string) ([]ServiceTypeTrend, error)
}