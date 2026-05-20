package usecase

import "github.com/AriPurwoAji/project_3/backend/internal/domain"

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