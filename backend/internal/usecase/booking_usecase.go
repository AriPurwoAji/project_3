package usecase

import (
	"errors"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
)

type bookingUsecase struct {
	bookingRepo domain.BookingRepository
}

func NewBookingUsecase(repo domain.BookingRepository) domain.BookingUsecase {
	return &bookingUsecase{bookingRepo: repo}
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
	return u.bookingRepo.ClaimBooking(bookingID, technicianID)
}

func (u *bookingUsecase) UpdateStatus(bookingID, technicianID, status string) error {
	booking, err := u.bookingRepo.FindByID(bookingID)
	if err != nil {
		return errors.New("booking tidak ditemukan")
	}
	if booking.TechnicianID == nil || *booking.TechnicianID != technicianID {
		return errors.New("kamu bukan teknisi yang mengerjakan job ini")
	}
	return u.bookingRepo.UpdateStatus(bookingID, technicianID, status)
}

func (u *bookingUsecase) AssignTechnician(bookingID, technicianID string) error {
	return u.bookingRepo.AssignTechnician(bookingID, technicianID)
}