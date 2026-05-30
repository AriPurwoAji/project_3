package pdf

import (
	"bytes"
	"fmt"
	stdimage "image"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/AriPurwoAji/project_3/backend/internal/domain"
	gofpdf "github.com/go-pdf/fpdf"
)

type ReportGenerator struct{}

func NewReportGenerator() *ReportGenerator {
	return &ReportGenerator{}
}

func (g *ReportGenerator) GenerateReport(report *domain.HydraulicReport, booking *domain.Booking) ([]byte, error) {
	f := gofpdf.New("P", "mm", "A4", "")
	f.SetMargins(15, 15, 15)
	f.SetAutoPageBreak(true, 15)
	f.AddPage()

	const pageW = 180.0

	// ─── HELPERS ────────────────────────────────────────────────────────────

	setColor := func(r, g, b int) {
		f.SetTextColor(r, g, b)
	}
	setFill := func(r, g, b int) {
		f.SetFillColor(r, g, b)
	}
	setDraw := func(r, g, b int) {
		f.SetDrawColor(r, g, b)
	}

	sectionHeader := func(title string) {
		f.Ln(3)
		setFill(37, 99, 235)
		setColor(255, 255, 255)
		f.SetFont("Helvetica", "B", 9)
		f.CellFormat(pageW, 7, "  "+title, "", 1, "L", true, 0, "")
		setColor(17, 24, 39)
		f.Ln(2)
	}

	// Two-column label:value row
	row2 := func(l1, v1, l2, v2 string) {
		const lw, vw = 35.0, 55.0
		f.SetFont("Helvetica", "", 8)
		setColor(107, 114, 128)
		f.CellFormat(lw, 5, l1+":", "", 0, "L", false, 0, "")
		f.SetFont("Helvetica", "B", 8)
		setColor(17, 24, 39)
		f.CellFormat(vw, 5, sanitize(v1), "", 0, "L", false, 0, "")
		f.SetFont("Helvetica", "", 8)
		setColor(107, 114, 128)
		f.CellFormat(lw, 5, l2+":", "", 0, "L", false, 0, "")
		f.SetFont("Helvetica", "B", 8)
		setColor(17, 24, 39)
		f.CellFormat(vw, 5, sanitize(v2), "", 1, "L", false, 0, "")
	}

	// Full-width label:value row
	row1 := func(label, val string) {
		const lw = 35.0
		f.SetFont("Helvetica", "", 8)
		setColor(107, 114, 128)
		f.CellFormat(lw, 5, label+":", "", 0, "L", false, 0, "")
		f.SetFont("Helvetica", "B", 8)
		setColor(17, 24, 39)
		f.CellFormat(pageW-lw, 5, sanitize(val), "", 1, "L", false, 0, "")
	}

	// Multi-line text block
	textBlock := func(val string) {
		f.SetFont("Helvetica", "", 9)
		setColor(17, 24, 39)
		f.MultiCell(pageW, 5, sanitize(val), "", "L", false)
		f.Ln(1)
	}

	// ─── HEADER ─────────────────────────────────────────────────────────────

	setFill(37, 99, 235)
	setColor(255, 255, 255)
	f.SetFont("Helvetica", "B", 13)
	f.CellFormat(pageW-40, 10, "LAPORAN SERVIS HIDROLIK", "", 0, "L", true, 0, "")
	f.SetFont("Helvetica", "B", 10)
	f.CellFormat(40, 10, "HydroServ", "", 1, "R", true, 0, "")
	f.Ln(4)
	setColor(17, 24, 39)

	// ─── BOOKING INFO ────────────────────────────────────────────────────────

	serviceTypeLabel := map[string]string{
		"repair":      "Repair / Perbaikan",
		"inspeksi":    "Inspeksi",
		"maintenance": "Pemeliharaan",
	}
	stLabel := serviceTypeLabel[booking.ServiceType]
	if stLabel == "" {
		stLabel = booking.ServiceType
	}

	urgLabel := "Standard"
	if booking.UrgencyLevel == "emergency" {
		urgLabel = "EMERGENCY"
	}

	dateStr := report.CreatedAt.Format("02 Jan 2006")
	if report.CreatedAt.IsZero() {
		dateStr = time.Now().Format("02 Jan 2006")
	}

	reportIDShort := report.ID
	if len(reportIDShort) > 8 {
		reportIDShort = reportIDShort[:8]
	}

	row2("No. Laporan", reportIDShort+"...", "Tanggal", dateStr)
	row2("Tipe Servis", stLabel, "Urgensi", urgLabel)
	row2("Pelanggan", booking.CompanyName, "Peralatan", booking.EquipmentName)
	row2("Teknisi", booking.TechnicianName, "Status", "Selesai")
	row1("Lokasi", booking.SiteAddress+", "+booking.SiteCity)

	// ─── HYDRAULIC CONDITION (repair / maintenance) ──────────────────────────

	if booking.ServiceType == "repair" || booking.ServiceType == "maintenance" {
		sectionHeader("KONDISI HIDROLIK")

		pressureBefore := "-"
		pressureAfter := "-"
		if report.PressureBeforeBar != nil {
			pressureBefore = fmt.Sprintf("%d bar", *report.PressureBeforeBar)
		}
		if report.PressureAfterBar != nil {
			pressureAfter = fmt.Sprintf("%d bar", *report.PressureAfterBar)
		}
		oilCond := "-"
		if report.OilCondition != nil {
			oilCond = *report.OilCondition
		}
		oilLevel := "-"
		if report.OilLevel != nil {
			oilLevel = *report.OilLevel
		}
		leakLoc := "-"
		if report.LeakLocation != nil {
			leakLoc = *report.LeakLocation
		}
		leakSev := "-"
		if report.LeakSeverity != nil {
			leakSev = *report.LeakSeverity
		}

		row2("Tekanan Sebelum", pressureBefore, "Tekanan Sesudah", pressureAfter)
		row2("Kondisi Oli", oilCond, "Level Oli", oilLevel)
		row2("Lokasi Kebocoran", leakLoc, "Keparahan", leakSev)
	}

	// ─── MAINTENANCE CHECKLIST ───────────────────────────────────────────────

	if booking.ServiceType == "maintenance" && len(report.MaintenanceChecklist) > 0 {
		sectionHeader("CHECKLIST PEMELIHARAAN")

		statusLabel := map[string]string{
			"done":           "Selesai",
			"skip":           "Dilewati",
			"not_applicable": "N/A",
		}
		statusSymbol := map[string]string{
			"done":           "[v]",
			"skip":           "[-]",
			"not_applicable": "[x]",
		}

		setDraw(229, 231, 235)
		for i, item := range report.MaintenanceChecklist {
			sym := statusSymbol[item.Status]
			if sym == "" {
				sym = "[ ]"
			}
			lbl := statusLabel[item.Status]
			if lbl == "" {
				lbl = item.Status
			}
			bg := i%2 == 0
			if bg {
				setFill(249, 250, 251)
			} else {
				setFill(255, 255, 255)
			}
			f.SetFont("Helvetica", "B", 8)
			setColor(37, 99, 235)
			f.CellFormat(10, 5, sym, "", 0, "C", bg, 0, "")
			f.SetFont("Helvetica", "", 8)
			setColor(17, 24, 39)
			f.CellFormat(145, 5, sanitize(item.Item), "", 0, "L", bg, 0, "")
			setColor(107, 114, 128)
			f.CellFormat(25, 5, lbl, "", 1, "L", bg, 0, "")
		}
		setColor(17, 24, 39)
	}

	// ─── INSPECTION ITEMS ────────────────────────────────────────────────────

	if booking.ServiceType == "inspeksi" && len(report.InspectionItems) > 0 {
		sectionHeader("ITEM INSPEKSI")

		// Table header
		setFill(243, 244, 246)
		setColor(107, 114, 128)
		setDraw(229, 231, 235)
		f.SetFont("Helvetica", "B", 7)
		f.CellFormat(8, 6, "No", "1", 0, "C", true, 0, "")
		f.CellFormat(22, 6, "Tipe", "1", 0, "C", true, 0, "")
		f.CellFormat(25, 6, "Kode", "1", 0, "C", true, 0, "")
		f.CellFormat(55, 6, "Lokasi", "1", 0, "C", true, 0, "")
		f.CellFormat(30, 6, "Kondisi", "1", 0, "C", true, 0, "")
		f.CellFormat(40, 6, "Rekomendasi", "1", 1, "C", true, 0, "")

		condLabel := map[string]string{
			"good":     "Baik",
			"wear":     "Aus",
			"cracked":  "Retak",
			"leaking":  "Bocor",
			"critical": "Kritis",
		}
		recLabel := map[string]string{
			"no_action":        "Tidak perlu",
			"monitor":          "Pantau",
			"schedule_replace": "Jadwal ganti",
			"urgent_replace":   "Ganti segera",
		}

		setColor(17, 24, 39)
		for i, item := range report.InspectionItems {
			bg := i%2 == 1
			if bg {
				setFill(249, 250, 251)
			} else {
				setFill(255, 255, 255)
			}
			f.SetFont("Helvetica", "", 7)
			f.CellFormat(8, 5, fmt.Sprintf("%d", i+1), "1", 0, "C", bg, 0, "")
			f.CellFormat(22, 5, sanitize(item.ItemType), "1", 0, "C", bg, 0, "")
			f.CellFormat(25, 5, sanitize(item.ItemCode), "1", 0, "C", bg, 0, "")
			f.CellFormat(55, 5, sanitize(item.LocationDesc), "1", 0, "L", bg, 0, "")
			cond := condLabel[item.Condition]
			if cond == "" {
				cond = item.Condition
			}
			f.CellFormat(30, 5, sanitize(cond), "1", 0, "C", bg, 0, "")
			rec := recLabel[item.Recommendation]
			if rec == "" {
				rec = item.Recommendation
			}
			f.CellFormat(40, 5, sanitize(rec), "1", 1, "L", bg, 0, "")
		}
		setColor(17, 24, 39)
	}

	// ─── WORK DESCRIPTION ────────────────────────────────────────────────────

	sectionHeader("DESKRIPSI PEKERJAAN")
	textBlock(report.WorkDescription)

	// ─── RECOMMENDATIONS ─────────────────────────────────────────────────────

	sectionHeader("REKOMENDASI")
	textBlock(report.Recommendations)

	// ─── PHOTOS ──────────────────────────────────────────────────────────────

	if len(report.PhotoURLs) > 0 {
		sectionHeader("FOTO DOKUMENTASI")
		typeLabel := map[string]string{
			"before": "Sebelum",
			"after":  "Sesudah",
			"damage": "Kerusakan",
		}

		// Download image from URL, validate, then register with fpdf.
		tryEmbedImage := func(url string) bool {
			client := &http.Client{Timeout: 10 * time.Second}
			resp, err := client.Get(url)
			if err != nil || resp.StatusCode != 200 {
				return false
			}
			defer resp.Body.Close()

			imgBytes, err := io.ReadAll(resp.Body)
			if err != nil || len(imgBytes) == 0 {
				return false
			}

			// Validate with Go's image package — if this succeeds, fpdf will too
			_, format, err := stdimage.DecodeConfig(bytes.NewReader(imgBytes))
			if err != nil {
				return false
			}

			imgType := format
			if imgType == "jpeg" {
				imgType = "jpg"
			}
			if imgType != "jpg" && imgType != "png" {
				// Try to detect from URL extension as fallback
				urlNoQuery := strings.SplitN(url, "?", 2)[0]
				ext := strings.TrimPrefix(strings.ToLower(filepath.Ext(urlNoQuery)), ".")
				if ext == "png" {
					imgType = "png"
				} else {
					imgType = "jpg"
				}
			}

			f.RegisterImageOptionsReader(url, gofpdf.ImageOptions{ImageType: imgType}, bytes.NewReader(imgBytes))
			return true
		}

		imgW := pageW * 0.90

		for _, photo := range report.PhotoURLs {
			lbl := typeLabel[photo.Type]
			if lbl == "" {
				lbl = photo.Type
			}

			f.Ln(3)
			// Label
			f.SetFont("Helvetica", "B", 8)
			setColor(107, 114, 128)
			f.CellFormat(pageW, 5, "[ "+lbl+" ]", "", 1, "L", false, 0, "")

			if tryEmbedImage(photo.URL) {
				// Center image horizontally, auto height, flow=true advances Y
				xImg := (pageW-imgW)/2.0 + 15
				f.ImageOptions(photo.URL, xImg, -1, imgW, 0, true, gofpdf.ImageOptions{}, 0, "")
			} else {
				// Fallback: tampilkan URL sebagai teks
				f.SetFont("Helvetica", "I", 7)
				setColor(150, 150, 150)
				f.CellFormat(pageW, 5, "[ Foto tidak dapat ditampilkan ]", "", 1, "C", false, 0, "")
			}
		}
	}

	// ─── SIGNATURE ───────────────────────────────────────────────────────────

	f.Ln(8)
	setDraw(107, 114, 128)
	y := f.GetY()
	f.Line(15, y, 75, y)
	f.Ln(2)
	f.SetFont("Helvetica", "", 8)
	setColor(107, 114, 128)
	f.CellFormat(60, 5, "Tanda tangan teknisi", "", 0, "L", false, 0, "")
	f.SetX(130)
	f.CellFormat(65, 5, "Disetujui oleh pelanggan", "", 1, "L", false, 0, "")
	f.Ln(6)
	f.SetFont("Helvetica", "B", 9)
	setColor(17, 24, 39)
	f.CellFormat(60, 5, sanitize(booking.TechnicianName), "", 1, "L", false, 0, "")

	// ─── FOOTER ──────────────────────────────────────────────────────────────

	f.SetY(278)
	setDraw(229, 231, 235)
	f.Line(15, 278, 195, 278)
	f.Ln(1)
	f.SetFont("Helvetica", "", 7)
	setColor(107, 114, 128)
	f.CellFormat(pageW/2, 4,
		"Dibuat oleh sistem HydroServ · "+time.Now().Format("02 Jan 2006 15:04"),
		"", 0, "L", false, 0, "")
	f.CellFormat(pageW/2, 4, "Laporan ID: "+sanitize(report.ID), "", 0, "R", false, 0, "")

	// ─── OUTPUT ──────────────────────────────────────────────────────────────

	var buf bytes.Buffer
	if err := f.Output(&buf); err != nil {
		return nil, fmt.Errorf("gagal generate PDF: %w", err)
	}
	return buf.Bytes(), nil
}

func sanitize(s string) string {
	result := make([]byte, 0, len(s))
	for _, r := range s {
		if r < 0x80 {
			result = append(result, byte(r))
		} else if r <= 0xFF {
			result = append(result, byte(r))
		} else {
			result = append(result, '?')
		}
	}
	return string(result)
}
