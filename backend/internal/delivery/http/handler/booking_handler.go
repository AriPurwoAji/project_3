package handler

import (
	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/AriPurwoAji/project_3/backend/pkg/response"
	"github.com/gin-gonic/gin"
)

type BookingHandler struct {
	bookingUsecase domain.BookingUsecase
}

func NewBookingHandler(uc domain.BookingUsecase) *BookingHandler {
	return &BookingHandler{bookingUsecase: uc}
}

func (h *BookingHandler) CreateBooking(c *gin.Context) {
	userID := c.GetString("user_id")

	var req domain.CreateBookingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, 400, "Request tidak valid: "+err.Error())
		return
	}

	booking, err := h.bookingUsecase.CreateBooking(userID, req.CompanyID, req)
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}

	response.Success(c, 201, "Booking berhasil dibuat", booking)
}

func (h *BookingHandler) GetAllBookings(c *gin.Context) {
	filters := map[string]string{
		"status":        c.Query("status"),
		"company_id":    c.Query("company_id"),
		"technician_id": c.Query("technician_id"),
	}

	// Client/sales hanya boleh lihat booking perusahaannya sendiri
	role := c.GetString("role")
	if role == "client" || role == "sales" {
		filters["company_id"] = c.GetString("company_id")
	}

	bookings, err := h.bookingUsecase.GetAllBookings(filters)
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}

	response.Success(c, 200, "Success", bookings)
}

func (h *BookingHandler) GetBookingByID(c *gin.Context) {
	id := c.Param("id")
	booking, err := h.bookingUsecase.GetBookingByID(id)
	if err != nil {
		response.Error(c, 404, err.Error())
		return
	}
	response.Success(c, 200, "Success", booking)
}

func (h *BookingHandler) GetOpenBookings(c *gin.Context) {
	bookings, err := h.bookingUsecase.GetOpenBookings()
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", bookings)
}

func (h *BookingHandler) GetMyJobs(c *gin.Context) {
	technicianID := c.GetString("user_id")
	bookings, err := h.bookingUsecase.GetMyJobs(technicianID)
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", bookings)
}

func (h *BookingHandler) ClaimBooking(c *gin.Context) {
	bookingID := c.Param("id")
	technicianID := c.GetString("user_id")

	if err := h.bookingUsecase.ClaimBooking(bookingID, technicianID); err != nil {
		response.Error(c, 400, err.Error())
		return
	}

	response.Success(c, 200, "Job berhasil diambil", nil)
}

func (h *BookingHandler) UpdateStatus(c *gin.Context) {
	bookingID := c.Param("id")
	technicianID := c.GetString("user_id")

	var req domain.UpdateStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, 400, "Request tidak valid: "+err.Error())
		return
	}

	if err := h.bookingUsecase.UpdateStatus(bookingID, technicianID, req.Status); err != nil {
		response.Error(c, 400, err.Error())
		return
	}

	response.Success(c, 200, "Status berhasil diupdate", nil)
}

func (h *BookingHandler) CancelBooking(c *gin.Context) {
	bookingID := c.Param("id")
	userID    := c.GetString("user_id")
	role      := c.GetString("role")

	if err := h.bookingUsecase.CancelBooking(bookingID, userID, role); err != nil {
		response.Error(c, 400, err.Error())
		return
	}
	response.Success(c, 200, "Booking berhasil dibatalkan", nil)
}

func (h *BookingHandler) AssignTechnician(c *gin.Context) {
	bookingID := c.Param("id")

	var req struct {
		TechnicianID string `json:"technician_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, 400, "Request tidak valid: "+err.Error())
		return
	}

	if err := h.bookingUsecase.AssignTechnician(bookingID, req.TechnicianID); err != nil {
		response.Error(c, 400, err.Error())
		return
	}

	response.Success(c, 200, "Teknisi berhasil di-assign", nil)
}