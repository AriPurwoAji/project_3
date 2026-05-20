package handler

import (
	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	"github.com/AriPurwoAji/project_3/backend/pkg/response"
	"github.com/gin-gonic/gin"
)

type EquipmentHandler struct {
	uc domain.EquipmentUsecase
}

func NewEquipmentHandler(uc domain.EquipmentUsecase) *EquipmentHandler {
	return &EquipmentHandler{uc: uc}
}

func (h *EquipmentHandler) GetAll(c *gin.Context) {
	companyID := c.Query("company_id")
	var equipments []domain.Equipment
	var err error

	if companyID != "" {
		equipments, err = h.uc.GetEquipmentByCompany(companyID)
	} else {
		equipments, err = h.uc.GetAllEquipment()
	}

	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", equipments)
}

func (h *EquipmentHandler) Create(c *gin.Context) {
	var e domain.Equipment
	if err := c.ShouldBindJSON(&e); err != nil {
		response.Error(c, 400, err.Error())
		return
	}
	if err := h.uc.CreateEquipment(&e); err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 201, "Equipment berhasil dibuat", e)
}