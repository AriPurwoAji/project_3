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
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return nil, errors.New("booking tidak ditemukan")
	}

	if booking.TechnicianID == nil || *booking.TechnicianID != technicianID {
		return nil, errors.New("kamu bukan teknisi yang mengerjakan booking ini")
	}

	report := &domain.HydraulicReport{
		BookingID:            bookingID,
		TechnicianID:         technicianID,
		EquipmentID:          req.EquipmentID,
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

	// Inspection items
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

	// Tentukan apakah semua equipment sudah punya laporan
	hasEquip2 := booking.EquipmentID2 != nil
	allDone   := true

	if hasEquip2 {
		count, _ := u.reportRepo.CountByBookingID(bookingID)
		allDone = count >= 2
	}

	if allDone {
		// Semua laporan sudah masuk — minta konfirmasi client
		u.bookingRepo.ForceUpdateStatus(bookingID, "waiting_confirmation") //nolint
		u.notifyClient(booking, bookingID)
	}
	// Jika belum semua: status tetap (on_site / in_progress) — client belum dinotif

	// Generate PDF (best-effort)
	if u.pdfGen != nil && u.uploader != nil {
		go func() {
			pdfBytes, err := u.pdfGen.GenerateReport(report, booking)
			if err != nil {
				log.Printf("PDF generation failed for report %s: %v", report.ID, err)
				return
			}
			filename := fmt.Sprintf("laporan_%s.pdf", report.ID)
			pdfURL, err := u.uploader.Upload(pdfBytes, filename, "application/pdf")
			if err != nil {
				log.Printf("PDF upload failed for report %s: %v", report.ID, err)
				return
			}
			if err := u.reportRepo.UpdatePDFUrl(report.ID, pdfURL); err != nil {
				log.Printf("UpdatePDFUrl failed for report %s: %v", report.ID, err)
			}
		}()
	}

	return report, nil
}

func (u *reportUsecase) notifyClient(booking *domain.Booking, bookingID string) {
	equipInfo := ""
	if booking.EquipmentName != "" {
		equipInfo = " untuk " + booking.EquipmentName
	}
	if err := u.notifRepo.Create(&domain.Notification{
		UserID:    booking.CreatedBy,
		BookingID: &bookingID,
		Type:      "job_done",
		Title:     "Pekerjaan selesai — harap konfirmasi",
		Body: fmt.Sprintf(
			"Teknisi telah menyelesaikan pekerjaan%s dan mengajukan laporan. Periksa laporan dan konfirmasi hasilnya.",
			equipInfo,
		),
		Payload: map[string]interface{}{"booking_id": bookingID},
	}); err != nil {
		log.Printf("[notify] gagal buat notif waiting_confirmation userID=%s: %v", booking.CreatedBy, err)
	}

	u.notifRepo.BroadcastToRole("manager", &bookingID, "job_done", //nolint
		"Laporan servis menunggu konfirmasi",
		fmt.Sprintf("Teknisi %s telah submit laporan di %s. Menunggu konfirmasi client.", booking.TechnicianName, booking.SiteCity))
}

func (u *reportUsecase) GetReportByBookingID(bookingID string) (*domain.HydraulicReport, error) {
	return u.reportRepo.FindByBookingID(bookingID)
}

func (u *reportUsecase) GetAllReportsByBookingID(bookingID string) ([]domain.HydraulicReport, error) {
	return u.reportRepo.FindAllByBookingID(bookingID)
}

func (u *reportUsecase) GetMyReports(technicianID string) ([]domain.HydraulicReport, error) {
	reports, err := u.reportRepo.FindByTechnicianID(technicianID)
	if err != nil {
		return nil, err
	}
	for i, r := range reports {
		if booking, err := u.bookingRepo.FindByID(r.BookingID); err == nil {
			reports[i].BookingInfo = booking
		}
	}
	return reports, nil
}

func (u *reportUsecase) UpdateReport(reportID, technicianID string, req domain.UpdateReportRequest) (*domain.HydraulicReport, error) {
	existing, err := u.reportRepo.FindByID(reportID)
	if err != nil {
		return nil, errors.New("laporan tidak ditemukan")
	}
	if existing.TechnicianID != technicianID {
		return nil, errors.New("kamu bukan pemilik laporan ini")
	}
	if existing.Status != "rejected" {
		return nil, errors.New("hanya laporan yang ditolak yang bisa diedit")
	}

	if err := u.reportRepo.UpdateReport(reportID, req); err != nil {
		return nil, errors.New("gagal update laporan: " + err.Error())
	}

	// Update inspection items (hapus lama, buat baru)
	if len(req.InspectionItems) > 0 {
		_, err := u.reportRepo.FindByID(reportID) // memastikan report masih ada
		if err == nil {
			// Hapus items lama (tidak ada method delete, jadi skip untuk sekarang)
			var items []domain.InspectionItem
			for _, itemReq := range req.InspectionItems {
				items = append(items, domain.InspectionItem{
					ReportID:       reportID,
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
			u.reportRepo.CreateInspectionItems(items) //nolint
		}
	}

	// Cek apakah semua laporan untuk booking ini sudah submitted kembali
	booking, err := u.bookingRepo.FindByID(existing.BookingID)
	if err != nil {
		return u.reportRepo.FindByID(reportID)
	}

	totalEquip := 1
	if booking.EquipmentID2 != nil {
		totalEquip = 2
	}
	count, _ := u.reportRepo.CountByBookingID(existing.BookingID)
	if count >= totalEquip {
		u.bookingRepo.ForceUpdateStatus(existing.BookingID, "waiting_confirmation") //nolint
		// Notify client bahwa laporan sudah diperbaiki
		u.notifRepo.Create(&domain.Notification{ //nolint
			UserID:    booking.CreatedBy,
			BookingID: &existing.BookingID,
			Type:      "job_done",
			Title:     "Laporan sudah diperbaiki — harap konfirmasi ulang",
			Body:      "Teknisi telah memperbaiki laporan sesuai masukan kamu. Periksa dan konfirmasi hasilnya.",
			Payload:   map[string]interface{}{"booking_id": existing.BookingID},
		})
	}

	return u.reportRepo.FindByID(reportID)
}
