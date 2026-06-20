package usecase

import (
	"errors"
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

func (u *bookingUsecase) CreateBooking(userID, companyID string, req domain.CreateBookingRequest) (*domain.Booking, error) {
	booking := &domain.Booking{
		CompanyID:    companyID,
		CreatedBy:    userID,
		ServiceType:  req.ServiceType,
		UrgencyLevel: req.UrgencyLevel,
		Description:  req.Description,
		SiteAddress:  req.SiteAddress,
		SiteCity:     req.SiteCity,
		Latitude:     req.Latitude,
		Longitude:    req.Longitude,
		PhotoURLs:    req.PhotoURLs,
	}

	if req.EquipmentID != "" {
		booking.EquipmentID = &req.EquipmentID
	}

	if req.ScheduledAt != nil {
		// parse jika ada
	}

	if err := u.bookingRepo.Create(booking); err != nil {
		return nil, errors.New("gagal membuat booking: " + err.Error())
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
	return u.bookingRepo.FindByID(id)
}

func (u *bookingUsecase) GetOpenBookings() ([]domain.Booking, error) {
	return u.bookingRepo.FindOpenBookings()
}

func (u *bookingUsecase) GetMyJobs(technicianID string) ([]domain.Booking, error) {
	return u.bookingRepo.FindByTechnicianID(technicianID)
}

func (u *bookingUsecase) ClaimBooking(bookingID, technicianID string) error {
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return errors.New("booking tidak ditemukan")
	}
	if booking.Status != "open" {
		return errors.New("job sudah tidak tersedia")
	}
	if err := u.bookingRepo.ClaimBooking(bookingID, technicianID); err != nil {
		return err
	}
	// Notify client
	u.notify(booking.CreatedBy, &bookingID, "job_claimed",
		"Teknisi ditemukan",
		"Job Anda sudah diambil dan sedang diproses oleh teknisi.")
	// Notify teknisi (konfirmasi klaim berhasil)
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