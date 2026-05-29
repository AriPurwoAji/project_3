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

// notify creates a notification best-effort; logs on error
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
	u.notify(booking.CreatedBy, &bookingID, "job_claimed",
		"Teknisi ditemukan",
		"Job Anda sudah diambil dan sedang diproses oleh teknisi.")
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
	}
	return nil
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