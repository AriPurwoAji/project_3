package handler

import (
	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/AriPurwoAji/project_3/backend/pkg/response"
	"github.com/gin-gonic/gin"
)

type DashboardHandler struct {
	uc domain.DashboardUsecase
}

func NewDashboardHandler(uc domain.DashboardUsecase) *DashboardHandler {
	return &DashboardHandler{uc: uc}
}

func (h *DashboardHandler) GetSummary(c *gin.Context) {
	filters := map[string]string{
		"company_id": c.Query("company_id"),
		"from":       c.Query("from"),
		"to":         c.Query("to"),
	}
	summary, err := h.uc.GetSummary(filters)
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", summary)
}

func (h *DashboardHandler) GetTechnicianPerformance(c *gin.Context) {
	data, err := h.uc.GetTechnicianPerformance()
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", data)
}

func (h *DashboardHandler) GetServiceTypeTrend(c *gin.Context) {
	filters := map[string]string{
		"from": c.Query("from"),
		"to":   c.Query("to"),
	}
	data, err := h.uc.GetServiceTypeTrend(filters)
	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", data)
}