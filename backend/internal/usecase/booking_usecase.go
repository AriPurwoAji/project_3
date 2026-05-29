package usecase

import (
	"errors"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
)

type bookingUsecase struct {
	bookingRepo domain.BookingRepository
	notifRepo   domain.NotificationRepository
}

func NewBookingUsecase(repo domain.BookingRepository, notifRepo domain.NotificationRepository) domain.BookingUsecase {
	return &bookingUsecase{bookingRepo: repo, notifRepo: notifRepo}
}

// notify creates a notification best-effort (never blocks on error)
func (u *bookingUsecase) notify(userID string, bookingID *string, title, body string) {
	u.notifRepo.Create(&domain.Notification{ //nolint
		UserID:    userID,
		BookingID: bookingID,
		Type:      "booking_update",
		Title:     title,
		Body:      body,
	})
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
	u.notify(booking.CreatedBy, &bookingID,
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
		u.notify(booking.CreatedBy, &bookingID,
			"Teknisi dalam perjalanan",
			"Teknisi sedang menuju lokasi Anda.")
	case "on_site":
		u.notify(booking.CreatedBy, &bookingID,
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
	// Notify technician about assignment
	u.notify(technicianID, &bookingID,
		"Job baru ditugaskan",
		"Manager telah menugaskan Anda untuk mengerjakan sebuah job.")
	// Notify client that a technician has been assigned
	u.notify(booking.CreatedBy, &bookingID,
		"Teknisi ditugaskan",
		"Teknisi telah ditetapkan untuk mengerjakan job Anda.")
	return nil
}