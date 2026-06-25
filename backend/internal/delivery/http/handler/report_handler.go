package handler

import (
	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/AriPurwoAji/project_3/backend/pkg/response"
	"github.com/gin-gonic/gin"
)

type ReportHandler struct {
	reportUsecase domain.ReportUsecase
}

func NewReportHandler(uc domain.ReportUsecase) *ReportHandler {
	return &ReportHandler{reportUsecase: uc}
}

func (h *ReportHandler) CreateReport(c *gin.Context) {
	bookingID := c.Param("booking_id")
	technicianID := c.GetString("user_id")

	var req domain.CreateReportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, 400, "Request tidak valid: "+err.Error())
		return
	}

	report, err := h.reportUsecase.CreateReport(bookingID, technicianID, req)
	if err != nil {
		response.Error(c, 400, err.Error())
		return
	}

	response.Success(c, 201, "Laporan berhasil disimpan", report)
}

func (h *ReportHandler) GetReportByBookingID(c *gin.Context) {
	bookingID := c.Param("booking_id")
	report, err := h.reportUsecase.GetReportByBookingID(bookingID)
	if err != nil {
		response.Error(c, 404, err.Error())
		return
	}
	response.Success(c, 200, "Success", report)
}

func (h *ReportHandler) GetMyReports(c *gin.Context) {
	technicianID := c.GetString("user_id")
	reports, err := h.reportUsecase.GetMyReports(technicianID)
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", reports)
}

func (h *ReportHandler) GetAllReportsByBookingID(c *gin.Context) {
	bookingID := c.Param("booking_id")
	reports, err := h.reportUsecase.GetAllReportsByBookingID(bookingID)
	if err != nil {
		response.Error(c, 404, err.Error())
		return
	}
	response.Success(c, 200, "Success", reports)
}

func (h *ReportHandler) UpdateReport(c *gin.Context) {
	reportID     := c.Param("report_id")
	technicianID := c.GetString("user_id")

	var req domain.UpdateReportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, 400, "Request tidak valid: "+err.Error())
		return
	}

	report, err := h.reportUsecase.UpdateReport(reportID, technicianID, req)
	if err != nil {
		response.Error(c, 400, err.Error())
		return
	}
	response.Success(c, 200, "Laporan berhasil diperbarui", report)
}