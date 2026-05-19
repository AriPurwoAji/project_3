package usecase

import "github.com/AriPurwoAji/project_3/backend/internal/domain"

type dashboardUsecase struct {
	repo domain.DashboardRepository
}

func NewDashboardUsecase(repo domain.DashboardRepository) domain.DashboardUsecase {
	return &dashboardUsecase{repo: repo}
}

func (u *dashboardUsecase) GetSummary(filters map[string]string) (*domain.DashboardSummary, error) {
	return u.repo.GetSummary(filters)
}

func (u *dashboardUsecase) GetTechnicianPerformance() ([]domain.TechnicianPerformance, error) {
	return u.repo.GetTechnicianPerformance()
}

func (u *dashboardUsecase) GetServiceTypeTrend(filters map[string]string) ([]domain.ServiceTypeTrend, error) {
	return u.repo.GetServiceTypeTrend(filters)
}