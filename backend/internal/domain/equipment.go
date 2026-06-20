package domain

import "time"

type Equipment struct {
	ID             string    `json:"id"`
	CompanyID      string    `json:"company_id"`
	Name           string    `json:"name"`
	Description    string    `json:"description"`
	LocationDetail string    `json:"location_detail"`
	IsActive       bool      `json:"is_active"`
	CreatedAt      time.Time `json:"created_at"`
	CompanyName    string    `json:"company_name,omitempty"`
}

type EquipmentRepository interface {
	FindAll() ([]Equipment, error)
	FindByCompanyID(companyID string) ([]Equipment, error)
	FindByID(id string) (*Equipment, error)
	Create(equipment *Equipment) error
	Update(equipment *Equipment) error
	Delete(id string) error
}

type EquipmentUsecase interface {
	GetAllEquipment() ([]Equipment, error)
	GetEquipmentByCompany(companyID string) ([]Equipment, error)
	CreateEquipment(equipment *Equipment) error
	UpdateEquipment(id, companyID, role string, e *Equipment) error
	DeleteEquipment(id, companyID, role string) error
}