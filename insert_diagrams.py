#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ganti semua placeholder [SISIPKAN GAMBAR ...] di Word dengan gambar PNG asli.
"""

import os
import re
from docx import Document
from docx.shared import Cm, Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

PNG_DIR = r'c:\androidlanjutan\project_3\diagrams_png'
INPUT  = r'c:\androidlanjutan\project_3\Laporan_Project3_HydroServ.docx'
OUTPUT = r'c:\androidlanjutan\project_3\Laporan_Project3_HydroServ.docx'

# Map keyword dalam placeholder ke file PNG dan lebar gambar (cm)
DIAGRAM_MAP = [
    ('USE CASE DIAGRAM',              '01_usecase.png',           14),
    ('ACTIVITY DIAGRAM',              '02_activity.png',          10),
    ('CLASS DIAGRAM',                 '03_class.png',             14),
    ('SD-01',                         '04_seq_login.png',         13),
    ('SD-02',                         '05_seq_registrasi.png',    13),
    ('SD-03',                         '06_seq_buat_booking.png',  13),
    ('SD-04',                         '07_seq_claim.png',         13),
    ('SD-05',                         '08_seq_update_status.png', 13),
    ('SD-06',                         '09_seq_laporan.png',       13),
    ('SD-07',                         '10_seq_assign.png',        13),
    ('SD-08',                         '11_seq_pdf.png',           13),
    ('SD-09',                         '12_seq_dashboard.png',     13),
    ('SD-10',                         '13_seq_notif.png',         13),
    ('ERD',                           '14_erd.png',               14),
]

def find_png(keyword):
    for key, fname, width in DIAGRAM_MAP:
        if key.lower() in keyword.lower():
            if fname is None:
                return None, None
            path = os.path.join(PNG_DIR, fname)
            if os.path.exists(path):
                return path, width
    return None, None

def add_image_paragraph(doc, img_path, width_cm):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pf = p.paragraph_format
    pf.space_before = Pt(4)
    pf.space_after  = Pt(4)
    run = p.add_run()
    run.add_picture(img_path, width=Cm(width_cm))
    return p

def process():
    doc = Document(INPUT)
    new_doc = Document()

    # Copy page setup from original
    orig_sec = doc.sections[0]
    for sec in new_doc.sections:
        sec.page_height   = orig_sec.page_height
        sec.page_width    = orig_sec.page_width
        sec.left_margin   = orig_sec.left_margin
        sec.right_margin  = orig_sec.right_margin
        sec.top_margin    = orig_sec.top_margin
        sec.bottom_margin = orig_sec.bottom_margin

    # Copy default style font
    new_doc.styles['Normal'].font.name = 'Times New Roman'
    new_doc.styles['Normal'].font.size = Pt(12)

    replaced = 0
    skipped  = []

    for para in doc.paragraphs:
        txt = para.text.strip()

        # Cek apakah ini baris placeholder
        if txt.startswith('[SISIPKAN GAMBAR') and 'DI SINI' in txt:
            img_path, width = find_png(txt)
            if img_path:
                add_image_paragraph(new_doc, img_path, width)
                replaced += 1
                print(f'  [OK] {os.path.basename(img_path)} -> "{txt[:60]}"')
            else:
                # Placeholder yang belum ada gambarnya, tetap sebagai teks
                new_p = new_doc.add_paragraph()
                new_r = new_p.add_run(txt)
                new_r.font.name = 'Times New Roman'
                new_r.font.size = Pt(11)
                new_r.font.italic = True
                from docx.shared import RGBColor
                new_r.font.color.rgb = RGBColor(0x80, 0x80, 0x80)
                new_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                skipped.append(txt[:70])
        else:
            # Copy paragraph as-is dengan semua formatting
            new_p = new_doc.add_paragraph()
            new_p.alignment = para.alignment
            pf_src = para.paragraph_format
            pf_dst = new_p.paragraph_format
            pf_dst.space_before         = pf_src.space_before
            pf_dst.space_after          = pf_src.space_after
            pf_dst.line_spacing         = pf_src.line_spacing
            pf_dst.line_spacing_rule    = pf_src.line_spacing_rule
            pf_dst.left_indent          = pf_src.left_indent
            pf_dst.first_line_indent    = pf_src.first_line_indent

            for run in para.runs:
                new_r = new_p.add_run(run.text)
                new_r.font.name      = run.font.name or 'Times New Roman'
                new_r.font.size      = run.font.size or Pt(12)
                new_r.font.bold      = run.font.bold
                new_r.font.italic    = run.font.italic
                new_r.font.underline = run.font.underline
                if run.font.color and run.font.color.type:
                    try:
                        new_r.font.color.rgb = run.font.color.rgb
                    except Exception:
                        pass

            # Copy tabel jika ada di dalam paragraf (tidak umum, tapi jaga-jaga)

        # Copy page breaks
        for child in para._p:
            if child.tag.endswith('}r'):
                for sub in child:
                    if sub.tag.endswith('}lastRenderedPageBreak') or sub.tag.endswith('}br'):
                        pass  # biarkan natural flow

    # Copy semua tabel dari dokumen asli
    # Tabel disimpan terpisah dari paragraf, perlu rebuild
    # Pendekatan: simpan ke file dulu lalu insert tabel dari orig
    new_doc.save(OUTPUT)

    # Pendekatan lebih sederhana: pakai docx manipulation langsung pada orig doc
    # Ganti semua placeholder paragraph IN PLACE
    print(f'\nDiagram disisipkan: {replaced}')
    if skipped:
        print(f'Placeholder tanpa gambar ({len(skipped)}):')
        for s in skipped:
            print(f'  - {s}')

    return replaced

# ── Pendekatan lebih andal: modifikasi in-place ──────────────────────────────

def process_inplace():
    """Modifikasi dokumen asli secara in-place: ganti paragraf placeholder."""
    doc = Document(INPUT)
    replaced = 0

    paragraphs = list(doc.paragraphs)
    for para in paragraphs:
        txt = para.text.strip()
        if not txt.startswith('[SISIPKAN GAMBAR'):
            continue

        img_path, width = find_png(txt)
        if not img_path:
            print(f'  [SKIP] Tidak ada PNG untuk: {txt[:70]}')
            continue

        # Hapus semua run dari paragraf ini
        for run in para.runs:
            run.text = ''

        # Hapus text lama di XML
        p_elem = para._p
        for r in p_elem.findall(qn('w:r')):
            p_elem.remove(r)

        # Set alignment center
        para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        pf = para.paragraph_format
        pf.space_before = Pt(6)
        pf.space_after  = Pt(6)

        # Sisipkan gambar
        run = para.add_run()
        run.add_picture(img_path, width=Cm(width))

        replaced += 1
        print(f'  [OK] {os.path.basename(img_path)}')

    doc.save(OUTPUT)
    print(f'\nTotal diagram disisipkan: {replaced}')
    print(f'File tersimpan: {OUTPUT}')


if __name__ == '__main__':
    print('Menyisipkan diagram ke Word...\n')
    process_inplace()
