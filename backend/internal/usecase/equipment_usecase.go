package usecase

import (
	"errors"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
)

type equipmentUsecase struct {
	repo domain.EquipmentRepository
}

func NewEquipmentUsecase(repo domain.EquipmentRepository) domain.EquipmentUsecase {
	return &equipmentUsecase{repo: repo}
}

func (u *equipmentUsecase) GetAllEquipment() ([]domain.Equipment, error) {
	return u.repo.FindAll()
}

func (u *equipmentUsecase) GetEquipmentByCompany(companyID string) ([]domain.Equipment, error) {
	return u.repo.FindByCompanyID(companyID)
}

func (u *equipmentUsecase) CreateEquipment(e *domain.Equipment) error {
	return u.repo.Create(e)
}

func (u *equipmentUsecase) UpdateEquipment(id, companyID, role string, e *domain.Equipment) error {
	existing, err := u.repo.FindByID(id)
	if err != nil {
		return errors.New("equipment tidak ditemukan")
	}
	if role != "manager" && existing.CompanyID != companyID {
		return errors.New("kamu tidak berhak mengubah equipment ini")
	}
	e.ID        = id
	e.CompanyID = existing.CompanyID
	return u.repo.Update(e)
}

func (u *equipmentUsecase) DeleteEquipment(id, companyID, role string) error {
	existing, err := u.repo.FindByID(id)
	if err != nil {
		return errors.New("equipment tidak ditemukan")
	}
	if role != "manager" && existing.CompanyID != companyID {
		return errors.New("kamu tidak berhak menghapus equipment ini")
	}
	return u.repo.Delete(id)
}