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

		// ── helpers ──────────────────────────────────────────────────────────

		type col struct {
			label string
			w     float64
		}

		// Extract a string/number value from Specifications JSONB map
		getSpec := func(specs map[string]interface{}, key string) string {
			v, ok := specs[key]
			if !ok {
				return "-"
			}
			switch vt := v.(type) {
			case string:
				if vt == "" {
					return "-"
				}
				return vt
			case float64:
				if vt == 0 {
					return "-"
				}
				if vt == float64(int64(vt)) {
					return fmt.Sprintf("%d", int64(vt))
				}
				return fmt.Sprintf("%.1f", vt)
			default:
				s := fmt.Sprintf("%v", v)
				if s == "0" {
					return "-"
				}
				return s
			}
		}

		// Format a fitting end: "FEMALE ORFS STRAIGHT", "MALE FLANGE-62 90DEG"
		fmtFitting := func(specs map[string]interface{}, endKey string) string {
			raw, ok := specs[endKey]
			if !ok {
				return "-"
			}
			m, ok := raw.(map[string]interface{})
			if !ok {
				return "-"
			}
			gender := strings.ToUpper(fmt.Sprintf("%v", m["gender"]))
			stdRaw := fmt.Sprintf("%v", m["standard"])
			var std string
			switch stdRaw {
			case "SAE_F61":
				std = "FLANGE-61"
			case "SAE_F62":
				std = "FLANGE-62"
			default:
				std = strings.ToUpper(stdRaw)
			}
			angleRaw := fmt.Sprintf("%v", m["angle"])
			var angle string
			switch angleRaw {
			case "straight":
				angle = "STRAIGHT"
			case "45":
				angle = "45DEG"
			case "90":
				angle = "90DEG"
			case "90_long":
				angle = "90LONG"
			default:
				angle = strings.ToUpper(angleRaw)
			}
			return gender + " " + std + " " + angle
		}

		// Light gray sub-section divider between type tables
		subHeader := func(title string) {
			f.Ln(3)
			setFill(229, 231, 235)
			setColor(55, 65, 81)
			setDraw(209, 213, 219)
			f.SetFont("Helvetica", "B", 8)
			f.CellFormat(pageW, 6, "  "+title, "1", 1, "L", true, 0, "")
			setColor(17, 24, 39)
			f.Ln(1)
		}

		// Print a table header row
		tableHeader := func(cols []col) {
			setFill(243, 244, 246)
			setColor(107, 114, 128)
			setDraw(229, 231, 235)
			f.SetFont("Helvetica", "B", 7)
			for i, c := range cols {
				ln := 0
				if i == len(cols)-1 {
					ln = 1
				}
				f.CellFormat(c.w, 6, c.label, "1", ln, "C", true, 0, "")
			}
			setColor(17, 24, 39)
		}

		// ── shared label maps ─────────────────────────────────────────────

		condLabel := map[string]string{
			"good": "Baik", "wear": "Aus", "cracked": "Retak",
			"leaking": "Bocor", "critical": "Kritis",
		}
		recLabel := map[string]string{
			"no_action": "Tidak perlu", "monitor": "Pantau",
			"schedule_replace": "Jdwl ganti", "urgent_replace": "Ganti segera",
		}

		// ── group items by type ───────────────────────────────────────────

		var hoses, cylinders, pumps []domain.InspectionItem
		for _, it := range report.InspectionItems {
			switch it.ItemType {
			case "hose":
				hoses = append(hoses, it)
			case "cylinder":
				cylinders = append(cylinders, it)
			case "pump":
				pumps = append(pumps, it)
			}
		}

		// ── HOSE table ────────────────────────────────────────────────────
		// No(7) | Hose(45) | Bar(12) | Fitting 1(58) | Fitting 2(58) = 180

		if len(hoses) > 0 {
			subHeader("HOSE")
			tableHeader([]col{
				{"No", 7}, {"Hose", 45}, {"Bar", 12},
				{"Fitting 1", 58}, {"Fitting 2", 58},
			})
			for i, item := range hoses {
				bg := i%2 == 1
				if bg {
					setFill(249, 250, 251)
				} else {
					setFill(255, 255, 255)
				}
				dia      := getSpec(item.Specifications, "diameter_inch")
				pjg      := getSpec(item.Specifications, "length_m")
				hoseCell := sanitize(item.ItemCode)
				if dia != "-" {
					hoseCell += " " + dia + `"`
				}
				if pjg != "-" {
					hoseCell += " " + pjg + "m"
				}
				bar  := getSpec(item.Specifications, "pressure_bar")
				fit1 := fmtFitting(item.Specifications, "fitting_end1")
				fit2 := fmtFitting(item.Specifications, "fitting_end2")

				f.SetFont("Helvetica", "", 7)
				f.CellFormat(7, 5, fmt.Sprintf("%d", i+1), "1", 0, "C", bg, 0, "")
				f.CellFormat(45, 5, sanitize(hoseCell), "1", 0, "L", bg, 0, "")
				f.CellFormat(12, 5, bar, "1", 0, "C", bg, 0, "")
				f.CellFormat(58, 5, sanitize(fit1), "1", 0, "L", bg, 0, "")
				f.CellFormat(58, 5, sanitize(fit2), "1", 1, "L", bg, 0, "")
			}
		}

		// ── CYLINDER table ────────────────────────────────────────────────
		// No(7) | Kode(25) | Bore(20) | Stroke(20) | Bar(15) | Rod(46) | Seal(47) = 180

		if len(cylinders) > 0 {
			subHeader("CYLINDER")
			tableHeader([]col{
				{"No", 7}, {"Kode", 25}, {"Bore", 20}, {"Stroke", 20},
				{"Bar", 15}, {"Kondisi Rod", 46}, {"Kondisi Seal", 47},
			})
			for i, item := range cylinders {
				bg := i%2 == 1
				if bg {
					setFill(249, 250, 251)
				} else {
					setFill(255, 255, 255)
				}
				bore   := getSpec(item.Specifications, "bore_mm")
				if bore != "-" {
					bore += " mm"
				}
				stroke := getSpec(item.Specifications, "stroke_mm")
				if stroke != "-" {
					stroke += " mm"
				}
				bar      := getSpec(item.Specifications, "pressure_bar")
				rodRaw   := getSpec(item.Specifications, "rod_condition")
				sealRaw  := getSpec(item.Specifications, "seal_condition")
				rodCond  := condLabel[rodRaw]
				if rodCond == "" {
					rodCond = rodRaw
				}
				sealCond := condLabel[sealRaw]
				if sealCond == "" {
					sealCond = sealRaw
				}

				f.SetFont("Helvetica", "", 7)
				f.CellFormat(7, 5, fmt.Sprintf("%d", i+1), "1", 0, "C", bg, 0, "")
				f.CellFormat(25, 5, sanitize(item.ItemCode), "1", 0, "L", bg, 0, "")
				f.CellFormat(20, 5, bore, "1", 0, "C", bg, 0, "")
				f.CellFormat(20, 5, stroke, "1", 0, "C", bg, 0, "")
				f.CellFormat(15, 5, bar, "1", 0, "C", bg, 0, "")
				f.CellFormat(46, 5, sanitize(rodCond), "1", 0, "C", bg, 0, "")
				f.CellFormat(47, 5, sanitize(sealCond), "1", 1, "C", bg, 0, "")
			}
		}

		// ── PUMP table ────────────────────────────────────────────────────
		// No(7) | Kode(25) | Tipe(40) | Flow(20) | Bar(15) | Noise(35) | Suhu(38) = 180

		if len(pumps) > 0 {
			subHeader("PUMP")
			tableHeader([]col{
				{"No", 7}, {"Kode", 25}, {"Tipe Pompa", 40}, {"Flow", 20},
				{"Bar", 15}, {"Noise", 35}, {"Suhu", 38},
			})
			for i, item := range pumps {
				bg := i%2 == 1
				if bg {
					setFill(249, 250, 251)
				} else {
					setFill(255, 255, 255)
				}
				pumpType := getSpec(item.Specifications, "pump_type")
				flow     := getSpec(item.Specifications, "flow_lpm")
				if flow != "-" {
					flow += " lpm"
				}
				bar   := getSpec(item.Specifications, "pressure_bar")
				noise := getSpec(item.Specifications, "noise_level")
				temp  := getSpec(item.Specifications, "temperature_c")
				if temp != "-" {
					temp += " C"
				}

				f.SetFont("Helvetica", "", 7)
				f.CellFormat(7, 5, fmt.Sprintf("%d", i+1), "1", 0, "C", bg, 0, "")
				f.CellFormat(25, 5, sanitize(item.ItemCode), "1", 0, "L", bg, 0, "")
				f.CellFormat(40, 5, sanitize(pumpType), "1", 0, "L", bg, 0, "")
				f.CellFormat(20, 5, flow, "1", 0, "C", bg, 0, "")
				f.CellFormat(15, 5, bar, "1", 0, "C", bg, 0, "")
				f.CellFormat(35, 5, sanitize(noise), "1", 0, "C", bg, 0, "")
				f.CellFormat(38, 5, temp, "1", 1, "C", bg, 0, "")
			}
		}

		// ── RINGKASAN KONDISI ─────────────────────────────────────────────
		// No(8) | Tipe(22) | Kode(25) | Lokasi(75) | Kondisi(25) | Rek(25) = 180

		subHeader("RINGKASAN KONDISI")
		tableHeader([]col{
			{"No", 8}, {"Tipe", 22}, {"Kode", 25}, {"Lokasi", 75},
			{"Kondisi", 25}, {"Rekomendasi", 25},
		})
		typeLabel := map[string]string{
			"hose": "Hose", "cylinder": "Cylinder", "pump": "Pump",
		}
		for i, item := range report.InspectionItems {
			bg := i%2 == 1
			if bg {
				setFill(249, 250, 251)
			} else {
				setFill(255, 255, 255)
			}
			tl := typeLabel[item.ItemType]
			if tl == "" {
				tl = item.ItemType
			}
			cond := condLabel[item.Condition]
			if cond == "" {
				cond = item.Condition
			}
			rec := recLabel[item.Recommendation]
			if rec == "" {
				rec = item.Recommendation
			}
			f.SetFont("Helvetica", "", 7)
			f.CellFormat(8, 5, fmt.Sprintf("%d", i+1), "1", 0, "C", bg, 0, "")
			f.CellFormat(22, 5, sanitize(tl), "1", 0, "C", bg, 0, "")
			f.CellFormat(25, 5, sanitize(item.ItemCode), "1", 0, "L", bg, 0, "")
			f.CellFormat(75, 5, sanitize(item.LocationDesc), "1", 0, "L", bg, 0, "")
			f.CellFormat(25, 5, sanitize(cond), "1", 0, "C", bg, 0, "")
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
