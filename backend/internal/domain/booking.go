package domain

import (
	"time"
)

type BookingItem struct {
	ID          string    `json:"id"`
	BookingID   string    `json:"booking_id"`
	Description string    `json:"description"`
	SortOrder   int       `json:"sort_order"`
	IsDone      bool      `json:"is_done"`
	CreatedAt   time.Time `json:"created_at"`
}

type Booking struct {
	ID                  string     `json:"id"`
	CompanyID           string     `json:"company_id"`
	CreatedBy           string     `json:"created_by"`
	TechnicianID        *string    `json:"technician_id,omitempty"`
	EquipmentID         *string    `json:"equipment_id,omitempty"`
	EquipmentID2        *string    `json:"equipment_id_2,omitempty"`
	WorkEquipmentID     *string    `json:"work_equipment_id,omitempty"`
	DoneEquipmentIDs    []string   `json:"done_equipment_ids"`
	ReferenceBookingID  *string    `json:"reference_booking_id,omitempty"`
	ServiceType         string     `json:"service_type"`
	UrgencyLevel        string     `json:"urgency_level"`
	Status              string     `json:"status"`
	Description         string     `json:"description"`
	SiteAddress         string     `json:"site_address"`
	SiteCity            string     `json:"site_city"`
	Latitude            *float64   `json:"latitude,omitempty"`
	Longitude           *float64   `json:"longitude,omitempty"`
	PhotoURLs           []string   `json:"photo_urls"`
	ScheduledAt         *time.Time `json:"scheduled_at,omitempty"`
	ClaimedAt           *time.Time `json:"claimed_at,omitempty"`
	StartedAt           *time.Time `json:"started_at,omitempty"`
	CompletedAt         *time.Time `json:"completed_at,omitempty"`
	CreatedAt           time.Time  `json:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at"`

	// Relations
	CompanyName       string        `json:"company_name,omitempty"`
	TechnicianName    string        `json:"technician_name,omitempty"`
	EquipmentName     string        `json:"equipment_name,omitempty"`
	EquipmentName2    string        `json:"equipment_name_2,omitempty"`
	WorkEquipmentName string        `json:"work_equipment_name,omitempty"`
	CreatedByName     string        `json:"created_by_name,omitempty"`
	Items             []BookingItem `json:"items"`
}

type AvailableReference struct {
	ID            string    `json:"id"`
	ServiceType   string    `json:"service_type"`
	Description   string    `json:"description"`
	EquipmentName string    `json:"equipment_name,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
}

type CreateBookingRequest struct {
	CompanyID           string   `json:"company_id" binding:"required"`
	EquipmentID         string   `json:"equipment_id" binding:"required"`
	EquipmentID2        *string  `json:"equipment_id_2"`
	ServiceType         string   `json:"service_type" binding:"required,oneof=repair inspeksi maintenance"`
	UrgencyLevel        string   `json:"urgency_level" binding:"required,oneof=emergency standard"`
	Description         string   `json:"description" binding:"required"`
	SiteAddress         string   `json:"site_address" binding:"required"`
	SiteCity            string   `json:"site_city" binding:"required"`
	Latitude            *float64 `json:"latitude"`
	Longitude           *float64 `json:"longitude"`
	PhotoURLs           []string `json:"photo_urls"`
	ScheduledAt         *string  `json:"scheduled_at"`
	ReferenceBookingID  *string  `json:"reference_booking_id"`
	// Daftar item/tugas untuk inspeksi atau maintenance
	Items               []string `json:"items"`
}

type ClaimBookingRequest struct {
	WorkEquipmentID *string `json:"work_equipment_id"`
}

// Teknisi hanya bisa update ke on_the_way / on_site / cancelled.
// Status done hanya bisa dicapai via ConfirmJob oleh client/manager.
type UpdateStatusRequest struct {
	Status string `json:"status" binding:"required,oneof=on_the_way on_site cancelled"`
}

type MarkEquipmentDoneRequest struct {
	EquipmentID string `json:"equipment_id" binding:"required"`
	Done        bool   `json:"done"`
}

type RejectBookingRequest struct {
	Reason   string  `json:"reason"    binding:"required"`
	ReportID *string `json:"report_id"` // opsional: tolak laporan tertentu saja
}

type ToggleBookingItemRequest struct {
	IsDone bool `json:"is_done"`
}

type BookingRepository interface {
	Create(booking *Booking) error
	FindAll(filters map[string]string) ([]Booking, error)
	FindByID(id string) (*Booking, error)
	FindByTechnicianID(technicianID string) ([]Booking, error)
	FindOpenBookings() ([]Booking, error)
	ClaimBooking(bookingID, technicianID string, workEquipmentID *string) error
	UpdateStatus(bookingID, technicianID, status string) error
	ForceUpdateStatus(bookingID, status string) error
	AssignTechnician(bookingID, technicianID string) error
	CancelBooking(bookingID string) error
	ConfirmJob(bookingID, userID string) error
	RejectJob(bookingID string, reportID *string, reason string) error
	GetAvailableReferences(companyID string) ([]AvailableReference, error)
	MarkEquipmentDone(bookingID, equipmentID string, done bool) error
	CreateBookingItems(bookingID string, items []string) error
	GetBookingItems(bookingID string) ([]BookingItem, error)
	ToggleBookingItem(itemID string, isDone bool) error
}

type BookingUsecase interface {
	CreateBooking(userID, companyID string, req CreateBookingRequest) (*Booking, error)
	GetAllBookings(filters map[string]string) ([]Booking, error)
	GetBookingByID(id string) (*Booking, error)
	GetOpenBookings() ([]Booking, error)
	GetMyJobs(technicianID string) ([]Booking, error)
	ClaimBooking(bookingID, technicianID string, workEquipmentID *string) error
	UpdateStatus(bookingID, technicianID, status string) error
	AssignTechnician(bookingID, technicianID string) error
	CancelBooking(bookingID, userID, role string) error
	ConfirmJob(bookingID, userID, role string) error
	RejectJob(bookingID, userID, role, reason string, reportID *string) error
	GetAvailableReferences(companyID string) ([]AvailableReference, error)
	MarkEquipmentDone(bookingID, technicianID, equipmentID string, done bool) error
	GetBookingItems(bookingID string) ([]BookingItem, error)
	ToggleBookingItem(bookingID, itemID, technicianID string, isDone bool) error
}