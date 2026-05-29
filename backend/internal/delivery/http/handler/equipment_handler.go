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
	var equipments []domain.Equipment
	var err error

	role := c.GetString("role")
	if role == "client" || role == "sales" {
		// Client/sales hanya boleh lihat equipment perusahaannya sendiri
		companyID := c.GetString("company_id")
		if companyID == "" {
			response.Error(c, 403, "Akun tidak memiliki perusahaan terkait")
			return
		}
		equipments, err = h.uc.GetEquipmentByCompany(companyID)
	} else {
		// Manager/teknisi bisa filter atau lihat semua
		companyID := c.Query("company_id")
		if companyID != "" {
			equipments, err = h.uc.GetEquipmentByCompany(companyID)
		} else {
			equipments, err = h.uc.GetAllEquipment()
		}
	}

	if err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 200, "Success", equipments)
}

func (h *EquipmentHandler) Update(c *gin.Context) {
	id        := c.Param("id")
	companyID := c.GetString("company_id")
	role      := c.GetString("role")

	var e domain.Equipment
	if err := c.ShouldBindJSON(&e); err != nil {
		response.Error(c, 400, err.Error())
		return
	}
	if err := h.uc.UpdateEquipment(id, companyID, role, &e); err != nil {
		response.Error(c, 400, err.Error())
		return
	}
	response.Success(c, 200, "Equipment berhasil diperbarui", e)
}

func (h *EquipmentHandler) Delete(c *gin.Context) {
	id        := c.Param("id")
	companyID := c.GetString("company_id")
	role      := c.GetString("role")

	if err := h.uc.DeleteEquipment(id, companyID, role); err != nil {
		response.Error(c, 400, err.Error())
		return
	}
	response.Success(c, 200, "Equipment berhasil dihapus", nil)
}

func (h *EquipmentHandler) Create(c *gin.Context) {
	var e domain.Equipment
	if err := c.ShouldBindJSON(&e); err != nil {
		response.Error(c, 400, err.Error())
		return
	}

	role := c.GetString("role")
	if role == "client" || role == "sales" {
		e.CompanyID = c.GetString("company_id")
	}

	if e.CompanyID == "" {
		response.Error(c, 400, "company_id wajib diisi")
		return
	}

	if err := h.uc.CreateEquipment(&e); err != nil {
		response.Error(c, 500, err.Error())
		return
	}
	response.Success(c, 201, "Equipment berhasil dibuat", e)
}