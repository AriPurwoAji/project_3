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

		condLabel := map[string]string{
			"good": "Baik", "wear": "Aus", "cracked": "Retak",
			"leaking": "Bocor", "critical": "Kritis",
		}
		recLabel := map[string]string{
			"no_action": "Tidak perlu", "monitor": "Pantau",
			"schedule_replace": "Jadwal ganti", "urgent_replace": "Ganti segera",
		}

		getSpec := func(specs map[string]interface{}, key string) string {
			v, ok := specs[key]
			if !ok {
				return "-"
			}
			switch val := v.(type) {
			case string:
				if val == "" {
					return "-"
				}
				return val
			case float64:
				if val == float64(int(val)) {
					return fmt.Sprintf("%d", int(val))
				}
				return fmt.Sprintf("%.1f", val)
			default:
				return fmt.Sprintf("%v", v)
			}
		}

		fmtFitting := func(specs map[string]interface{}, key string) string {
			raw, ok := specs[key]
			if !ok {
				return "-"
			}
			fm, ok := raw.(map[string]interface{})
			if !ok {
				return "-"
			}
			g, _ := fm["gender"].(string)
			s, _ := fm["standard"].(string)
			a, _ := fm["angle"].(string)
			switch a {
			case "straight":
				a = "STRAIGHT"
			case "45":
				a = "45DEG"
			case "90":
				a = "90DEG"
			case "90_long":
				a = "90LONG"
			default:
				a = strings.ToUpper(a)
			}
			return strings.ToUpper(g) + " " + strings.ToUpper(s) + " " + a
		}

		subHeader := func(title string) {
			f.Ln(1)
			f.SetFont("Helvetica", "B", 7)
			setColor(37, 99, 235)
			setFill(235, 242, 255)
			f.CellFormat(pageW, 5, "  "+title, "", 1, "L", true, 0, "")
			f.Ln(1)
			setColor(17, 24, 39)
		}

		var hoseItems, cylItems, pumpItems []domain.InspectionItem
		for _, item := range report.InspectionItems {
			switch item.ItemType {
			case "hose":
				hoseItems = append(hoseItems, item)
			case "cylinder":
				cylItems = append(cylItems, item)
			case "pump":
				pumpItems = append(pumpItems, item)
			}
		}

		itemNo := 1

		// ── SELANG (HOSE) ──
		// No(7) Kode(20) Pjg(16) Dia(16) Bar(16) Fitting1(52) Fitting2(53) = 180
		if len(hoseItems) > 0 {
			subHeader("Selang (Hose)")
			setFill(243, 244, 246)
			setColor(107, 114, 128)
			setDraw(229, 231, 235)
			f.SetFont("Helvetica", "B", 6)
			f.CellFormat(7, 6, "No", "1", 0, "C", true, 0, "")
			f.CellFormat(20, 6, "Kode", "1", 0, "C", true, 0, "")
			f.CellFormat(16, 6, "Pjg(m)", "1", 0, "C", true, 0, "")
			f.CellFormat(16, 6, "Dia", "1", 0, "C", true, 0, "")
			f.CellFormat(16, 6, "Bar", "1", 0, "C", true, 0, "")
			f.CellFormat(52, 6, "Fitting 1", "1", 0, "C", true, 0, "")
			f.CellFormat(53, 6, "Fitting 2", "1", 1, "C", true, 0, "")
			setColor(17, 24, 39)
			for _, item := range hoseItems {
				bg := itemNo%2 == 1
				if bg {
					setFill(249, 250, 251)
				} else {
					setFill(255, 255, 255)
				}
				specs := item.Specifications
				f.SetFont("Helvetica", "", 6)
				f.CellFormat(7, 5, fmt.Sprintf("%d", itemNo), "1", 0, "C", bg, 0, "")
				f.CellFormat(20, 5, sanitize(item.ItemCode), "1", 0, "C", bg, 0, "")
				f.CellFormat(16, 5, sanitize(getSpec(specs, "length_m")), "1", 0, "C", bg, 0, "")
				f.CellFormat(16, 5, sanitize(getSpec(specs, "diameter_inch")), "1", 0, "C", bg, 0, "")
				f.CellFormat(16, 5, sanitize(getSpec(specs, "pressure_bar")), "1", 0, "C", bg, 0, "")
				f.CellFormat(52, 5, sanitize(fmtFitting(specs, "fitting_end1")), "1", 0, "C", bg, 0, "")
				f.CellFormat(53, 5, sanitize(fmtFitting(specs, "fitting_end2")), "1", 1, "C", bg, 0, "")
				itemNo++
			}
			f.Ln(2)
		}

		// ── SILINDER (CYLINDER) ──
		// No(7) Kode(20) Bore(22) Stroke(22) Bar(18) Rod(45) Seal(46) = 180
		if len(cylItems) > 0 {
			subHeader("Silinder (Cylinder)")
			setFill(243, 244, 246)
			setColor(107, 114, 128)
			setDraw(229, 231, 235)
			f.SetFont("Helvetica", "B", 6)
			f.CellFormat(7, 6, "No", "1", 0, "C", true, 0, "")
			f.CellFormat(20, 6, "Kode", "1", 0, "C", true, 0, "")
			f.CellFormat(22, 6, "Bore(mm)", "1", 0, "C", true, 0, "")
			f.CellFormat(22, 6, "Stroke(mm)", "1", 0, "C", true, 0, "")
			f.CellFormat(18, 6, "Bar", "1", 0, "C", true, 0, "")
			f.CellFormat(45, 6, "Kondisi Rod", "1", 0, "C", true, 0, "")
			f.CellFormat(46, 6, "Kondisi Seal", "1", 1, "C", true, 0, "")
			cylCond := map[string]string{
				"good": "Baik", "wear": "Aus", "cracked": "Retak", "leaking": "Bocor",
			}
			setColor(17, 24, 39)
			for _, item := range cylItems {
				bg := itemNo%2 == 1
				if bg {
					setFill(249, 250, 251)
				} else {
					setFill(255, 255, 255)
				}
				specs := item.Specifications
				rodCond, _ := specs["rod_condition"].(string)
				sealCond, _ := specs["seal_condition"].(string)
				if lbl := cylCond[rodCond]; lbl != "" {
					rodCond = lbl
				}
				if lbl := cylCond[sealCond]; lbl != "" {
					sealCond = lbl
				}
				f.SetFont("Helvetica", "", 6)
				f.CellFormat(7, 5, fmt.Sprintf("%d", itemNo), "1", 0, "C", bg, 0, "")
				f.CellFormat(20, 5, sanitize(item.ItemCode), "1", 0, "C", bg, 0, "")
				f.CellFormat(22, 5, sanitize(getSpec(specs, "bore_mm")), "1", 0, "C", bg, 0, "")
				f.CellFormat(22, 5, sanitize(getSpec(specs, "stroke_mm")), "1", 0, "C", bg, 0, "")
				f.CellFormat(18, 5, sanitize(getSpec(specs, "pressure_bar")), "1", 0, "C", bg, 0, "")
				f.CellFormat(45, 5, sanitize(rodCond), "1", 0, "C", bg, 0, "")
				f.CellFormat(46, 5, sanitize(sealCond), "1", 1, "C", bg, 0, "")
				itemNo++
			}
			f.Ln(2)
		}

		// ── POMPA (PUMP) ──
		// No(7) Kode(20) Tipe(40) Flow(20) Bar(18) Noise(35) Suhu(40) = 180
		if len(pumpItems) > 0 {
			subHeader("Pompa (Pump)")
			setFill(243, 244, 246)
			setColor(107, 114, 128)
			setDraw(229, 231, 235)
			f.SetFont("Helvetica", "B", 6)
			f.CellFormat(7, 6, "No", "1", 0, "C", true, 0, "")
			f.CellFormat(20, 6, "Kode", "1", 0, "C", true, 0, "")
			f.CellFormat(40, 6, "Tipe Pompa", "1", 0, "C", true, 0, "")
			f.CellFormat(20, 6, "Flow(lpm)", "1", 0, "C", true, 0, "")
			f.CellFormat(18, 6, "Bar", "1", 0, "C", true, 0, "")
			f.CellFormat(35, 6, "Noise Level", "1", 0, "C", true, 0, "")
			f.CellFormat(40, 6, "Suhu(C)", "1", 1, "C", true, 0, "")
			setColor(17, 24, 39)
			for _, item := range pumpItems {
				bg := itemNo%2 == 1
				if bg {
					setFill(249, 250, 251)
				} else {
					setFill(255, 255, 255)
				}
				specs := item.Specifications
				f.SetFont("Helvetica", "", 6)
				f.CellFormat(7, 5, fmt.Sprintf("%d", itemNo), "1", 0, "C", bg, 0, "")
				f.CellFormat(20, 5, sanitize(item.ItemCode), "1", 0, "C", bg, 0, "")
				f.CellFormat(40, 5, sanitize(getSpec(specs, "pump_type")), "1", 0, "L", bg, 0, "")
				f.CellFormat(20, 5, sanitize(getSpec(specs, "flow_lpm")), "1", 0, "C", bg, 0, "")
				f.CellFormat(18, 5, sanitize(getSpec(specs, "pressure_bar")), "1", 0, "C", bg, 0, "")
				f.CellFormat(35, 5, sanitize(getSpec(specs, "noise_level")), "1", 0, "C", bg, 0, "")
				f.CellFormat(40, 5, sanitize(getSpec(specs, "temperature_c")), "1", 1, "C", bg, 0, "")
				itemNo++
			}
			f.Ln(2)
		}

		// ── RINGKASAN KONDISI & REKOMENDASI ──
		// No(8) Tipe(22) Kode(25) Lokasi(80) Kondisi(20) Rek(25) = 180
		subHeader("Kondisi & Rekomendasi")
		setFill(243, 244, 246)
		setColor(107, 114, 128)
		setDraw(229, 231, 235)
		f.SetFont("Helvetica", "B", 6)
		f.CellFormat(8, 6, "No", "1", 0, "C", true, 0, "")
		f.CellFormat(22, 6, "Tipe", "1", 0, "C", true, 0, "")
		f.CellFormat(25, 6, "Kode", "1", 0, "C", true, 0, "")
		f.CellFormat(80, 6, "Lokasi", "1", 0, "C", true, 0, "")
		f.CellFormat(20, 6, "Kondisi", "1", 0, "C", true, 0, "")
		f.CellFormat(25, 6, "Rekomendasi", "1", 1, "C", true, 0, "")
		typeLabel := map[string]string{"hose": "Selang", "cylinder": "Silinder", "pump": "Pompa"}
		setColor(17, 24, 39)
		for i, item := range report.InspectionItems {
			bg := i%2 == 0
			if bg {
				setFill(249, 250, 251)
			} else {
				setFill(255, 255, 255)
			}
			cond := condLabel[item.Condition]
			if cond == "" {
				cond = item.Condition
			}
			rec := recLabel[item.Recommendation]
			if rec == "" {
				rec = item.Recommendation
			}
			tl := typeLabel[item.ItemType]
			if tl == "" {
				tl = item.ItemType
			}
			f.SetFont("Helvetica", "", 6)
			f.CellFormat(8, 5, fmt.Sprintf("%d", i+1), "1", 0, "C", bg, 0, "")
			f.CellFormat(22, 5, sanitize(tl), "1", 0, "L", bg, 0, "")
			f.CellFormat(25, 5, sanitize(item.ItemCode), "1", 0, "L", bg, 0, "")
			f.CellFormat(80, 5, sanitize(item.LocationDesc), "1", 0, "L", bg, 0, "")
			f.CellFormat(20, 5, sanitize(cond), "1", 0, "C", bg, 0, "")
			f.CellFormat(25, 5, sanitize(rec), "1", 1, "L", bg, 0, "")
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
