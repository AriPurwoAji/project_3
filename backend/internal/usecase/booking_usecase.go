package usecase

import (
	"errors"
	"fmt"
	"log"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
)

type bookingUsecase struct {
	bookingRepo domain.BookingRepository
	notifRepo   domain.NotificationRepository
}

func NewBookingUsecase(repo domain.BookingRepository, notifRepo domain.NotificationRepository) domain.BookingUsecase {
	return &bookingUsecase{bookingRepo: repo, notifRepo: notifRepo}
}

// notify buat in-app notif (FCM push otomatis dikirim oleh notifRepo.Create)
func (u *bookingUsecase) notify(userID string, bookingID *string, notifType, title, body string) {
	if err := u.notifRepo.Create(&domain.Notification{
		UserID:    userID,
		BookingID: bookingID,
		Type:      notifType,
		Title:     title,
		Body:      body,
		Payload:   map[string]interface{}{},
	}); err != nil {
		log.Printf("[notify] gagal buat notif userID=%s type=%s: %v", userID, notifType, err)
	}
}

func (u *bookingUsecase) GetAvailableReferences(companyID string) ([]domain.AvailableReference, error) {
	return u.bookingRepo.GetAvailableReferences(companyID)
}

func (u *bookingUsecase) CreateBooking(userID, companyID string, req domain.CreateBookingRequest) (*domain.Booking, error) {
	// Validasi repair prerequisite
	if req.ServiceType == "repair" {
		if req.ReferenceBookingID == nil || *req.ReferenceBookingID == "" {
			return nil, errors.New("layanan repair memerlukan riwayat inspeksi atau maintenance yang sudah selesai sebagai referensi")
		}
		refs, err := u.bookingRepo.GetAvailableReferences(companyID)
		if err != nil {
			return nil, errors.New("gagal memverifikasi riwayat: " + err.Error())
		}
		found := false
		for _, r := range refs {
			if r.ID == *req.ReferenceBookingID {
				found = true
				break
			}
		}
		if !found {
			return nil, errors.New("riwayat yang dipilih tidak tersedia atau sudah pernah digunakan sebagai referensi repair")
		}
	}

	booking := &domain.Booking{
		CompanyID:          companyID,
		CreatedBy:          userID,
		ServiceType:        req.ServiceType,
		UrgencyLevel:       req.UrgencyLevel,
		Description:        req.Description,
		SiteAddress:        req.SiteAddress,
		SiteCity:           req.SiteCity,
		Latitude:           req.Latitude,
		Longitude:          req.Longitude,
		PhotoURLs:          req.PhotoURLs,
		ReferenceBookingID: req.ReferenceBookingID,
	}

	if req.EquipmentID != "" {
		booking.EquipmentID = &req.EquipmentID
	}
	booking.EquipmentID2 = req.EquipmentID2

	if req.ScheduledAt != nil {
		// parse jika ada
	}

	if err := u.bookingRepo.Create(booking); err != nil {
		return nil, errors.New("gagal membuat booking: " + err.Error())
	}

	// Buat booking items jika ada (inspeksi/maintenance)
	if len(req.Items) > 0 {
		_ = u.bookingRepo.CreateBookingItems(booking.ID, req.Items)
	}

	// Ambil booking lengkap (dengan company name) untuk isi notifikasi
	full, err := u.bookingRepo.FindByID(booking.ID)
	if err != nil {
		full = booking
	}
	companyLabel := full.CompanyName
	if companyLabel == "" {
		companyLabel = "klien"
	}

	urgencyNote := ""
	if req.UrgencyLevel == "emergency" {
		urgencyNote = " [EMERGENCY]"
	}
	notifTitle := "Booking baru masuk" + urgencyNote
	notifBody  := "Permintaan servis " + req.ServiceType + " dari " + companyLabel + " di " + req.SiteCity + "."

	u.notifRepo.BroadcastToRole("manager", &booking.ID, "job_open", notifTitle, notifBody) //nolint
	u.notifRepo.BroadcastToRole("teknisi", &booking.ID, "job_open", notifTitle, notifBody) //nolint
	u.notifRepo.BroadcastToRole("sales",   &booking.ID, "job_open", notifTitle, notifBody) //nolint

	return booking, nil
}

func (u *bookingUsecase) GetAllBookings(filters map[string]string) ([]domain.Booking, error) {
	return u.bookingRepo.FindAll(filters)
}

func (u *bookingUsecase) GetBookingByID(id string) (*domain.Booking, error) {
	booking, err := u.bookingRepo.FindByID(id)
	if err != nil {
		return nil, err
	}
	items, err := u.bookingRepo.GetBookingItems(id)
	if err == nil {
		booking.Items = items
	}
	return booking, nil
}

func (u *bookingUsecase) GetOpenBookings() ([]domain.Booking, error) {
	return u.bookingRepo.FindOpenBookings()
}

func (u *bookingUsecase) GetMyJobs(technicianID string) ([]domain.Booking, error) {
	return u.bookingRepo.FindByTechnicianID(technicianID)
}

func (u *bookingUsecase) ClaimBooking(bookingID, technicianID string, workEquipmentID *string) error {
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return errors.New("booking tidak ditemukan")
	}
	if booking.Status != "open" {
		return errors.New("job sudah tidak tersedia")
	}
	// Validasi: jika booking punya 2 equipment, work_equipment_id wajib diisi
	if booking.EquipmentID2 != nil && (workEquipmentID == nil || *workEquipmentID == "") {
		return errors.New("pilih equipment yang dikerjakan terlebih dahulu")
	}
	if err := u.bookingRepo.ClaimBooking(bookingID, technicianID, workEquipmentID); err != nil {
		return err
	}
	u.notify(booking.CreatedBy, &bookingID, "job_claimed",
		"Teknisi ditemukan",
		"Job Anda sudah diambil dan sedang diproses oleh teknisi.")
	u.notify(technicianID, &bookingID, "job_claimed",
		"Job berhasil diambil",
		"Kamu telah mengambil job "+booking.ServiceType+" di "+booking.SiteCity+". Segera proses!")
	return nil
}

func (u *bookingUsecase) UpdateStatus(bookingID, technicianID, status string) error {
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return errors.New("booking tidak ditemukan")
	}
	if booking.TechnicianID == nil || *booking.TechnicianID != technicianID {
		return errors.New("kamu bukan teknisi yang mengerjakan job ini")
	}
	if err := u.bookingRepo.UpdateStatus(bookingID, technicianID, status); err != nil {
		return err
	}
	switch status {
	case "on_the_way":
		u.notify(booking.CreatedBy, &bookingID, "status_changed",
			"Teknisi dalam perjalanan",
			"Teknisi sedang menuju lokasi Anda.")
	case "on_site":
		u.notify(booking.CreatedBy, &bookingID, "status_changed",
			"Teknisi tiba di lokasi",
			"Pengerjaan sedang dimulai.")
	case "done":
		u.notify(booking.CreatedBy, &bookingID, "job_done",
			"Pekerjaan selesai ✅",
			"Job servis "+booking.ServiceType+" di "+booking.SiteCity+" telah diselesaikan oleh teknisi.")
	}
	return nil
}

func (u *bookingUsecase) ConfirmJob(bookingID, userID, role string) error {
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return errors.New("booking tidak ditemukan")
	}
	if booking.Status != "waiting_confirmation" {
		return errors.New("booking belum dalam status menunggu konfirmasi")
	}
	if role != "manager" && booking.CreatedBy != userID {
		return errors.New("kamu tidak berhak mengonfirmasi booking ini")
	}
	if err := u.bookingRepo.ConfirmJob(bookingID, userID); err != nil {
		return err
	}
	// Notifikasi ke teknisi bahwa client sudah konfirmasi
	if booking.TechnicianID != nil {
		u.notify(*booking.TechnicianID, &bookingID, "job_done",
			"Pekerjaan dikonfirmasi client ✅",
			"Client telah mengonfirmasi penyelesaian job "+booking.ServiceType+" di "+booking.SiteCity+". Job selesai!")
	}
	u.notify(booking.CreatedBy, &bookingID, "job_done",
		"Konfirmasi berhasil ✅",
		"Terima kasih! Hasil kerja teknisi telah kamu konfirmasi. Job dinyatakan selesai.")
	return nil
}

func (u *bookingUsecase) RejectJob(bookingID, userID, role, reason string) error {
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return errors.New("booking tidak ditemukan")
	}
	if booking.Status != "waiting_confirmation" {
		return errors.New("booking belum dalam status menunggu konfirmasi")
	}
	if role != "manager" && booking.CreatedBy != userID {
		return errors.New("kamu tidak berhak menolak booking ini")
	}
	if err := u.bookingRepo.RejectJob(bookingID); err != nil {
		return err
	}
	// Notifikasi ke teknisi
	if booking.TechnicianID != nil {
		equipInfo := ""
		if booking.EquipmentName != "" {
			equipInfo = " untuk " + booking.EquipmentName
		}
		u.notify(*booking.TechnicianID, &bookingID, "job_rejected",
			"Laporan ditolak — perlu perbaikan",
			fmt.Sprintf("Laporan job%s milik %s ditolak. Alasan: %s. Segera perbaiki laporan.", equipInfo, booking.CompanyName, reason))
	}
	return nil
}

func (u *bookingUsecase) CancelBooking(bookingID, userID, role string) error {
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return errors.New("booking tidak ditemukan")
	}
	if booking.Status != "open" {
		return errors.New("hanya booking berstatus 'open' yang bisa dibatalkan")
	}
	if role != "manager" && booking.CreatedBy != userID {
		return errors.New("kamu tidak berhak membatalkan booking ini")
	}
	return u.bookingRepo.CancelBooking(bookingID)
}

func (u *bookingUsecase) GetBookingItems(bookingID string) ([]domain.BookingItem, error) {
	return u.bookingRepo.GetBookingItems(bookingID)
}

func (u *bookingUsecase) ToggleBookingItem(bookingID, itemID, technicianID string, isDone bool) error {
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return errors.New("booking tidak ditemukan")
	}
	if booking.TechnicianID == nil || *booking.TechnicianID != technicianID {
		return errors.New("kamu bukan teknisi yang mengerjakan job ini")
	}
	return u.bookingRepo.ToggleBookingItem(itemID, isDone)
}

func (u *bookingUsecase) MarkEquipmentDone(bookingID, technicianID, equipmentID string, done bool) error {
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return errors.New("booking tidak ditemukan")
	}
	if booking.TechnicianID == nil || *booking.TechnicianID != technicianID {
		return errors.New("kamu bukan teknisi yang mengerjakan job ini")
	}
	// Pastikan equipment_id yang ditandai memang bagian dari booking ini
	validEquip := false
	if booking.EquipmentID != nil && *booking.EquipmentID == equipmentID {
		validEquip = true
	}
	if booking.EquipmentID2 != nil && *booking.EquipmentID2 == equipmentID {
		validEquip = true
	}
	if !validEquip {
		return errors.New("equipment tidak terdaftar dalam booking ini")
	}
	return u.bookingRepo.MarkEquipmentDone(bookingID, equipmentID, done)
}

func (u *bookingUsecase) AssignTechnician(bookingID, technicianID string) error {
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return errors.New("booking tidak ditemukan")
	}
	if err := u.bookingRepo.AssignTechnician(bookingID, technicianID); err != nil {
		return err
	}
	u.notify(technicianID, &bookingID, "job_claimed",
		"Job baru ditugaskan",
		"Manager telah menugaskan Anda untuk mengerjakan sebuah job.")
	u.notify(booking.CreatedBy, &bookingID, "job_claimed",
		"Teknisi ditugaskan",
		"Teknisi telah ditetapkan untuk mengerjakan job Anda.")
	return nil
}