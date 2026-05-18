package domain

import "time"

type HydraulicReport struct {
	ID                string          `json:"id"`
	BookingID         string          `json:"booking_id"`
	TechnicianID      string          `json:"technician_id"`
	PressureBeforeBar *int            `json:"pressure_before_bar,omitempty"`
	PressureAfterBar  *int            `json:"pressure_after_bar,omitempty"`
	OilCondition      *string         `json:"oil_condition,omitempty"`
	OilLevel          *string         `json:"oil_level,omitempty"`
	LeakLocation      *string         `json:"leak_location,omitempty"`
	LeakSeverity      *string         `json:"leak_severity,omitempty"`
	PartsReplaced     []PartReplaced  `json:"parts_replaced"`
	PhotoURLs         []ReportPhoto   `json:"photo_urls"`
	PDFUrl            *string         `json:"pdf_url,omitempty"`
	WorkDescription   string          `json:"work_description"`
	Recommendations   string          `json:"recommendations"`
	CreatedAt         time.Time       `json:"created_at"`
	UpdatedAt         time.Time       `json:"updated_at"`

	// Relations
	InspectionItems []InspectionItem `json:"inspection_items,omitempty"`
	TechnicianName  string           `json:"technician_name,omitempty"`
	BookingInfo     *Booking         `json:"booking_info,omitempty"`
}

type PartReplaced struct {
	Name       string `json:"name"`
	PartNumber string `json:"part_number"`
	Qty        int    `json:"qty"`
}

type ReportPhoto struct {
	URL  string `json:"url"`
	Type string `json:"type"` // before | after | damage
}

type InspectionItem struct {
	ID             string                 `json:"id"`
	ReportID       string                 `json:"report_id"`
	ItemType       string                 `json:"item_type"` // hose | cylinder | pump
	ItemCode       string                 `json:"item_code"`
	LocationDesc   string                 `json:"location_desc"`
	Specifications map[string]interface{} `json:"specifications"`
	Condition      string                 `json:"condition"`
	Recommendation string                 `json:"recommendation"`
	PhotoURL       *string                `json:"photo_url,omitempty"`
	Notes          string                 `json:"notes"`
	CreatedAt      time.Time              `json:"created_at"`
}

// Fitting untuk hose
type HoseFitting struct {
	Standard string `json:"standard"` // ORFS|BSP|NPT|JIC|Metric|SAE_F61|SAE_F62
	Angle    string `json:"angle"`    // straight|45|90|90_long
	Gender   string `json:"gender"`   // male|female
}

// Request structs
type CreateReportRequest struct {
	WorkDescription string         `json:"work_description" binding:"required"`
	Recommendations string         `json:"recommendations"`
	// Repair fields
	PressureBeforeBar *int          `json:"pressure_before_bar"`
	PressureAfterBar  *int          `json:"pressure_after_bar"`
	OilCondition      *string       `json:"oil_condition"`
	OilLevel          *string       `json:"oil_level"`
	LeakLocation      *string       `json:"leak_location"`
	LeakSeverity      *string       `json:"leak_severity"`
	PartsReplaced     []PartReplaced `json:"parts_replaced"`
	PhotoURLs         []ReportPhoto  `json:"photo_urls"`
	// Inspeksi fields
	InspectionItems   []CreateInspectionItemRequest `json:"inspection_items"`
}

type CreateInspectionItemRequest struct {
	ItemType       string                 `json:"item_type" binding:"required,oneof=hose cylinder pump"`
	ItemCode       string                 `json:"item_code"`
	LocationDesc   string                 `json:"location_desc"`
	Specifications map[string]interface{} `json:"specifications" binding:"required"`
	Condition      string                 `json:"condition" binding:"required,oneof=good wear cracked leaking critical"`
	Recommendation string                 `json:"recommendation" binding:"required,oneof=no_action monitor schedule_replace urgent_replace"`
	PhotoURL       *string                `json:"photo_url"`
	Notes          string                 `json:"notes"`
}

type ReportRepository interface {
	Create(report *HydraulicReport) error
	CreateInspectionItems(items []InspectionItem) error
	FindByBookingID(bookingID string) (*HydraulicReport, error)
	FindByID(id string) (*HydraulicReport, error)
	FindByTechnicianID(technicianID string) ([]HydraulicReport, error)
	UpdatePDFUrl(reportID, pdfURL string) error
}

type ReportUsecase interface {
	CreateReport(bookingID, technicianID string, req CreateReportRequest) (*HydraulicReport, error)
	GetReportByBookingID(bookingID string) (*HydraulicReport, error)
	GetMyReports(technicianID string) ([]HydraulicReport, error)
}