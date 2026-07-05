#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate Laporan Project 3 HydroServ — format .docx
Prodi TI, Institut Teknologi dan Bisnis Bina Sarana Global
"""

from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

# ──────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────

def setup_run(run, bold=False, italic=False, size=12, name='Times New Roman'):
    run.font.name = name
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic

def setup_para(para, align=WD_ALIGN_PARAGRAPH.JUSTIFY,
               space_before=0, space_after=6,
               ls=1.5, indent=None):
    para.alignment = align
    pf = para.paragraph_format
    pf.space_before = Pt(space_before)
    pf.space_after  = Pt(space_after)
    pf.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
    pf.line_spacing = ls
    if indent is not None:
        pf.first_line_indent = Cm(indent)

def body(doc, text, bold=False, italic=False,
         align=WD_ALIGN_PARAGRAPH.JUSTIFY, space_after=6, indent=1.27):
    p = doc.add_paragraph()
    r = p.add_run(text)
    setup_run(r, bold=bold, italic=italic)
    setup_para(p, align=align, space_after=space_after, indent=indent)
    return p

def center(doc, text, bold=False, italic=False, size=12, space_before=0, space_after=6):
    p = doc.add_paragraph()
    r = p.add_run(text)
    setup_run(r, bold=bold, italic=italic, size=size)
    setup_para(p, align=WD_ALIGN_PARAGRAPH.CENTER,
               space_before=space_before, space_after=space_after, indent=None)
    return p

def h_bab(doc, text):
    """BAB heading — center, bold, 14pt"""
    p = doc.add_paragraph()
    r = p.add_run(text)
    setup_run(r, bold=True, size=14)
    setup_para(p, align=WD_ALIGN_PARAGRAPH.CENTER,
               space_before=0, space_after=18, indent=None)
    return p

def h1(doc, text):
    """Sub-heading level 1 — bold 12pt, left"""
    p = doc.add_paragraph()
    r = p.add_run(text)
    setup_run(r, bold=True)
    setup_para(p, align=WD_ALIGN_PARAGRAPH.LEFT,
               space_before=12, space_after=6, indent=None)
    return p

def h2(doc, text):
    """Sub-heading level 2 — bold 12pt, left"""
    p = doc.add_paragraph()
    r = p.add_run(text)
    setup_run(r, bold=True)
    setup_para(p, align=WD_ALIGN_PARAGRAPH.LEFT,
               space_before=6, space_after=6, indent=None)
    return p

def numbered_list(doc, items, start=1, indent=1.27):
    for i, item in enumerate(items, start):
        p = doc.add_paragraph()
        r = p.add_run(f'{i}.\t{item}')
        setup_run(r)
        setup_para(p, space_after=6, indent=None)
        pf = p.paragraph_format
        pf.left_indent = Cm(indent)
        pf.first_line_indent = Cm(-indent)

def bullet_list(doc, items, indent=1.0):
    for item in items:
        p = doc.add_paragraph()
        r = p.add_run(f'•\t{item}')
        setup_run(r)
        setup_para(p, space_after=4, indent=None)
        pf = p.paragraph_format
        pf.left_indent = Cm(indent)
        pf.first_line_indent = Cm(-0.5)

def page_break(doc):
    doc.add_page_break()

def caption(doc, text):
    p = doc.add_paragraph()
    r = p.add_run(text)
    setup_run(r, italic=True)
    setup_para(p, align=WD_ALIGN_PARAGRAPH.CENTER,
               space_before=2, space_after=12, indent=None)

def placeholder(doc, text):
    p = doc.add_paragraph()
    r = p.add_run(text)
    setup_run(r, italic=True)
    r.font.color.rgb = RGBColor(0x80, 0x80, 0x80)
    setup_para(p, align=WD_ALIGN_PARAGRAPH.CENTER, space_after=8, indent=None)

def simple_table(doc, headers, rows, font_size=10):
    t = doc.add_table(rows=1+len(rows), cols=len(headers))
    t.style = 'Table Grid'
    # header
    hrow = t.rows[0]
    for j, h in enumerate(headers):
        c = hrow.cells[j]
        c.text = h
        for para in c.paragraphs:
            para.alignment = WD_ALIGN_PARAGRAPH.CENTER
            for run in para.runs:
                run.font.name = 'Times New Roman'
                run.font.size = Pt(font_size)
                run.font.bold = True
    # data
    for i, row_data in enumerate(rows, 1):
        row = t.rows[i]
        for j, val in enumerate(row_data):
            c = row.cells[j]
            c.text = str(val)
            for para in c.paragraphs:
                for run in para.runs:
                    run.font.name = 'Times New Roman'
                    run.font.size = Pt(font_size)
    return t


# ──────────────────────────────────────────────
# MAIN BUILDER
# ──────────────────────────────────────────────

def build():
    doc = Document()

    # Page setup A4
    for sec in doc.sections:
        sec.page_height  = Cm(29.7)
        sec.page_width   = Cm(21.0)
        sec.left_margin  = Cm(4.0)
        sec.right_margin = Cm(3.0)
        sec.top_margin   = Cm(3.0)
        sec.bottom_margin = Cm(3.0)

    # Default style
    style = doc.styles['Normal']
    style.font.name = 'Times New Roman'
    style.font.size = Pt(12)
    pf = style.paragraph_format
    pf.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
    pf.line_spacing = 1.5

    # ═══════════════════════════════════════════
    # HALAMAN JUDUL
    # ═══════════════════════════════════════════
    center(doc, 'RANCANG BANGUN APLIKASI MOBILE MANAJEMEN JASA\nSERVIS HIDROLIK BERBASIS ANDROID\n(Studi Kasus: [NAMA PERUSAHAAN])',
           bold=True, size=14, space_before=60, space_after=18)

    center(doc, 'LAPORAN PROJECT 3', bold=True, size=12, space_after=6)

    center(doc, 'Diajukan sebagai syarat untuk memperoleh gelar Sarjana Komputer\npada Program Studi Teknologi Informasi',
           size=12, space_after=30)

    placeholder(doc, '[SISIPKAN LOGO ITB BSG]')

    center(doc, 'Disusun Oleh:', size=12, space_after=4)
    center(doc, 'Ari Purwo Aji\t\t1123150126', size=12, space_after=2)
    center(doc, 'Rian Maulana\t\t1123150061', size=12, space_after=36)

    center(doc, 'PROGRAM STUDI TEKNOLOGI INFORMASI\nINSTITUT TEKNOLOGI DAN BISNIS BINA SARANA GLOBAL\nTANGERANG\n2026',
           bold=True, size=12, space_after=0)

    page_break(doc)

    # ═══════════════════════════════════════════
    # LEMBAR PERSETUJUAN
    # ═══════════════════════════════════════════
    h_bab(doc, 'LEMBAR PERSETUJUAN DAN PENGESAHAN\nLAPORAN PROJECT 3')

    center(doc, 'RANCANG BANGUN APLIKASI MOBILE MANAJEMEN JASA SERVIS HIDROLIK\nBERBASIS ANDROID\n(Studi Kasus: [NAMA PERUSAHAAN])',
           bold=True, space_after=12)
    center(doc, 'Dipersiapkan dan disusun oleh:', space_after=4)
    center(doc, 'Ari Purwo Aji\t\t\t1123150126\nRian Maulana\t\t\t1123150061', space_after=12)
    center(doc, 'Telah disetujui dan disidangkan sebagai Laporan Project 3\npada Program Studi Teknologi Informasi\nInstitut Teknologi dan Bisnis Bina Sarana Global',
           space_after=24)
    center(doc, 'Tangerang, ........................... 2026', space_after=48)

    # Tanda tangan 2 kolom dengan tabel invisible
    tbl = doc.add_table(rows=3, cols=2)
    cells = [
        ['Dosen Pembimbing,', 'Dosen Penguji,'],
        ['', ''],
        ['Halim Agung, M.Kom., M.M., MOS', '.......................................'],
    ]
    for ri, row in enumerate(cells):
        for ci, val in enumerate(row):
            c = tbl.rows[ri].cells[ci]
            c.text = val
            for para in c.paragraphs:
                para.alignment = WD_ALIGN_PARAGRAPH.CENTER
                for run in para.runs:
                    run.font.name = 'Times New Roman'
                    run.font.size = Pt(12)
                    if ri == 2:
                        run.font.bold = True
    # hilangkan border tabel
    for row in tbl.rows:
        for cell in row.cells:
            tc = cell._tc
            tcPr = tc.get_or_add_tcPr()
            tcBorders = OxmlElement('w:tcBorders')
            for side in ['top','left','bottom','right','insideH','insideV']:
                el = OxmlElement(f'w:{side}')
                el.set(qn('w:val'), 'none')
                tcBorders.append(el)
            tcPr.append(tcBorders)

    doc.add_paragraph()
    center(doc, 'Mengetahui,\nKetua Program Studi Teknologi Informasi', space_after=48)
    center(doc, '.......................................', space_after=6)
    center(doc, 'NIDN. ......................', space_after=0)

    page_break(doc)

    # ═══════════════════════════════════════════
    # KATA PENGANTAR
    # ═══════════════════════════════════════════
    h_bab(doc, 'KATA PENGANTAR')

    body(doc, 'Puji syukur penulis panjatkan ke hadirat Tuhan Yang Maha Esa atas segala rahmat dan karunia-Nya, sehingga penulis dapat menyelesaikan laporan Project 3 yang berjudul "Rancang Bangun Aplikasi Mobile Manajemen Jasa Servis Hidrolik Berbasis Android (Studi Kasus: [NAMA PERUSAHAAN])" dengan baik dan tepat waktu.')

    body(doc, 'Laporan ini disusun sebagai salah satu syarat kelulusan pada Program Studi Teknologi Informasi di Institut Teknologi dan Bisnis Bina Sarana Global. Dalam proses penyusunan laporan ini, penulis mendapatkan banyak bantuan, bimbingan, dan dukungan dari berbagai pihak. Oleh karena itu, penulis mengucapkan terima kasih yang sebesar-besarnya kepada:')

    numbered_list(doc, [
        'Bapak/Ibu ......................., selaku Rektor Institut Teknologi dan Bisnis Bina Sarana Global.',
        'Bapak/Ibu ......................., selaku Dekan Fakultas Teknologi Informasi.',
        'Bapak/Ibu ......................., selaku Ketua Program Studi Teknologi Informasi.',
        'Bapak Halim Agung, M.Kom., M.M., MOS, selaku Dosen Pembimbing yang telah memberikan arahan, bimbingan, dan masukan yang sangat berharga selama proses penyusunan laporan ini.',
        'Seluruh dosen dan staf Program Studi Teknologi Informasi Institut Teknologi dan Bisnis Bina Sarana Global.',
        'Pihak [NAMA PERUSAHAAN] yang telah memberikan izin dan dukungan selama penelitian berlangsung.',
        'Orang tua dan keluarga yang senantiasa memberikan doa, semangat, dan dukungan moral.',
        'Rekan-rekan mahasiswa yang turut memberikan saran dan motivasi.',
    ])

    body(doc, 'Penulis menyadari bahwa laporan ini masih jauh dari sempurna. Oleh karena itu, penulis mengharapkan kritik dan saran yang konstruktif dari semua pihak demi perbaikan dan penyempurnaan laporan ini. Semoga laporan ini dapat bermanfaat bagi pembaca dan pihak-pihak yang membutuhkan.')

    p_loc = doc.add_paragraph()
    p_loc.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    r = p_loc.add_run('Tangerang, ........................... 2026\n\n\n\nPenulis')
    setup_run(r)
    p_loc.paragraph_format.space_before = Pt(24)
    p_loc.paragraph_format.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
    p_loc.paragraph_format.line_spacing = 1.5

    page_break(doc)

    # ═══════════════════════════════════════════
    # ABSTRAK
    # ═══════════════════════════════════════════
    h_bab(doc, 'ABSTRAK')

    body(doc, '[NAMA PERUSAHAAN] merupakan perusahaan yang bergerak di bidang jasa servis dan pemeliharaan peralatan hidrolik. Proses operasional yang berjalan saat ini masih dilakukan secara manual, mulai dari penerimaan pemesanan servis melalui WhatsApp, penugasan teknisi secara verbal, hingga pembuatan laporan servis di atas kertas. Kondisi ini menyebabkan data rentan hilang, tidak ada visibilitas real-time bagi manajer, dan proses pelaporan tidak terstruktur.')

    body(doc, 'Penelitian ini bertujuan untuk merancang dan membangun aplikasi mobile HydroServ berbasis Android sebagai solusi digitalisasi proses operasional jasa servis hidrolik. Sistem dibangun menggunakan Flutter sebagai framework mobile, Go/Gin sebagai REST API backend, dan PostgreSQL melalui layanan Supabase sebagai basis data. Sistem mendukung empat peran pengguna: client, sales, teknisi, dan manager, masing-masing dengan fitur dan hak akses yang berbeda.')

    body(doc, 'Metode pengembangan yang digunakan adalah Metode Prototype dengan pendekatan analisis OOAD menggunakan UML. Hasil penelitian menunjukkan bahwa aplikasi HydroServ berhasil mendigitalisasi seluruh alur proses servis dari pemesanan, penugasan teknisi, pembaruan status real-time, pembuatan laporan teknis dengan foto dan generate dokumen PDF, push notification otomatis, hingga dashboard monitoring untuk manajer.')

    p_kw = doc.add_paragraph()
    setup_para(p_kw, space_after=6, indent=1.27)
    r1 = p_kw.add_run('Kata Kunci: ')
    setup_run(r1, bold=True)
    r2 = p_kw.add_run('Aplikasi Mobile, Android, Hidrolik, Flutter, Go, REST API, Manajemen Servis')
    setup_run(r2)

    page_break(doc)

    # ABSTRACT
    h_bab(doc, 'ABSTRACT')
    body(doc, '[NAMA PERUSAHAAN] is a company engaged in hydraulic equipment service and maintenance. The current operational process is still carried out manually, from receiving service orders through WhatsApp, assigning technicians verbally, to creating service reports on paper. This causes data loss vulnerability, lack of real-time visibility for managers, and unstructured reporting.')
    body(doc, 'This study aims to design and build an Android-based mobile application called HydroServ to digitalize hydraulic service operations. The system is built using Flutter as the mobile framework, Go/Gin as the REST API backend, and PostgreSQL via Supabase as the database, supporting four user roles: client, sales, technician, and manager.')
    body(doc, 'The Prototype Method with OOAD/UML analysis was used in development. Results show that HydroServ successfully digitalizes the entire service workflow from booking, technician assignment, real-time status updates, technical report creation with photos and PDF generation, automatic push notifications, to a manager monitoring dashboard.')

    p_kw2 = doc.add_paragraph()
    setup_para(p_kw2, space_after=6, indent=1.27)
    r3 = p_kw2.add_run('Keywords: ')
    setup_run(r3, bold=True)
    r4 = p_kw2.add_run('Mobile Application, Android, Hydraulic, Flutter, Go, REST API, Service Management')
    setup_run(r4)

    page_break(doc)

    # ═══════════════════════════════════════════
    # DAFTAR ISI
    # ═══════════════════════════════════════════
    h_bab(doc, 'DAFTAR ISI')

    toc = [
        ('HALAMAN JUDUL', 'i', True),
        ('LEMBAR PERSETUJUAN DAN PENGESAHAN', 'ii', True),
        ('KATA PENGANTAR', 'iii', True),
        ('ABSTRAK', 'iv', True),
        ('ABSTRACT', 'v', True),
        ('DAFTAR ISI', 'vi', True),
        ('DAFTAR GAMBAR', 'viii', True),
        ('DAFTAR TABEL', 'ix', True),
        ('BAB I  PENDAHULUAN', '1', True),
        ('1.1  Latar Belakang', '1', False),
        ('1.2  Identifikasi Masalah', '4', False),
        ('1.3  Rumusan Masalah', '5', False),
        ('1.4  Ruang Lingkup', '5', False),
        ('1.5  Tujuan dan Manfaat Penelitian', '6', False),
        ('1.6  Metode Penelitian', '7', False),
        ('1.7  Sistematika Penulisan', '9', False),
        ('BAB II  LANDASAN TEORI', '10', True),
        ('2.1  Konsep Sistem Informasi', '10', False),
        ('2.2  Aplikasi Mobile Android', '11', False),
        ('2.3  REST API', '12', False),
        ('2.4  Flutter', '13', False),
        ('2.5  Go dan Gin Framework', '14', False),
        ('2.6  PostgreSQL dan Supabase', '15', False),
        ('2.7  JWT (JSON Web Token)', '16', False),
        ('2.8  Firebase Cloud Messaging (FCM)', '17', False),
        ('2.9  Metode Prototype', '18', False),
        ('2.10  OOAD dan UML', '19', False),
        ('2.11  Elisitasi', '20', False),
        ('2.12  Literature Review', '21', False),
        ('BAB III  ANALISIS SISTEM YANG BERJALAN', '25', True),
        ('3.1  Gambaran Umum Perusahaan', '25', False),
        ('3.2  Tata Laksana Sistem yang Berjalan', '28', False),
        ('3.3  Analisis Sistem yang Berjalan', '30', False),
        ('3.4  Elisitasi', '32', False),
        ('BAB IV  RANCANGAN SISTEM YANG DIUSULKAN', '38', True),
        ('4.1  Rancangan Sistem Usulan', '38', False),
        ('4.2  Diagram UML', '39', False),
        ('4.3  Rancangan Basis Data', '55', False),
        ('4.4  Rancangan Antarmuka', '60', False),
        ('4.5  Implementasi Sistem', '65', False),
        ('4.6  Pengujian Sistem', '70', False),
        ('BAB V  PENUTUP', '78', True),
        ('5.1  Kesimpulan', '78', False),
        ('5.2  Saran', '79', False),
        ('DAFTAR PUSTAKA', '80', True),
        ('LAMPIRAN', '82', True),
    ]

    for label, page, bold in toc:
        p = doc.add_paragraph()
        pf = p.paragraph_format
        pf.space_after = Pt(2)
        pf.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
        pf.line_spacing = 1.5
        # tab stop dengan leader titik
        tabs = OxmlElement('w:tabs')
        tab = OxmlElement('w:tab')
        tab.set(qn('w:val'), 'right')
        tab.set(qn('w:leader'), 'dot')
        tab.set(qn('w:pos'), '8000')
        tabs.append(tab)
        pPr = p._p.get_or_add_pPr()
        pPr.append(tabs)
        r = p.add_run(f'{label}\t{page}')
        setup_run(r, bold=bold)

    page_break(doc)

    # DAFTAR GAMBAR
    h_bab(doc, 'DAFTAR GAMBAR')
    gambar = [
        ('Gambar 2.1', 'Tahapan Metode Prototype', '18'),
        ('Gambar 3.1', 'Struktur Organisasi [NAMA PERUSAHAAN]', '27'),
        ('Gambar 3.2', 'Activity Diagram Sistem yang Berjalan', '29'),
        ('Gambar 4.1', 'Use Case Diagram Sistem HydroServ', '39'),
        ('Gambar 4.2', 'Activity Diagram Alur Booking Servis Hidrolik', '43'),
        ('Gambar 4.3', 'Class Diagram Sistem HydroServ', '46'),
        ('Gambar 4.4', 'Sequence Diagram — Login', '48'),
        ('Gambar 4.5', 'Sequence Diagram — Registrasi Akun Baru', '49'),
        ('Gambar 4.6', 'Sequence Diagram — Buat Booking (Client)', '50'),
        ('Gambar 4.7', 'Sequence Diagram — Claim Booking (Teknisi)', '51'),
        ('Gambar 4.8', 'Sequence Diagram — Update Status Pekerjaan', '52'),
        ('Gambar 4.9', 'Sequence Diagram — Buat Laporan Servis', '53'),
        ('Gambar 4.10', 'Sequence Diagram — Assign Teknisi (Manager)', '54'),
        ('Gambar 4.11', 'Sequence Diagram — Generate dan Unduh PDF Laporan', '55'),
        ('Gambar 4.12', 'Sequence Diagram — Dashboard Monitoring (Manager)', '55'),
        ('Gambar 4.13', 'Sequence Diagram — Push Notifikasi Otomatis', '56'),
        ('Gambar 4.14', 'Entity Relationship Diagram (ERD)', '57'),
        ('Gambar 4.15', 'Tampilan Halaman Login', '61'),
        ('Gambar 4.16', 'Tampilan Halaman Registrasi', '61'),
        ('Gambar 4.17', 'Tampilan Halaman Buat Booking', '62'),
        ('Gambar 4.18', 'Tampilan Halaman Job Board Teknisi', '62'),
        ('Gambar 4.19', 'Tampilan Form Laporan Servis', '63'),
        ('Gambar 4.20', 'Tampilan Detail Laporan Servis', '63'),
        ('Gambar 4.21', 'Tampilan Dashboard Manager', '64'),
        ('Gambar 4.22', 'Tampilan Halaman Notifikasi', '64'),
    ]
    for kode, nama, hal in gambar:
        p = doc.add_paragraph()
        pf = p.paragraph_format
        pf.space_after = Pt(2)
        pf.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
        pf.line_spacing = 1.5
        tabs = OxmlElement('w:tabs')
        tab = OxmlElement('w:tab')
        tab.set(qn('w:val'), 'right'); tab.set(qn('w:leader'), 'dot'); tab.set(qn('w:pos'), '8000')
        tabs.append(tab)
        p._p.get_or_add_pPr().append(tabs)
        r = p.add_run(f'{kode}\t{nama}\t{hal}')
        setup_run(r)

    page_break(doc)

    # DAFTAR TABEL
    h_bab(doc, 'DAFTAR TABEL')
    tabel_list = [
        ('Tabel 3.1', 'Elisitasi Tahap I — Functional Requirement', '32'),
        ('Tabel 3.2', 'Elisitasi Tahap I — Non-Functional Requirement', '34'),
        ('Tabel 3.3', 'Elisitasi Tahap II', '35'),
        ('Tabel 3.4', 'Final Draft Elisitasi', '36'),
        ('Tabel 4.1', 'Spesifikasi Tabel users', '57'),
        ('Tabel 4.2', 'Spesifikasi Tabel companies', '58'),
        ('Tabel 4.3', 'Spesifikasi Tabel hydraulic_equipment', '58'),
        ('Tabel 4.4', 'Spesifikasi Tabel bookings', '59'),
        ('Tabel 4.5', 'Spesifikasi Tabel hydraulic_reports', '60'),
        ('Tabel 4.6', 'Spesifikasi Tabel inspection_items', '60'),
        ('Tabel 4.7', 'Spesifikasi Tabel notifications', '61'),
        ('Tabel 4.8', 'Pengujian Black Box — Autentikasi', '70'),
        ('Tabel 4.9', 'Pengujian Black Box — Booking', '72'),
        ('Tabel 4.10', 'Pengujian Black Box — Job Board dan Status', '73'),
        ('Tabel 4.11', 'Pengujian Black Box — Laporan Servis', '74'),
        ('Tabel 4.12', 'Pengujian Black Box — Dashboard dan Notifikasi', '76'),
    ]
    for kode, nama, hal in tabel_list:
        p = doc.add_paragraph()
        pf = p.paragraph_format
        pf.space_after = Pt(2)
        pf.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
        pf.line_spacing = 1.5
        tabs = OxmlElement('w:tabs')
        tab = OxmlElement('w:tab')
        tab.set(qn('w:val'), 'right'); tab.set(qn('w:leader'), 'dot'); tab.set(qn('w:pos'), '8000')
        tabs.append(tab)
        p._p.get_or_add_pPr().append(tabs)
        r = p.add_run(f'{kode}\t{nama}\t{hal}')
        setup_run(r)

    page_break(doc)

    # ═══════════════════════════════════════════
    # BAB I
    # ═══════════════════════════════════════════
    h_bab(doc, 'BAB I\nPENDAHULUAN')

    h1(doc, '1.1 Latar Belakang')
    body(doc, 'Peralatan hidrolik merupakan komponen kritis yang digunakan secara luas pada sektor manufaktur, konstruksi, pertambangan, dan industri berat lainnya. Keandalan operasional peralatan ini sangat bergantung pada kualitas pemeliharaan dan ketepatan waktu penanganan kerusakan. Keterlambatan servis, apalagi pada kondisi darurat, dapat menyebabkan terhentinya lini produksi yang berujung pada kerugian materil yang signifikan bagi klien.')
    body(doc, '[NAMA PERUSAHAAN] merupakan perusahaan yang bergerak di bidang jasa servis dan pemeliharaan peralatan hidrolik, melayani berbagai klien dari sektor industri di wilayah [KOTA]. Layanan yang diberikan meliputi perbaikan (repair), inspeksi teknis, pemeliharaan berkala (maintenance), hingga penggantian oli hidrolik. Dalam menjalankan operasionalnya, perusahaan melibatkan beberapa peran: manajer yang mengawasi keseluruhan pekerjaan, teknisi yang turun langsung ke lapangan, serta tim sales dan klien yang mengajukan permintaan servis.')
    body(doc, 'Berdasarkan hasil observasi dan wawancara yang dilakukan penulis — yang juga merupakan karyawan di perusahaan tersebut — diketahui bahwa seluruh proses operasional saat ini masih dilakukan secara manual. Permintaan servis diterima melalui pesan WhatsApp atau panggilan telepon, pencatatan order dikerjakan di buku catatan fisik, penugasan teknisi disampaikan secara verbal tanpa dokumentasi tertulis, dan laporan hasil servis dibuat di atas kertas yang rawan hilang atau rusak. Tidak tersedia pula mekanisme untuk memantau posisi dan status pekerjaan teknisi di lapangan secara real-time.')
    body(doc, 'Kondisi tersebut menimbulkan sejumlah permasalahan konkret: data pesanan servis pernah terlewat karena pesan WhatsApp tertimbun, manajer kesulitan mengetahui progres pekerjaan tanpa menelepon teknisi satu per satu, dan klien tidak memperoleh informasi perkembangan pekerjaan secara proaktif. Arsip laporan hasil servis yang tidak terstruktur juga menyulitkan penelusuran riwayat peralatan milik klien.')
    body(doc, 'Perkembangan teknologi mobile computing dan layanan cloud telah membuka peluang untuk mendigitalisasi proses operasional tersebut secara menyeluruh. Flutter, sebagai framework pengembangan aplikasi mobile lintas platform yang dikembangkan oleh Google, memungkinkan pembangunan antarmuka yang modern dan responsif untuk Android dengan satu basis kode. Di sisi server, bahasa pemrograman Go dengan framework Gin menyediakan performa tinggi dan kemudahan pembangunan REST API. Kombinasi ini, bersama layanan database cloud Supabase berbasis PostgreSQL, membentuk fondasi yang solid untuk membangun sistem informasi yang handal.')
    body(doc, 'Berdasarkan latar belakang tersebut, penulis merancang dan membangun sebuah aplikasi mobile bernama HydroServ — sistem informasi manajemen jasa servis hidrolik berbasis Android yang mengintegrasikan seluruh alur kerja operasional perusahaan dalam satu platform digital. Penelitian ini diangkat sebagai topik Project 3 dengan judul:')
    center(doc, '"RANCANG BANGUN APLIKASI MOBILE MANAJEMEN JASA SERVIS HIDROLIK BERBASIS ANDROID\n(Studi Kasus: [NAMA PERUSAHAAN])"',
           bold=True, space_before=6, space_after=12)

    h1(doc, '1.2 Identifikasi Masalah')
    body(doc, 'Berdasarkan hasil observasi langsung dan wawancara dengan teknisi, sales, serta manajer di [NAMA PERUSAHAAN], ditemukan permasalahan-permasalahan sebagai berikut:')
    numbered_list(doc, [
        'Pemesanan jasa servis masih diterima melalui WhatsApp dan telepon tanpa sistem pencatatan terpusat, sehingga data pemesanan rentan hilang atau terlewat di antara banyaknya pesan masuk.',
        'Tidak tersedia mekanisme untuk memantau posisi dan status pekerjaan teknisi di lapangan secara real-time, sehingga manajer harus menghubungi teknisi satu per satu untuk mengetahui perkembangan pekerjaan.',
        'Proses penugasan teknisi kepada suatu pekerjaan dilakukan secara verbal tanpa dokumentasi, sehingga tidak ada rekam jejak yang jelas mengenai siapa mengerjakan apa dan kapan.',
        'Laporan hasil servis dibuat secara manual di atas kertas, tidak tersimpan secara terpusat, dan sulit ditelusuri kembali ketika klien membutuhkan riwayat servis peralatannya.',
        'Klien tidak mendapat notifikasi otomatis mengenai perkembangan status pekerjaan, sehingga harus aktif menghubungi perusahaan untuk mengetahui apakah pekerjaan sudah selesai.',
    ])

    h1(doc, '1.3 Rumusan Masalah')
    body(doc, 'Berdasarkan identifikasi masalah di atas, rumusan masalah dalam penelitian ini adalah:')
    numbered_list(doc, [
        'Bagaimana merancang dan membangun aplikasi mobile berbasis Android yang dapat mengelola proses pemesanan jasa servis hidrolik secara digital dan terstruktur?',
        'Bagaimana sistem dapat memfasilitasi teknisi dalam mencatat dan melaporkan hasil pekerjaan servis secara digital dengan data teknis yang terstandarisasi, termasuk dokumentasi foto dan dokumen PDF yang dapat dibagikan?',
        'Bagaimana sistem dapat memberikan visibilitas real-time kepada manajer terhadap seluruh aktivitas operasional servis melalui fitur dashboard monitoring?',
    ])

    h1(doc, '1.4 Ruang Lingkup')
    body(doc, 'Agar penelitian ini tetap terfokus dan dapat diselesaikan secara optimal, ditetapkan batasan ruang lingkup sebagai berikut:')
    numbered_list(doc, [
        'Sistem yang dibangun adalah aplikasi mobile berbasis Android menggunakan framework Flutter.',
        'Backend sistem menggunakan bahasa pemrograman Go dengan framework Gin sebagai REST API server.',
        'Penyimpanan data menggunakan database PostgreSQL melalui layanan cloud Supabase, dengan penyimpanan file (foto) pada Supabase Storage.',
        'Sistem mencakup empat peran pengguna: client, sales, teknisi, dan manager, masing-masing dengan hak akses yang berbeda dan terpisah.',
        'Fitur yang diimplementasikan meliputi: manajemen data peralatan (equipment) klien, pemesanan servis (booking), job board teknisi, pembaruan status pekerjaan, pembuatan laporan servis hidrolik, push notification via Firebase Cloud Messaging, dan dashboard monitoring manajer.',
        'Sistem tidak mencakup modul pembayaran, penagihan (invoicing), atau manajemen keuangan.',
        'Sistem tidak mencakup manajemen stok suku cadang secara terintegrasi.',
    ])

    h1(doc, '1.5 Tujuan dan Manfaat Penelitian')
    h2(doc, '1.5.1 Tujuan Penelitian')
    body(doc, 'Tujuan dari penelitian ini adalah:')
    numbered_list(doc, [
        'Merancang dan membangun aplikasi mobile berbasis Android untuk mendigitalisasi proses pemesanan dan manajemen pekerjaan jasa servis hidrolik di [NAMA PERUSAHAAN].',
        'Mengimplementasikan fitur pelaporan hasil servis berbasis digital yang mencakup data teknis terstandarisasi (tekanan, kondisi oli, kebocoran), dokumentasi foto kondisi peralatan, dan generate dokumen PDF laporan servis.',
        'Menyediakan dashboard monitoring berbasis data real-time bagi manajer untuk mengawasi kinerja teknisi dan tren operasional perusahaan.',
    ])

    h2(doc, '1.5.2 Manfaat Penelitian')
    manfaat = [
        ('Bagi Perusahaan ([NAMA PERUSAHAAN])',
         'Meningkatkan efisiensi operasional melalui digitalisasi proses pemesanan, penugasan, dan pelaporan servis; meminimalkan risiko kehilangan data; serta menyediakan data historis yang dapat dianalisis untuk perencanaan bisnis dan evaluasi kinerja.'),
        ('Bagi Teknisi',
         'Mempermudah proses klaim pekerjaan secara mandiri, pembaruan status di lapangan secara real-time, dan pembuatan laporan servis langsung dari perangkat mobile tanpa perlu pengisian kertas manual.'),
        ('Bagi Klien',
         'Memberikan transparansi dan kepercayaan melalui visibilitas status pekerjaan secara real-time, notifikasi otomatis perkembangan pekerjaan, serta akses terhadap laporan hasil servis dalam format digital dan PDF.'),
        ('Bagi Penulis',
         'Menerapkan kompetensi yang diperoleh selama perkuliahan Program Studi Teknologi Informasi dalam membangun sistem informasi nyata yang digunakan di lingkungan kerja, menggunakan teknologi modern seperti Flutter, Go, PostgreSQL, REST API, dan Firebase.'),
    ]
    for i, (judul, isi) in enumerate(manfaat, 1):
        p = doc.add_paragraph()
        setup_para(p, space_after=6, indent=None)
        pf = p.paragraph_format
        pf.left_indent = Cm(1.27)
        pf.first_line_indent = Cm(-1.27)
        r_j = p.add_run(f'{i}. {judul}: ')
        setup_run(r_j, bold=True)
        r_i = p.add_run(isi)
        setup_run(r_i)

    h1(doc, '1.6 Metode Penelitian')
    h2(doc, '1.6.1 Metode Pengumpulan Data')
    metode = [
        ('a. Observasi',
         'Penulis melakukan pengamatan langsung terhadap alur kerja operasional di [NAMA PERUSAHAAN] selama periode penelitian. Observasi mencakup proses penerimaan permintaan servis dari klien, mekanisme penugasan teknisi oleh manajer, pelaksanaan servis di lapangan, hingga pelaporan hasil pekerjaan. Observasi dilakukan secara partisipatif karena penulis merupakan karyawan aktif di perusahaan tersebut.'),
        ('b. Wawancara',
         'Penulis melakukan wawancara terstruktur dengan pemangku kepentingan di [NAMA PERUSAHAAN], meliputi: teknisi lapangan, staf sales, dan manajer operasional. Wawancara bertujuan mengidentifikasi kebutuhan fungsional sistem, kendala yang dihadapi pada proses manual, serta harapan pengguna terhadap sistem yang akan dibangun.'),
        ('c. Studi Pustaka',
         'Penulis mempelajari literatur ilmiah dan teknis yang relevan, mencakup: pengembangan aplikasi mobile, arsitektur REST API, sistem informasi manajemen, serta dokumentasi resmi teknologi yang digunakan (Flutter, Go, Gin, PostgreSQL, Firebase). Studi pustaka juga mencakup penelitian terdahulu yang berkaitan dengan digitalisasi sistem operasional di industri jasa teknik.'),
    ]
    for label, isi in metode:
        p = doc.add_paragraph()
        setup_para(p, space_after=6, indent=1.27)
        r_l = p.add_run(label + '\n')
        setup_run(r_l, bold=True)
        r_i = p.add_run(isi)
        setup_run(r_i)

    h2(doc, '1.6.2 Metode Pengembangan Sistem')
    body(doc, 'Pengembangan sistem menggunakan Metode Prototype, yang terdiri dari lima tahapan berulang: (1) Communication — penulis berkomunikasi dengan pengguna untuk memahami kebutuhan; (2) Quick Plan — perencanaan cepat ruang lingkup dan timeline; (3) Quick Design — perancangan antarmuka dan arsitektur sistem; (4) Prototype Build — pembangunan prototipe yang dapat dicoba pengguna; (5) Deployment & Feedback — pengujian oleh pengguna nyata dan pengumpulan umpan balik untuk iterasi berikutnya.')
    body(doc, 'Metode Prototype dipilih karena kebutuhan sistem melibatkan pengguna dari berbagai peran (teknisi lapangan, sales, manajer) yang memiliki ekspektasi berbeda, sehingga umpan balik langsung dari pengguna selama proses pengembangan sangat diperlukan untuk memastikan sistem yang dibangun benar-benar sesuai kebutuhan operasional.')

    h2(doc, '1.6.3 Metode Analisis dan Perancangan Sistem')
    body(doc, 'Analisis dan perancangan sistem menggunakan pendekatan OOAD (Object-Oriented Analysis and Design) dengan notasi UML (Unified Modeling Language). Diagram UML yang digunakan meliputi:')
    numbered_list(doc, [
        'Use Case Diagram: menggambarkan fungsi sistem dari perspektif setiap peran pengguna;',
        'Activity Diagram: menggambarkan alur proses bisnis dari pemesanan hingga penyelesaian laporan servis;',
        'Class Diagram: menggambarkan struktur entitas data dan hubungan antar-kelas dalam sistem;',
        'Sequence Diagram: menggambarkan interaksi antar-komponen sistem dalam skenario tertentu secara berurutan waktu.',
    ])

    h1(doc, '1.7 Sistematika Penulisan')
    body(doc, 'Laporan Project 3 ini disusun dengan sistematika sebagai berikut:')
    sistematika = [
        ('BAB I PENDAHULUAN',
         'Membahas latar belakang pemilihan topik, identifikasi masalah, rumusan masalah, ruang lingkup penelitian, tujuan dan manfaat, metode penelitian, serta sistematika penulisan laporan.'),
        ('BAB II LANDASAN TEORI',
         'Memaparkan teori-teori yang menjadi dasar penelitian, meliputi konsep sistem informasi, aplikasi mobile Android, REST API, teknologi yang digunakan dalam implementasi (Flutter, Go/Gin, PostgreSQL/Supabase, JWT, Firebase), metode prototype, pendekatan OOAD/UML, serta kajian literatur dari penelitian terdahulu yang relevan.'),
        ('BAB III ANALISIS SISTEM YANG BERJALAN',
         'Menguraikan profil dan struktur organisasi [NAMA PERUSAHAAN], tata laksana sistem operasional yang sedang berjalan beserta activity diagram sistem berjalan, analisis permasalahan pada sistem yang ada, serta hasil elisitasi kebutuhan sistem dalam tiga tahap.'),
        ('BAB IV RANCANGAN SISTEM YANG DIUSULKAN',
         'Menjelaskan rancangan sistem usulan secara komprehensif, mencakup diagram UML (Use Case, Activity, Class, Sequence), rancangan basis data (ERD dan spesifikasi tabel), rancangan antarmuka, hasil implementasi sistem disertai screenshot aplikasi, serta pengujian sistem menggunakan metode Black Box Testing.'),
        ('BAB V PENUTUP',
         'Berisi kesimpulan yang menjawab ketiga rumusan masalah serta saran pengembangan sistem untuk penelitian atau iterasi berikutnya.'),
    ]
    for judul, isi in sistematika:
        p = doc.add_paragraph()
        setup_para(p, space_after=8, indent=1.27)
        r_j = p.add_run(judul + '\n')
        setup_run(r_j, bold=True)
        r_i = p.add_run(isi)
        setup_run(r_i)

    page_break(doc)

    # ═══════════════════════════════════════════
    # BAB II
    # ═══════════════════════════════════════════
    h_bab(doc, 'BAB II\nLANDASAN TEORI')

    sub2 = [
        ('2.1 Konsep Sistem Informasi',
         'Sistem informasi adalah kumpulan komponen yang saling berhubungan untuk mengumpulkan, memproses, menyimpan, dan mendistribusikan informasi guna mendukung pengambilan keputusan, koordinasi, dan pengendalian dalam sebuah organisasi (Laudon & Laudon, 2020). Komponen utama sistem informasi meliputi perangkat keras (hardware), perangkat lunak (software), data, manusia (brainware), dan prosedur. [LENGKAPI DENGAN TEORI DAN REFERENSI TAMBAHAN...]'),
        ('2.2 Aplikasi Mobile Android',
         'Aplikasi mobile adalah perangkat lunak yang dirancang untuk berjalan pada perangkat mobile seperti smartphone dan tablet. Android merupakan sistem operasi berbasis Linux yang dikembangkan oleh Google dan menjadi platform mobile dengan pangsa pasar terbesar di dunia. [LENGKAPI DENGAN TEORI DAN REFERENSI TAMBAHAN...]'),
        ('2.3 REST API',
         'REST (Representational State Transfer) adalah gaya arsitektur perangkat lunak yang mendefinisikan aturan untuk membuat layanan web. API (Application Programming Interface) berbasis REST atau RESTful API menggunakan protokol HTTP dengan metode GET, POST, PUT/PATCH, dan DELETE untuk operasi CRUD. [LENGKAPI DENGAN TEORI DAN REFERENSI TAMBAHAN...]'),
        ('2.4 Flutter',
         'Flutter adalah framework open-source yang dikembangkan oleh Google untuk membangun aplikasi mobile, web, dan desktop dari satu basis kode menggunakan bahasa pemrograman Dart. Flutter menggunakan konsep widget sebagai komponen dasar pembangunan antarmuka pengguna, dengan dua jenis widget utama: StatelessWidget dan StatefulWidget. [LENGKAPI DENGAN TEORI DAN REFERENSI TAMBAHAN...]'),
        ('2.5 Go dan Gin Framework',
         'Go (atau Golang) adalah bahasa pemrograman yang dikembangkan oleh Google, dirancang untuk memiliki performa tinggi, efisiensi memori, dan kemudahan pemrograman konkurensi melalui goroutine dan channel. Gin adalah web framework untuk Go yang ringan, berkinerja tinggi, dan mendukung routing berbasis middleware. [LENGKAPI DENGAN TEORI DAN REFERENSI TAMBAHAN...]'),
        ('2.6 PostgreSQL dan Supabase',
         'PostgreSQL adalah sistem manajemen basis data relasional (RDBMS) open-source yang dikenal karena keandalannya, dukungan tipe data kompleks seperti JSONB, dan ekstensi seperti UUID. Supabase adalah platform Backend-as-a-Service (BaaS) open-source berbasis PostgreSQL yang menyediakan database, autentikasi, storage, dan realtime secara terintegrasi. [LENGKAPI DENGAN TEORI DAN REFERENSI TAMBAHAN...]'),
        ('2.7 JWT (JSON Web Token)',
         'JSON Web Token (JWT) adalah standar terbuka (RFC 7519) yang mendefinisikan cara ringkas dan mandiri untuk mengirimkan informasi secara aman antar pihak sebagai objek JSON. JWT terdiri dari tiga bagian: Header (algoritma), Payload (klaim/data), dan Signature (tanda tangan digital). Dalam sistem HydroServ, JWT digunakan untuk autentikasi stateless dengan access token (24 jam) dan refresh token (720 jam). [LENGKAPI DENGAN TEORI DAN REFERENSI TAMBAHAN...]'),
        ('2.8 Firebase Cloud Messaging (FCM)',
         'Firebase Cloud Messaging (FCM) adalah layanan pengiriman pesan lintas platform yang dikembangkan oleh Google sebagai bagian dari Firebase. FCM memungkinkan pengiriman push notification secara andal ke perangkat Android, iOS, dan web. Sistem HydroServ menggunakan FCM v1 HTTP API untuk mengirimkan notifikasi real-time kepada pengguna ketika terjadi perubahan status booking. [LENGKAPI DENGAN TEORI DAN REFERENSI TAMBAHAN...]'),
        ('2.9 Metode Prototype',
         'Metode Prototype merupakan pendekatan pengembangan perangkat lunak di mana versi awal sistem (prototipe) dibangun terlebih dahulu, kemudian diuji dan disempurnakan berdasarkan umpan balik pengguna secara iteratif. Menurut Pressman (2014), tahapan Metode Prototype adalah: (1) Communication, (2) Quick Plan, (3) Quick Design, (4) Construction of Prototype, (5) Deployment, Delivery & Feedback. [LENGKAPI DENGAN REFERENSI DAN GAMBAR DIAGRAM TAHAPAN...]'),
        ('2.10 OOAD dan UML',
         'Object-Oriented Analysis and Design (OOAD) adalah pendekatan analisis dan perancangan sistem yang berfokus pada objek dan interaksi antar-objek. Unified Modeling Language (UML) adalah bahasa pemodelan standar yang digunakan dalam pendekatan OOAD, terdiri dari berbagai diagram seperti Use Case Diagram, Activity Diagram, Class Diagram, dan Sequence Diagram. [LENGKAPI DENGAN TEORI DAN REFERENSI TAMBAHAN...]'),
        ('2.11 Elisitasi',
         'Elisitasi adalah proses pengumpulan dan pemurnian kebutuhan sistem yang dilakukan melalui diskusi dengan pihak manajemen dan para pemangku kepentingan. Menurut Sommerville & Sawyer (1997), elisitasi dilakukan dalam tiga tahap: Elisitasi Tahap I (pengumpulan semua kebutuhan dari wawancara), Elisitasi Tahap II (penyaringan menggunakan metode MDI: Mandatory/Desirable/Inessential), dan Final Draft Elisitasi (validasi menggunakan metode TOE: Technical/Operational/Economic dengan skala risiko H/M/L). [LENGKAPI DENGAN REFERENSI TAMBAHAN...]'),
        ('2.12 Literature Review',
         '[ISI DENGAN RINGKASAN 5 PENELITIAN TERDAHULU YANG RELEVAN:\n\n1. [Penulis, Tahun, Judul — Penelitian Internal ITB BSG 1]\nMetodologi: ... Hasil: ... Perbandingan dengan penelitian ini: ...\n\n2. [Penulis, Tahun, Judul — Penelitian Internal ITB BSG 2]\nMetodologi: ... Hasil: ... Perbandingan dengan penelitian ini: ...\n\n3. [Penulis, Tahun, Judul — Jurnal Nasional 1]\nMetodologi: ... Hasil: ... Perbandingan dengan penelitian ini: ...\n\n4. [Penulis, Tahun, Judul — Jurnal Nasional 2]\nMetodologi: ... Hasil: ... Perbandingan dengan penelitian ini: ...\n\n5. [Penulis, Tahun, Judul — Jurnal Internasional]\nMetodologi: ... Hasil: ... Perbandingan dengan penelitian ini: ...]'),
    ]
    for judul, isi in sub2:
        h1(doc, judul)
        body(doc, isi)

    page_break(doc)

    # ═══════════════════════════════════════════
    # BAB III
    # ═══════════════════════════════════════════
    h_bab(doc, 'BAB III\nANALISIS SISTEM YANG BERJALAN')

    h1(doc, '3.1 Gambaran Umum Perusahaan')
    h2(doc, '3.1.1 Sejarah Singkat [NAMA PERUSAHAAN]')
    placeholder(doc, '[ISI: Sejarah berdirinya perusahaan, tahun berdiri, pendiri, perkembangan hingga saat ini, bidang usaha utama]')

    h2(doc, '3.1.2 Visi dan Misi')
    body(doc, 'Visi:', bold=True, indent=None)
    placeholder(doc, '[ISI VISI PERUSAHAAN]')
    body(doc, 'Misi:', bold=True, indent=None)
    placeholder(doc, '[ISI POIN-POIN MISI PERUSAHAAN]')

    h2(doc, '3.1.3 Struktur Organisasi')
    placeholder(doc, '[SISIPKAN GAMBAR BAGAN STRUKTUR ORGANISASI DI SINI]')
    caption(doc, 'Gambar 3.1 Struktur Organisasi [NAMA PERUSAHAAN]')

    h2(doc, '3.1.4 Tugas dan Tanggung Jawab')
    placeholder(doc, '[ISI: Deskripsi tugas dan tanggung jawab setiap jabatan dalam struktur organisasi]')

    h1(doc, '3.2 Tata Laksana Sistem yang Berjalan')
    h2(doc, '3.2.1 Prosedur Pemesanan Servis')
    body(doc, 'Prosedur pemesanan jasa servis yang saat ini berjalan di [NAMA PERUSAHAAN] adalah sebagai berikut:')
    numbered_list(doc, [
        'Klien menghubungi perusahaan melalui pesan WhatsApp atau telepon untuk menyampaikan kebutuhan servis.',
        'Staf sales atau manajer menerima permintaan dan mencatat informasi dasar (nama klien, jenis peralatan, keluhan) di buku catatan.',
        'Manajer mengevaluasi urgensi dan ketersediaan teknisi untuk menentukan jadwal penanganan.',
        'Informasi pekerjaan disampaikan kepada teknisi secara verbal atau melalui pesan WhatsApp.',
        'Teknisi menuju lokasi klien dan melaksanakan pekerjaan servis.',
    ])
    placeholder(doc, '[SISIPKAN ACTIVITY DIAGRAM SISTEM YANG BERJALAN — PROSES PEMESANAN MANUAL]')
    caption(doc, 'Gambar 3.2 Activity Diagram Sistem yang Berjalan')

    h2(doc, '3.2.2 Prosedur Penugasan Teknisi')
    placeholder(doc, '[ISI: Narasi bagaimana manajer menugaskan teknisi saat ini (verbal, WA, dll), termasuk kendala yang dihadapi]')

    h2(doc, '3.2.3 Prosedur Pelaporan Hasil Servis')
    placeholder(doc, '[ISI: Narasi bagaimana teknisi membuat laporan servis saat ini (kertas manual, apa saja yang dicatat, bagaimana pengarsipannya)]')

    h1(doc, '3.3 Analisis Sistem yang Berjalan')
    h2(doc, '3.3.1 Analisis Masalah')
    body(doc, 'Berdasarkan observasi dan wawancara yang telah dilakukan, dapat diidentifikasi bahwa sistem yang sedang berjalan memiliki permasalahan utama sebagai berikut:')
    numbered_list(doc, [
        'Data pemesanan servis tidak tercatat dengan baik karena masih mengandalkan pesan WhatsApp dan catatan manual yang mudah hilang atau terlewat.',
        'Tidak ada transparansi status pekerjaan kepada klien maupun manajer secara real-time, mengakibatkan komunikasi yang intensif dan tidak efisien.',
        'Penugasan teknisi dilakukan secara verbal tanpa dokumentasi resmi, sehingga akuntabilitas pekerjaan sulit dilacak.',
        'Laporan servis yang dibuat secara manual tidak terstandarisasi dan tidak tersimpan secara terpusat, menyulitkan penelusuran riwayat peralatan.',
        'Tidak ada sistem notifikasi otomatis yang membantu semua pihak mendapatkan informasi terkini mengenai perkembangan pekerjaan.',
    ])

    h2(doc, '3.3.2 Alternatif Pemecahan Masalah')
    body(doc, 'Berdasarkan analisis masalah di atas, alternatif pemecahan masalah yang diusulkan adalah membangun sebuah aplikasi mobile bernama HydroServ yang mengintegrasikan seluruh proses operasional jasa servis hidrolik dalam satu platform digital. Sistem ini akan menggantikan pencatatan manual dengan sistem informasi terkomputerisasi yang dapat diakses secara real-time oleh semua pemangku kepentingan sesuai peran dan kewenangan masing-masing.')

    h1(doc, '3.4 Elisitasi')
    h2(doc, '3.4.1 Elisitasi Tahap I')
    body(doc, 'Elisitasi Tahap I berisi seluruh kebutuhan sistem yang diperoleh dari hasil wawancara dengan stakeholder di [NAMA PERUSAHAAN].')

    # Tabel Elisitasi Tahap I - Functional
    center(doc, 'Tabel 3.1 Elisitasi Tahap I — Functional Requirement', bold=True, space_after=4)
    el1_func = [
        ('1', 'Sistem dapat melakukan registrasi akun baru berdasarkan peran pengguna'),
        ('2', 'Sistem dapat melakukan login dan mengarahkan pengguna ke halaman sesuai perannya'),
        ('3', 'Sistem dapat mengelola data peralatan hidrolik (equipment) milik klien'),
        ('4', 'Sistem dapat membuat pemesanan servis dengan detail lokasi, foto, dan jadwal'),
        ('5', 'Sistem menampilkan daftar booking terbuka di halaman job board teknisi'),
        ('6', 'Sistem memungkinkan teknisi mengklaim pekerjaan secara mandiri'),
        ('7', 'Sistem memungkinkan manajer menugaskan teknisi secara manual'),
        ('8', 'Sistem dapat memperbarui status pekerjaan secara real-time (on_the_way, on_site, done)'),
        ('9', 'Sistem dapat membuat laporan servis dengan data teknis terstandarisasi'),
        ('10', 'Sistem mendukung upload foto kondisi peralatan (before/after/damage)'),
        ('11', 'Sistem mendukung pencatatan inspection items untuk servis jenis inspeksi'),
        ('12', 'Sistem menghasilkan dokumen PDF laporan servis yang dapat dibagikan'),
        ('13', 'Sistem mengirimkan push notification otomatis untuk setiap perubahan status'),
        ('14', 'Sistem menampilkan dashboard statistik dan monitoring untuk manajer'),
        ('15', 'Sistem memungkinkan pembatalan booking sebelum dikerjakan'),
        ('16', 'Sistem mendukung navigasi ke lokasi servis via Google Maps'),
        ('17', 'Sistem menyimpan riwayat notifikasi dan menandai notifikasi telah dibaca'),
        ('18', 'Sistem dapat melakukan refresh token JWT secara otomatis'),
    ]
    simple_table(doc, ['No', 'Analisa Kebutuhan Fungsional'],
                 el1_func, font_size=10)

    doc.add_paragraph()
    center(doc, 'Tabel 3.2 Elisitasi Tahap I — Non-Functional Requirement', bold=True, space_after=4)
    el1_nonfunc = [
        ('1', 'Sistem berjalan pada platform Android versi 8.0 (Oreo) ke atas'),
        ('2', 'Sistem menggunakan autentikasi berbasis JWT untuk keamanan akses'),
        ('3', 'Respons API tidak melebihi 2 detik pada kondisi jaringan normal'),
        ('4', 'Data tersimpan di cloud (Supabase) dengan enkripsi dan role-based access control'),
        ('5', 'Aplikasi mendukung navigasi berbasis role secara otomatis saat login'),
        ('6', 'Antarmuka aplikasi menggunakan bahasa Indonesia dan mudah digunakan oleh teknisi lapangan'),
        ('7', 'Sistem menggunakan HTTPS untuk seluruh komunikasi API'),
        ('8', 'Backend dapat di-deploy dan di-scale secara otomatis di platform cloud (Railway)'),
    ]
    simple_table(doc, ['No', 'Analisa Kebutuhan Non-Fungsional'],
                 el1_nonfunc, font_size=10)

    h2(doc, '3.4.2 Elisitasi Tahap II')
    body(doc, 'Elisitasi Tahap II merupakan hasil penyaringan dari Elisitasi Tahap I menggunakan metode MDI (Mandatory, Desirable, Inessential). Kebutuhan yang dikategorikan Inessential (I) dieliminasi dari daftar kebutuhan.')
    placeholder(doc, '[SISIPKAN TABEL 3.3 ELISITASI TAHAP II DENGAN KOLOM MDI]')

    h2(doc, '3.4.3 Final Draft Elisitasi')
    body(doc, 'Final Draft Elisitasi merupakan hasil akhir dari proses elisitasi yang digunakan sebagai acuan pembangunan sistem. Kebutuhan divalidasi menggunakan metode TOE (Technical, Operational, Economic) dengan skala risiko H (High), M (Medium), dan L (Low).')
    placeholder(doc, '[SISIPKAN TABEL 3.4 FINAL DRAFT ELISITASI DENGAN KOLOM TOE + RISK]')

    page_break(doc)

    # ═══════════════════════════════════════════
    # BAB IV
    # ═══════════════════════════════════════════
    h_bab(doc, 'BAB IV\nRANCANGAN SISTEM YANG DIUSULKAN')

    h1(doc, '4.1 Rancangan Sistem Usulan')
    h2(doc, '4.1.1 Prosedur Sistem Usulan')
    body(doc, 'Berdasarkan hasil analisis sistem yang berjalan pada BAB III, dirancang sistem usulan berbasis aplikasi mobile yang mendigitalisasi seluruh proses operasional jasa servis hidrolik. Alur proses pada sistem yang diusulkan adalah sebagai berikut:')
    numbered_list(doc, [
        'Client membuat permintaan booking servis melalui aplikasi mobile dengan mengisi detail pekerjaan, memilih equipment, menentukan lokasi via peta, dan mengunggah foto kondisi awal.',
        'Sistem menyimpan booking dengan status OPEN dan mengirimkan push notification kepada manajer.',
        'Booking yang berstatus OPEN tampil di halaman Job Board teknisi. Teknisi dapat mengklaim pekerjaan secara mandiri, atau manajer dapat menugaskan teknisi secara langsung.',
        'Setelah diklaim/ditugaskan, status berubah menjadi IN_PROGRESS. Teknisi memperbarui status secara real-time: ON_THE_WAY saat berangkat, ON_SITE saat tiba di lokasi, dan DONE setelah pekerjaan selesai.',
        'Setiap perubahan status menghasilkan push notification otomatis kepada client dan manajer.',
        'Setelah status DONE, teknisi membuat laporan servis digital berisi data teknis, foto kondisi peralatan, dan daftar suku cadang yang diganti. Untuk servis tipe inspeksi, teknisi menambahkan inspection items per komponen.',
        'Sistem menghasilkan dokumen PDF laporan servis secara otomatis yang dapat diunduh dan dibagikan.',
        'Manajer memantau seluruh aktivitas operasional melalui dashboard monitoring yang menampilkan statistik, performa teknisi, dan tren booking.',
    ])

    h1(doc, '4.2 Diagram UML')
    h2(doc, '4.2.1 Use Case Diagram')
    body(doc, 'Use Case Diagram berikut menggambarkan fungsi-fungsi yang tersedia dalam sistem HydroServ beserta peran pengguna yang dapat mengaksesnya. Sistem memiliki empat aktor: Client, Sales, Teknisi, dan Manager, dengan total 17 use case.')
    placeholder(doc, '[SISIPKAN GAMBAR USE CASE DIAGRAM DI SINI\n(Export dari Mermaid / draw.io sebagai gambar PNG/JPG)]')
    caption(doc, 'Gambar 4.1 Use Case Diagram Sistem HydroServ')

    h2(doc, '4.2.2 Activity Diagram')
    body(doc, 'Activity Diagram berikut menggambarkan alur proses booking servis hidrolik secara menyeluruh, mulai dari pembuatan booking oleh client, proses klaim oleh teknisi, pelaksanaan pekerjaan di lapangan, hingga pembuatan laporan servis digital.')
    placeholder(doc, '[SISIPKAN GAMBAR ACTIVITY DIAGRAM DI SINI]')
    caption(doc, 'Gambar 4.2 Activity Diagram Alur Booking Servis Hidrolik')

    h2(doc, '4.2.3 Class Diagram')
    body(doc, 'Class Diagram berikut menggambarkan struktur kelas-kelas entitas dalam sistem HydroServ beserta atribut, metode, dan relasi antar-kelas. Sistem terdiri dari tujuh kelas utama: User, Company, HydraulicEquipment, Booking, HydraulicReport, InspectionItem, dan Notification.')
    placeholder(doc, '[SISIPKAN GAMBAR CLASS DIAGRAM DI SINI]')
    caption(doc, 'Gambar 4.3 Class Diagram Sistem HydroServ')

    h2(doc, '4.2.4 Sequence Diagram')
    body(doc, 'Berikut adalah Sequence Diagram untuk seluruh skenario utama dalam sistem HydroServ:')

    seq_list = [
        ('SD-01: Login', '4.4'),
        ('SD-02: Registrasi Akun Baru', '4.5'),
        ('SD-03: Buat Booking (Client)', '4.6'),
        ('SD-04: Claim Booking (Teknisi)', '4.7'),
        ('SD-05: Update Status Pekerjaan (Teknisi)', '4.8'),
        ('SD-06: Buat Laporan Servis (Teknisi)', '4.9'),
        ('SD-07: Assign Teknisi (Manager)', '4.10'),
        ('SD-08: Generate dan Unduh PDF Laporan', '4.11'),
        ('SD-09: Dashboard Monitoring (Manager)', '4.12'),
        ('SD-10: Push Notifikasi Otomatis', '4.13'),
    ]
    for nama, no in seq_list:
        placeholder(doc, f'[SISIPKAN GAMBAR SEQUENCE DIAGRAM — {nama}]')
        caption(doc, f'Gambar {no} Sequence Diagram — {nama}')

    h1(doc, '4.3 Rancangan Basis Data')
    h2(doc, '4.3.1 Entity Relationship Diagram (ERD)')
    placeholder(doc, '[SISIPKAN GAMBAR ERD DI SINI]')
    caption(doc, 'Gambar 4.14 Entity Relationship Diagram (ERD) Sistem HydroServ')

    h2(doc, '4.3.2 Spesifikasi Tabel')
    spek_tables = [
        ('Tabel 4.1 Spesifikasi Tabel users', [
            ('id', 'UUID', 'PK, DEFAULT gen_random_uuid()', 'Identitas unik pengguna'),
            ('name', 'VARCHAR(255)', 'NOT NULL', 'Nama lengkap pengguna'),
            ('email', 'VARCHAR(255)', 'NOT NULL, UNIQUE', 'Alamat email'),
            ('password_hash', 'TEXT', 'NOT NULL', 'Hash password (bcrypt)'),
            ('role', 'VARCHAR(20)', "CHECK IN ('client','sales','teknisi','manager')", 'Peran pengguna'),
            ('is_verified', 'BOOLEAN', 'DEFAULT FALSE', 'Status verifikasi email'),
            ('company_id', 'UUID', 'FK → companies(id)', 'ID perusahaan'),
            ('profile_photo_url', 'TEXT', 'NULLABLE', 'URL foto profil'),
            ('fcm_token', 'TEXT', 'NULLABLE', 'Token FCM untuk push notif'),
            ('created_at', 'TIMESTAMP', 'DEFAULT NOW()', 'Waktu pembuatan'),
        ]),
        ('Tabel 4.2 Spesifikasi Tabel companies', [
            ('id', 'UUID', 'PK', 'Identitas unik perusahaan'),
            ('name', 'VARCHAR(255)', 'NOT NULL', 'Nama perusahaan'),
            ('industry', 'VARCHAR(100)', 'NULLABLE', 'Bidang industri'),
            ('address', 'TEXT', 'NULLABLE', 'Alamat perusahaan'),
            ('city', 'VARCHAR(100)', 'NULLABLE', 'Kota'),
            ('phone', 'VARCHAR(20)', 'NULLABLE', 'Nomor telepon'),
            ('created_at', 'TIMESTAMP', 'DEFAULT NOW()', 'Waktu pembuatan'),
        ]),
        ('Tabel 4.3 Spesifikasi Tabel hydraulic_equipment', [
            ('id', 'UUID', 'PK', 'Identitas unik peralatan'),
            ('company_id', 'UUID', 'NOT NULL, FK → companies(id)', 'ID perusahaan pemilik'),
            ('name', 'VARCHAR(255)', 'NOT NULL', 'Nama peralatan'),
            ('type', 'VARCHAR(50)', "CHECK IN ('pump','cylinder','hose','valve','accumulator','power_pack','other')", 'Tipe peralatan'),
            ('brand', 'VARCHAR(100)', 'NULLABLE', 'Merk peralatan'),
            ('model', 'VARCHAR(100)', 'NULLABLE', 'Model peralatan'),
            ('serial_number', 'VARCHAR(100)', 'UNIQUE, NULLABLE', 'Nomor seri'),
            ('rated_pressure_bar', 'INTEGER', 'NULLABLE', 'Tekanan kerja (bar)'),
            ('location_detail', 'TEXT', 'NULLABLE', 'Lokasi peralatan di pabrik'),
            ('is_active', 'BOOLEAN', 'DEFAULT TRUE', 'Status aktif peralatan'),
        ]),
        ('Tabel 4.4 Spesifikasi Tabel bookings', [
            ('id', 'UUID', 'PK', 'Identitas unik booking'),
            ('company_id', 'UUID', 'NOT NULL, FK → companies(id)', 'ID perusahaan klien'),
            ('created_by', 'UUID', 'NOT NULL, FK → users(id)', 'ID pembuat booking'),
            ('technician_id', 'UUID', 'NULLABLE, FK → users(id)', 'ID teknisi ditugaskan'),
            ('equipment_id', 'UUID', 'NULLABLE, FK → hydraulic_equipment(id)', 'ID peralatan'),
            ('service_type', 'VARCHAR(20)', "CHECK IN ('repair','inspeksi','maintenance')", 'Jenis layanan'),
            ('urgency_level', 'VARCHAR(20)', "DEFAULT 'standard'", 'Tingkat urgensi'),
            ('status', 'VARCHAR(20)', "DEFAULT 'open'", 'Status booking'),
            ('description', 'TEXT', 'NULLABLE', 'Deskripsi pekerjaan'),
            ('site_address', 'TEXT', 'NULLABLE', 'Alamat lokasi servis'),
            ('site_city', 'VARCHAR(100)', 'NULLABLE', 'Kota lokasi'),
            ('latitude', 'FLOAT', 'NULLABLE', 'Koordinat lintang'),
            ('longitude', 'FLOAT', 'NULLABLE', 'Koordinat bujur'),
            ('photo_urls', 'JSONB', "DEFAULT '[]'", 'URL foto kondisi awal'),
            ('scheduled_at', 'TIMESTAMP', 'NULLABLE', 'Jadwal pelaksanaan'),
            ('claimed_at', 'TIMESTAMP', 'NULLABLE', 'Waktu diklaim'),
            ('completed_at', 'TIMESTAMP', 'NULLABLE', 'Waktu selesai'),
            ('created_at', 'TIMESTAMP', 'DEFAULT NOW()', 'Waktu pembuatan'),
        ]),
        ('Tabel 4.5 Spesifikasi Tabel hydraulic_reports', [
            ('id', 'UUID', 'PK', 'Identitas unik laporan'),
            ('booking_id', 'UUID', 'NOT NULL, FK → bookings(id)', 'ID booking terkait'),
            ('technician_id', 'UUID', 'NOT NULL, FK → users(id)', 'ID teknisi pembuat'),
            ('system_pressure_bar', 'INTEGER', 'NULLABLE', 'Tekanan sistem (bar)'),
            ('actual_pressure_bar', 'INTEGER', 'NULLABLE', 'Tekanan aktual (bar)'),
            ('oil_condition', 'VARCHAR(50)', 'NULLABLE', 'Kondisi oli'),
            ('oil_brand', 'VARCHAR(100)', 'NULLABLE', 'Merk oli'),
            ('oil_volume_liter', 'FLOAT', 'NULLABLE', 'Volume oli (liter)'),
            ('leak_found', 'BOOLEAN', 'DEFAULT FALSE', 'Status kebocoran ditemukan'),
            ('leak_location', 'TEXT', 'NULLABLE', 'Lokasi kebocoran'),
            ('repair_notes', 'TEXT', 'NULLABLE', 'Catatan perbaikan'),
            ('recommendation', 'TEXT', 'NULLABLE', 'Rekomendasi tindak lanjut'),
            ('created_at', 'TIMESTAMP', 'DEFAULT NOW()', 'Waktu pembuatan'),
        ]),
        ('Tabel 4.6 Spesifikasi Tabel inspection_items', [
            ('id', 'UUID', 'PK', 'Identitas unik item inspeksi'),
            ('report_id', 'UUID', 'NOT NULL, FK → hydraulic_reports(id)', 'ID laporan terkait'),
            ('component_type', 'VARCHAR(50)', "CHECK IN ('hose','cylinder','pump')", 'Tipe komponen'),
            ('component_name', 'VARCHAR(255)', 'NULLABLE', 'Nama komponen'),
            ('condition', 'VARCHAR(50)', 'NULLABLE', 'Kondisi komponen'),
            ('recommendation', 'TEXT', 'NULLABLE', 'Rekomendasi perbaikan'),
            ('specifications', 'JSONB', "DEFAULT '{}'", 'Spesifikasi teknis fitting'),
        ]),
        ('Tabel 4.7 Spesifikasi Tabel notifications', [
            ('id', 'UUID', 'PK', 'Identitas unik notifikasi'),
            ('user_id', 'UUID', 'NOT NULL, FK → users(id)', 'ID penerima notifikasi'),
            ('booking_id', 'UUID', 'NULLABLE, FK → bookings(id)', 'ID booking terkait'),
            ('title', 'VARCHAR(255)', 'NOT NULL', 'Judul notifikasi'),
            ('message', 'TEXT', 'NOT NULL', 'Isi pesan notifikasi'),
            ('type', 'VARCHAR(50)', 'NULLABLE', 'Tipe notifikasi'),
            ('is_read', 'BOOLEAN', 'DEFAULT FALSE', 'Status sudah dibaca'),
            ('created_at', 'TIMESTAMP', 'DEFAULT NOW()', 'Waktu pembuatan'),
        ]),
    ]

    for tbl_caption, rows in spek_tables:
        center(doc, tbl_caption, bold=True, space_before=12, space_after=4)
        simple_table(doc, ['Field', 'Tipe Data', 'Constraint', 'Keterangan'], rows, font_size=9)
        doc.add_paragraph()

    h1(doc, '4.4 Rancangan Antarmuka')
    body(doc, 'Berikut adalah tampilan antarmuka aplikasi HydroServ yang telah diimplementasikan. Rancangan antarmuka menggunakan Material Design 3 dengan tema warna biru sebagai warna utama yang mencerminkan identitas profesional perusahaan hidrolik.')
    placeholder(doc, '[SISIPKAN SCREENSHOT TIAP HALAMAN APLIKASI DISERTAI KETERANGAN SINGKAT\n— Halaman Login\n— Halaman Registrasi\n— Halaman Buat Booking\n— Halaman Job Board Teknisi\n— Halaman My Jobs\n— Form Laporan Servis\n— Detail Laporan Servis\n— Dashboard Manager\n— Halaman Notifikasi\n— (lainnya sesuai kebutuhan)]')

    h1(doc, '4.5 Implementasi Sistem')
    h2(doc, '4.5.1 Spesifikasi Hardware dan Software')
    body(doc, 'Hardware yang digunakan dalam pengembangan dan pengujian sistem:')
    bullet_list(doc, [
        'Laptop pengembangan: Prosesor Intel Core i5/i7 atau setara, RAM minimal 8GB, Storage SSD 256GB',
        'Smartphone Android untuk pengujian: Minimal Android versi 8.0 (Oreo / API Level 26)',
    ])
    body(doc, 'Software yang digunakan:')
    bullet_list(doc, [
        'Flutter SDK versi 3.x dan Dart versi 3.x — framework pengembangan mobile',
        'Go versi 1.21+ dan Gin Framework v1.9+ — bahasa dan framework backend',
        'PostgreSQL 15 via Supabase — database cloud',
        'Visual Studio Code — IDE utama pengembangan',
        'Android Studio — emulator Android dan Android SDK',
        'Postman — pengujian dan dokumentasi REST API',
        'Git + GitHub — version control dan kolaborasi',
        'Railway — platform deployment backend (auto-deploy dari branch develop)',
        'Firebase Console — konfigurasi Firebase Cloud Messaging',
        'Resend — layanan pengiriman email transaksional',
    ])

    h2(doc, '4.5.2 Tampilan Aplikasi')
    placeholder(doc, '[SISIPKAN SCREENSHOT APLIKASI PER FITUR DENGAN PENJELASAN FUNGSI MASING-MASING — MINIMAL 10 SCREENSHOT]')

    h1(doc, '4.6 Pengujian Sistem')
    body(doc, 'Pengujian sistem dilakukan menggunakan metode Black Box Testing, yaitu pengujian yang berfokus pada fungsionalitas sistem dari perspektif pengguna tanpa memperhatikan kode program di dalamnya. Setiap skenario diuji dengan memberikan input tertentu dan memverifikasi apakah output yang dihasilkan sesuai dengan yang diharapkan.')

    center(doc, 'Tabel 4.8 Pengujian Black Box Testing — Autentikasi', bold=True, space_after=4)
    bb_auth = [
        ('1', 'Login email & password valid', 'Email benar, password benar', '200 OK, token diterima, redirect home sesuai role', 'Sesuai ✓'),
        ('2', 'Login password salah', 'Email benar, password salah', '401 Unauthorized, pesan error tampil', 'Sesuai ✓'),
        ('3', 'Login akun belum terverifikasi', 'Akun belum klik link verifikasi', '403 Forbidden, pesan "cek email" tampil', 'Sesuai ✓'),
        ('4', 'Registrasi dengan data lengkap', 'Semua field diisi valid', '201 Created, email verifikasi terkirim', 'Sesuai ✓'),
        ('5', 'Registrasi email sudah terdaftar', 'Email yang sudah dipakai user lain', '409 Conflict, pesan error tampil', 'Sesuai ✓'),
    ]
    simple_table(doc, ['No', 'Skenario Uji', 'Input', 'Output Diharapkan', 'Hasil'], bb_auth, font_size=9)

    doc.add_paragraph()
    center(doc, 'Tabel 4.9 Pengujian Black Box Testing — Booking', bold=True, space_after=4)
    bb_booking = [
        ('1', 'Buat booking dengan data lengkap', 'Semua field diisi, foto diupload', 'Booking tersimpan status OPEN, notif ke manager', 'Sesuai ✓'),
        ('2', 'Buat booking tanpa deskripsi', 'Field deskripsi kosong', '400 Bad Request, field wajib diisi', 'Sesuai ✓'),
        ('3', 'Lihat daftar booking milik sendiri', 'Login sebagai client', 'Tampil hanya booking milik perusahaan client', 'Sesuai ✓'),
        ('4', 'Batalkan booking status open', 'Booking masih OPEN', 'Status berubah CANCELLED', 'Sesuai ✓'),
        ('5', 'Batalkan booking yang sudah in_progress', 'Booking sudah diklaim teknisi', '403 Forbidden, tidak bisa dibatalkan', 'Sesuai ✓'),
    ]
    simple_table(doc, ['No', 'Skenario Uji', 'Input', 'Output Diharapkan', 'Hasil'], bb_booking, font_size=9)

    doc.add_paragraph()
    center(doc, 'Tabel 4.10 Pengujian Black Box Testing — Job Board dan Status Pekerjaan', bold=True, space_after=4)
    bb_job = [
        ('1', 'Teknisi lihat job board', 'Login sebagai teknisi', 'Tampil semua booking status OPEN', 'Sesuai ✓'),
        ('2', 'Teknisi claim booking tersedia', 'Booking status OPEN, klik Claim', 'Status → IN_PROGRESS, notif ke manager & client', 'Sesuai ✓'),
        ('3', 'Klaim booking yang sudah diklaim', 'Booking sudah diklaim teknisi lain', '409 Conflict, pesan error tampil', 'Sesuai ✓'),
        ('4', 'Update status ke ON_THE_WAY', 'Status IN_PROGRESS, tap tombol', 'Status → ON_THE_WAY, notif terkirim', 'Sesuai ✓'),
        ('5', 'Update status oleh teknisi lain', 'Teknisi bukan yang assigned', '403 Forbidden, tidak bisa update', 'Sesuai ✓'),
        ('6', 'Manager assign teknisi ke booking', 'Pilih booking + pilih teknisi', 'Status → IN_PROGRESS, notif ke teknisi', 'Sesuai ✓'),
    ]
    simple_table(doc, ['No', 'Skenario Uji', 'Input', 'Output Diharapkan', 'Hasil'], bb_job, font_size=9)

    doc.add_paragraph()
    center(doc, 'Tabel 4.11 Pengujian Black Box Testing — Laporan Servis', bold=True, space_after=4)
    bb_report = [
        ('1', 'Buat laporan servis dengan data lengkap', 'Semua data teknis diisi, foto diupload', 'Laporan tersimpan, PDF dapat diunduh', 'Sesuai ✓'),
        ('2', 'Tambah inspection item (servis inspeksi)', 'Isi form komponen hose dengan fitting specs', 'Item tersimpan dan muncul di detail laporan', 'Sesuai ✓'),
        ('3', 'Unduh PDF laporan', 'Tap tombol unduh di detail laporan', 'PDF digenerate dan share sheet terbuka', 'Sesuai ✓'),
        ('4', 'Lihat laporan oleh manager', 'Login sebagai manager, buka laporan', 'Detail laporan lengkap tampil dengan foto', 'Sesuai ✓'),
    ]
    simple_table(doc, ['No', 'Skenario Uji', 'Input', 'Output Diharapkan', 'Hasil'], bb_report, font_size=9)

    doc.add_paragraph()
    center(doc, 'Tabel 4.12 Pengujian Black Box Testing — Dashboard dan Notifikasi', bold=True, space_after=4)
    bb_dash = [
        ('1', 'Manager lihat dashboard', 'Login sebagai manager, buka tab Dashboard', 'Statistik, performa teknisi, dan tren tampil', 'Sesuai ✓'),
        ('2', 'Terima push notification saat booking baru', 'Client buat booking baru', 'Manager terima push notif di device', 'Sesuai ✓'),
        ('3', 'Terima notif saat status berubah', 'Teknisi update status ke DONE', 'Client dan manager terima push notif', 'Sesuai ✓'),
        ('4', 'Tandai notifikasi sudah dibaca', 'Tap notifikasi di halaman notifikasi', 'is_read berubah TRUE, badge berkurang', 'Sesuai ✓'),
    ]
    simple_table(doc, ['No', 'Skenario Uji', 'Input', 'Output Diharapkan', 'Hasil'], bb_dash, font_size=9)

    page_break(doc)

    # ═══════════════════════════════════════════
    # BAB V
    # ═══════════════════════════════════════════
    h_bab(doc, 'BAB V\nPENUTUP')

    h1(doc, '5.1 Kesimpulan')
    body(doc, 'Berdasarkan hasil penelitian, perancangan, pembangunan, dan pengujian yang telah dilakukan, dapat ditarik kesimpulan sebagai berikut:')
    numbered_list(doc, [
        'Aplikasi mobile HydroServ berbasis Android berhasil dirancang dan dibangun menggunakan Flutter sebagai framework mobile dan Go/Gin sebagai REST API backend, dengan dukungan empat peran pengguna (client, sales, teknisi, dan manager) yang masing-masing memiliki alur kerja dan hak akses berbeda. Sistem ini berhasil mendigitalisasi seluruh proses pemesanan jasa servis hidrolik dari status OPEN hingga DONE, menggantikan proses manual berbasis WhatsApp dan catatan fisik yang sebelumnya digunakan di [NAMA PERUSAHAAN].',
        'Fitur pelaporan servis digital berhasil diimplementasikan dengan menyediakan formulir laporan teknis terstandarisasi yang mencakup data tekanan sistem dan aktual, kondisi oli, informasi kebocoran, catatan perbaikan, suku cadang yang diganti, serta dokumentasi foto before/after/damage yang diunggah ke Supabase Storage. Untuk jenis layanan inspeksi, sistem mendukung pencatatan inspection items per komponen (hose, cylinder, pump) dengan spesifikasi fitting terdetail. Laporan dapat diunduh dan dibagikan dalam format PDF yang digenerate otomatis oleh sistem.',
        'Dashboard monitoring berbasis data real-time berhasil disediakan bagi manajer, menampilkan statistik ringkasan booking per status, data performa teknisi, dan grafik tren booking secara periodik. Ditambah dengan sistem push notification otomatis via Firebase Cloud Messaging untuk setiap perubahan status pekerjaan, manajer mendapatkan visibilitas penuh terhadap seluruh operasional servis tanpa perlu aktif menghubungi teknisi satu per satu.',
    ])

    h1(doc, '5.2 Saran')
    body(doc, 'Berdasarkan hasil penelitian dan keterbatasan sistem yang telah dibangun, penulis memberikan saran untuk pengembangan lebih lanjut sebagai berikut:')
    numbered_list(doc, [
        'Implementasi fitur multi-user per perusahaan klien, sehingga beberapa akun pengguna dapat tergabung dalam satu perusahaan yang sama dengan hak akses yang dapat dikustomisasi.',
        'Pengembangan modul pembayaran dan invoicing digital yang terintegrasi dengan sistem booking, sehingga proses penagihan kepada klien dapat dilakukan sepenuhnya dalam satu platform.',
        'Penambahan fitur manajemen stok suku cadang yang terintegrasi dengan laporan servis, sehingga ketersediaan komponen dapat dipantau dan dikelola secara real-time.',
        'Pengembangan versi aplikasi untuk platform iOS guna memperluas jangkauan pengguna yang menggunakan perangkat Apple.',
        'Implementasi fitur laporan analitik yang lebih mendalam, seperti ekspor data ke format Excel dan visualisasi tren biaya servis per peralatan untuk mendukung pengambilan keputusan manajemen.',
    ])

    page_break(doc)

    # ═══════════════════════════════════════════
    # DAFTAR PUSTAKA
    # ═══════════════════════════════════════════
    h_bab(doc, 'DAFTAR PUSTAKA')

    pustaka = [
        'Laudon, K. C., & Laudon, J. P. (2020). Management Information Systems: Managing the Digital Firm (16th ed.). Pearson Education.',
        'Pressman, R. S. (2014). Software Engineering: A Practitioner\'s Approach (8th ed.). McGraw-Hill Education.',
        '[PENULIS]. ([TAHUN]). [JUDUL PENELITIAN INTERNAL ITB BSG 1]. [NAMA JURNAL/PROSIDING ITB BSG], [Volume]([Nomor]), [halaman].',
        '[PENULIS]. ([TAHUN]). [JUDUL PENELITIAN INTERNAL ITB BSG 2]. [NAMA JURNAL/PROSIDING ITB BSG], [Volume]([Nomor]), [halaman].',
        '[PENULIS]. ([TAHUN]). [JUDUL PENELITIAN NASIONAL 1]. [NAMA JURNAL TERAKREDITASI SINTA], [Volume]([Nomor]), [halaman]. https://doi.org/...',
        '[PENULIS]. ([TAHUN]). [JUDUL PENELITIAN NASIONAL 2]. [NAMA JURNAL TERAKREDITASI SINTA], [Volume]([Nomor]), [halaman]. https://doi.org/...',
        '[PENULIS]. ([TAHUN]). [JUDUL PENELITIAN INTERNASIONAL]. [NAMA JURNAL INTERNASIONAL (IEEE/Springer/Elsevier)], [Volume]([Nomor]), [halaman]. https://doi.org/...',
    ]
    for item in pustaka:
        p = doc.add_paragraph()
        r = p.add_run(item)
        setup_run(r)
        setup_para(p, space_after=6, indent=None)
        pf = p.paragraph_format
        pf.left_indent = Cm(1.27)
        pf.first_line_indent = Cm(-1.27)

    page_break(doc)

    # ═══════════════════════════════════════════
    # LAMPIRAN
    # ═══════════════════════════════════════════
    h_bab(doc, 'LAMPIRAN')

    h1(doc, 'Lampiran A — Hasil Wawancara')
    placeholder(doc, '[SISIPKAN TRANSKRIP ATAU RINGKASAN HASIL WAWANCARA DENGAN:\n— Teknisi (nama, jabatan, tanggal)\n— Sales/Manager (nama, jabatan, tanggal)\nBeserta daftar pertanyaan dan jawaban]')

    h1(doc, 'Lampiran B — Potongan Source Code Backend (Go/Gin)')
    placeholder(doc, '[SISIPKAN POTONGAN SOURCE CODE PENTING:\n— cmd/api/main.go (entry point)\n— internal/delivery/http/router/router.go\n— internal/delivery/http/handler/booking_handler.go\n— internal/infrastructure/pdf/generator.go]')

    h1(doc, 'Lampiran C — Potongan Source Code Mobile (Flutter)')
    placeholder(doc, '[SISIPKAN POTONGAN SOURCE CODE PENTING:\n— lib/core/network/api_client.dart\n— lib/features/booking/presentation/pages/create_booking_page.dart\n— lib/features/report/presentation/pages/report_detail_page.dart]')

    h1(doc, 'Lampiran D — Database Migration Scripts')
    placeholder(doc, '[SISIPKAN MIGRATION SQL SCRIPTS:\n— 001_create_extensions.sql\n— 002_create_users_companies.sql\n— 003_create_hydraulic_equipment.sql\n— 004_create_bookings.sql\n— (dst)]')

    # ═══════════════════════════════════════════
    # SAVE
    # ═══════════════════════════════════════════
    output = r'c:\androidlanjutan\project_3\Laporan_Project3_HydroServ.docx'
    doc.save(output)
    print(f'OK Dokumen berhasil dibuat: {output}')
    return output


if __name__ == '__main__':
    build()
