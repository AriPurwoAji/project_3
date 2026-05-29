package usecase

import (
	"errors"
	"fmt"
	"log"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
)

type reportUsecase struct {
	reportRepo  domain.ReportRepository
	bookingRepo domain.BookingRepository
	pdfGen      domain.PDFReportGenerator
	uploader    domain.FileUploader
	notifRepo   domain.NotificationRepository
}

func NewReportUsecase(
	reportRepo domain.ReportRepository,
	bookingRepo domain.BookingRepository,
	pdfGen domain.PDFReportGenerator,
	uploader domain.FileUploader,
	notifRepo domain.NotificationRepository,
) domain.ReportUsecase {
	return &reportUsecase{
		reportRepo:  reportRepo,
		bookingRepo: bookingRepo,
		pdfGen:      pdfGen,
		uploader:    uploader,
		notifRepo:   notifRepo,
	}
}

func (u *reportUsecase) CreateReport(bookingID, technicianID string, req domain.CreateReportRequest) (*domain.HydraulicReport, error) {
	// Validasi booking
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return nil, errors.New("booking tidak ditemukan")
	}

	if booking.TechnicianID == nil || *booking.TechnicianID != technicianID {
		return nil, errors.New("kamu bukan teknisi yang mengerjakan booking ini")
	}

	// Buat report
	report := &domain.HydraulicReport{
		BookingID:            bookingID,
		TechnicianID:         technicianID,
		PressureBeforeBar:    req.PressureBeforeBar,
		PressureAfterBar:     req.PressureAfterBar,
		OilCondition:         req.OilCondition,
		OilLevel:             req.OilLevel,
		LeakLocation:         req.LeakLocation,
		LeakSeverity:         req.LeakSeverity,
		PartsReplaced:        req.PartsReplaced,
		PhotoURLs:            req.PhotoURLs,
		WorkDescription:      req.WorkDescription,
		Recommendations:      req.Recommendations,
		MaintenanceChecklist: req.MaintenanceChecklist,
	}

	if report.PartsReplaced == nil {
		report.PartsReplaced = []domain.PartReplaced{}
	}
	if report.PhotoURLs == nil {
		report.PhotoURLs = []domain.ReportPhoto{}
	}

	if err := u.reportRepo.Create(report); err != nil {
		return nil, errors.New("gagal menyimpan laporan: " + err.Error())
	}

	// Simpan inspection items jika ada
	if len(req.InspectionItems) > 0 {
		var items []domain.InspectionItem
		for _, itemReq := range req.InspectionItems {
			items = append(items, domain.InspectionItem{
				ReportID:       report.ID,
				ItemType:       itemReq.ItemType,
				ItemCode:       itemReq.ItemCode,
				LocationDesc:   itemReq.LocationDesc,
				Specifications: itemReq.Specifications,
				Condition:      itemReq.Condition,
				Recommendation: itemReq.Recommendation,
				PhotoURL:       itemReq.PhotoURL,
				Notes:          itemReq.Notes,
			})
		}
		if err := u.reportRepo.CreateInspectionItems(items); err != nil {
			return nil, errors.New("gagal menyimpan item inspeksi: " + err.Error())
		}
		report.InspectionItems = items
	}

	// Update booking status jadi done
	u.bookingRepo.UpdateStatus(bookingID, technicianID, "done")

	// Notify client that work is complete
	if err := u.notifRepo.Create(&domain.Notification{
		UserID:    booking.CreatedBy,
		BookingID: &bookingID,
		Type:      "job_done",
		Title:     "Pekerjaan selesai",
		Body:      "Laporan servis telah dibuat. Silakan cek detail dan unduh PDF di aplikasi.",
		Payload:   map[string]interface{}{},
	}); err != nil {
		log.Printf("[notify] gagal buat notif laporan selesai userID=%s: %v", booking.CreatedBy, err)
	}

	// Generate PDF (best-effort; does not fail the report creation)
	if u.pdfGen != nil && u.uploader != nil {
		pdfBytes, err := u.pdfGen.GenerateReport(report, booking)
		if err != nil {
			log.Printf("PDF generation failed for report %s: %v", report.ID, err)
		} else {
			filename := fmt.Sprintf("laporan_%s.pdf", report.ID)
			pdfURL, err := u.uploader.Upload(pdfBytes, filename, "application/pdf")
			if err != nil {
				log.Printf("PDF upload failed for report %s: %v", report.ID, err)
			} else {
				if err := u.reportRepo.UpdatePDFUrl(report.ID, pdfURL); err != nil {
					log.Printf("UpdatePDFUrl failed for report %s: %v", report.ID, err)
				} else {
					report.PDFUrl = &pdfURL
				}
			}
		}
	}

	return report, nil
}

func (u *reportUsecase) GetReportByBookingID(bookingID string) (*domain.HydraulicReport, error) {
	return u.reportRepo.FindByBookingID(bookingID)
}

func (u *reportUsecase) GetMyReports(technicianID string) ([]domain.HydraulicReport, error) {
	return u.reportRepo.FindByTechnicianID(technicianID)
}