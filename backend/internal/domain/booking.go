package domain

import (
	"time"
)

type Booking struct {
	ID           string     `json:"id"`
	CompanyID    string     `json:"company_id"`
	CreatedBy    string     `json:"created_by"`
	TechnicianID *string    `json:"technician_id,omitempty"`
	EquipmentID  *string    `json:"equipment_id,omitempty"`
	ServiceType  string     `json:"service_type"`
	UrgencyLevel string     `json:"urgency_level"`
	Status       string     `json:"status"`
	Description  string     `json:"description"`
	SiteAddress  string     `json:"site_address"`
	SiteCity     string     `json:"site_city"`
	Latitude     *float64   `json:"latitude,omitempty"`
	Longitude    *float64   `json:"longitude,omitempty"`
	PhotoURLs    []string   `json:"photo_urls"`
	ScheduledAt  *time.Time `json:"scheduled_at,omitempty"`
	ClaimedAt    *time.Time `json:"claimed_at,omitempty"`
	StartedAt    *time.Time `json:"started_at,omitempty"`
	CompletedAt  *time.Time `json:"completed_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`

	// Relations
	CompanyName      string `json:"company_name,omitempty"`
	TechnicianName   string `json:"technician_name,omitempty"`
	EquipmentName    string `json:"equipment_name,omitempty"`
	CreatedByName    string `json:"created_by_name,omitempty"`
}

type CreateBookingRequest struct {
	CompanyID    string   `json:"company_id" binding:"required"`
	EquipmentID  string   `json:"equipment_id" binding:"required"`
	ServiceType  string   `json:"service_type" binding:"required,oneof=repair inspeksi maintenance"`
	UrgencyLevel string   `json:"urgency_level" binding:"required,oneof=emergency standard"`
	Description  string   `json:"description" binding:"required"`
	SiteAddress  string   `json:"site_address" binding:"required"`
	SiteCity     string   `json:"site_city" binding:"required"`
	Latitude     *float64 `json:"latitude"`
	Longitude    *float64 `json:"longitude"`
	PhotoURLs    []string `json:"photo_urls"`
	ScheduledAt  *string  `json:"scheduled_at"`
}

// Teknisi hanya bisa update ke on_the_way / on_site / cancelled.
// Status done hanya bisa dicapai via ConfirmJob oleh client/manager.
type UpdateStatusRequest struct {
	Status string `json:"status" binding:"required,oneof=on_the_way on_site cancelled"`
}

type BookingRepository interface {
	Create(booking *Booking) error
	FindAll(filters map[string]string) ([]Booking, error)
	FindByID(id string) (*Booking, error)
	FindByTechnicianID(technicianID string) ([]Booking, error)
	FindOpenBookings() ([]Booking, error)
	ClaimBooking(bookingID, technicianID string) error
	UpdateStatus(bookingID, technicianID, status string) error
	AssignTechnician(bookingID, technicianID string) error
	CancelBooking(bookingID string) error
	ConfirmJob(bookingID, userID string) error
}

type BookingUsecase interface {
	CreateBooking(userID, companyID string, req CreateBookingRequest) (*Booking, error)
	GetAllBookings(filters map[string]string) ([]Booking, error)
	GetBookingByID(id string) (*Booking, error)
	GetOpenBookings() ([]Booking, error)
	GetMyJobs(technicianID string) ([]Booking, error)
	ClaimBooking(bookingID, technicianID string) error
	UpdateStatus(bookingID, technicianID, status string) error
	AssignTechnician(bookingID, technicianID string) error
	CancelBooking(bookingID, userID, role string) error
	ConfirmJob(bookingID, userID, role string) error
}