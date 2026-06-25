import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/cache/page_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class EditReportPage extends StatefulWidget {
  final Map<String, dynamic> report;
  final Map<String, dynamic> booking;
  const EditReportPage({super.key, required this.report, required this.booking});

  @override
  State<EditReportPage> createState() => _EditReportPageState();
}

class _EditReportPageState extends State<EditReportPage> {
  final _formKey       = GlobalKey<FormState>();
  final _descCtrl      = TextEditingController();
  final _recsCtrl      = TextEditingController();
  final _pressBeforeCtrl = TextEditingController();
  final _pressAfterCtrl  = TextEditingController();
  final _leakLocCtrl     = TextEditingController();

  String? _oilCondition;
  String? _oilLevel;
  String? _leakSeverity;

  bool _loading = false;
  final List<_PhotoEntry> _photos = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    _descCtrl.text = r['work_description'] ?? '';
    _recsCtrl.text = r['recommendations']  ?? '';
    _oilCondition  = r['oil_condition'];
    _oilLevel      = r['oil_level'];
    _leakSeverity  = r['leak_severity'];
    if ((r['leak_location'] ?? '').toString().isNotEmpty) {
      _leakLocCtrl.text = r['leak_location'] ?? '';
    }
    if ((r['pressure_before_bar'] ?? '').toString().isNotEmpty) {
      _pressBeforeCtrl.text = r['pressure_before_bar'].toString();
    }
    if ((r['pressure_after_bar'] ?? '').toString().isNotEmpty) {
      _pressAfterCtrl.text = r['pressure_after_bar'].toString();
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose(); _recsCtrl.dispose();
    _pressBeforeCtrl.dispose(); _pressAfterCtrl.dispose(); _leakLocCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.any((p) => p.url == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tunggu hingga semua foto selesai diupload'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    setState(() => _loading = true);

    // Build photo list: existing + new
    final existingPhotos = List<Map<String, dynamic>>.from(
        (widget.report['photo_urls'] as List? ?? []).map((p) => Map<String, dynamic>.from(p)));
    final newPhotos = _photos.asMap().entries.map((e) {
      final types = ['before', 'after', 'damage'];
      return {'url': e.value.url!, 'type': e.key < types.length ? types[e.key] : 'damage'};
    }).toList();
    final allPhotos = [...existingPhotos, ...newPhotos];

    final data = <String, dynamic>{
      'work_description': _descCtrl.text.trim(),
      'recommendations':  _recsCtrl.text.trim(),
      'photo_urls':       allPhotos,
      'parts_replaced':   widget.report['parts_replaced'] ?? [],
      'maintenance_checklist': widget.report['maintenance_checklist'] ?? [],
      'inspection_items': [],
    };

    if (_pressBeforeCtrl.text.isNotEmpty) data['pressure_before_bar'] = int.tryParse(_pressBeforeCtrl.text);
    if (_pressAfterCtrl.text.isNotEmpty)  data['pressure_after_bar']  = int.tryParse(_pressAfterCtrl.text);
    if (_oilCondition != null) data['oil_condition'] = _oilCondition;
    if (_oilLevel != null)     data['oil_level']     = _oilLevel;
    if (_leakLocCtrl.text.isNotEmpty) data['leak_location'] = _leakLocCtrl.text.trim();
    if (_leakSeverity != null) data['leak_severity'] = _leakSeverity;

    try {
      await ApiClient.instance.patch(
        '/reports/by-id/${widget.report['id']}',
        data: data,
      );
      if (!mounted) return;
      PageCache.remove('my_jobs');
      PageCache.remove('laporan');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Laporan berhasil diperbaiki! Menunggu konfirmasi ulang dari client.'),
        backgroundColor: AppTheme.secondary,
      ));
      context.go('/job-board');
    } catch (e) {
      String msg = 'Gagal memperbaiki laporan';
      if (e is DioException) msg = e.response?.data['message'] ?? msg;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920);
    if (xfile == null || !mounted) return;
    final entry = _PhotoEntry(file: File(xfile.path));
    setState(() => _photos.add(entry));
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(xfile.path, filename: xfile.name),
      });
      final res = await ApiClient.instance.post('/upload', data: formData);
      final url = res.data['data']['url'] as String;
      if (mounted) setState(() => entry.url = url);
    } catch (_) {
      if (mounted) {
        setState(() => _photos.remove(entry));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal upload foto'), backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejectionReason = (widget.report['rejection_reason'] as String?) ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perbaiki Laporan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Rejection reason banner
            if (rejectionReason.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppTheme.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Alasan penolakan:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: AppTheme.danger)),
                          const SizedBox(height: 2),
                          Text(rejectionReason,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Deskripsi
            _card(
              icon: Icons.description_outlined,
              title: 'Deskripsi Pekerjaan',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lbl('Deskripsi pekerjaan *'),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'Jelaskan pekerjaan yang telah dilakukan...'),
                    validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),
                  _lbl('Catatan / Rekomendasi *'),
                  TextFormField(
                    controller: _recsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Catatan atau rekomendasi tindak lanjut...'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Kondisi hydraulic
            _card(
              icon: Icons.settings_outlined,
              title: 'Kondisi Hydraulic',
              child: _kondisiSection(),
            ),
            const SizedBox(height: 12),

            // Foto tambahan
            _card(
              icon: Icons.photo_camera_outlined,
              title: 'Tambah Foto (opsional)',
              child: _fotoSection(),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kirim Perbaikan Laporan', style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _kondisiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _pressBox('Tekanan Sebelum', _pressBeforeCtrl, AppTheme.danger, AppTheme.dangerLight)),
          const SizedBox(width: 12),
          Expanded(child: _pressBox('Tekanan Sesudah', _pressAfterCtrl, AppTheme.secondary, AppTheme.secondaryLight)),
        ]),
        const SizedBox(height: 12),
        _lbl('Kondisi Oli'),
        const SizedBox(height: 6),
        _chips({'good': 'Baik', 'contaminated': 'Terkontaminasi', 'critical': 'Kritis'},
            _oilCondition, (v) => setState(() => _oilCondition = v),
            {'good': AppTheme.secondary, 'contaminated': AppTheme.warning, 'critical': AppTheme.danger}),
        const SizedBox(height: 12),
        _lbl('Level Oli'),
        const SizedBox(height: 6),
        _chips({'low': 'Rendah', 'normal': 'Normal', 'overfill': 'Kelebihan'},
            _oilLevel, (v) => setState(() => _oilLevel = v),
            {'low': AppTheme.danger, 'normal': AppTheme.secondary, 'overfill': AppTheme.warning}),
        const SizedBox(height: 12),
        _lbl('Tingkat Kebocoran'),
        const SizedBox(height: 6),
        _chips({'none': 'Tidak ada', 'minor': 'Minor', 'moderate': 'Sedang', 'severe': 'Parah'},
            _leakSeverity, (v) => setState(() => _leakSeverity = v),
            {'none': AppTheme.secondary, 'minor': AppTheme.warning, 'moderate': AppTheme.warning, 'severe': AppTheme.danger}),
        if (_leakSeverity != null && _leakSeverity != 'none') ...[
          const SizedBox(height: 12),
          _lbl('Lokasi Kebocoran'),
          TextFormField(controller: _leakLocCtrl,
              decoration: const InputDecoration(hintText: 'Contoh: Selang utama')),
        ],
      ],
    );
  }

  Widget _fotoSection() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        ..._photos.asMap().entries.map((e) {
          final entry = e.value;
          return SizedBox(width: 72, height: 72,
            child: Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.file(entry.file, width: 72, height: 72, fit: BoxFit.cover)),
              if (entry.url == null)
                Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: Container(color: Colors.black45,
                        child: const Center(child: SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))))),
              if (entry.url != null)
                Positioned(top: 2, right: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _photos.removeAt(e.key)),
                    child: Container(padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 10, color: Colors.white)),
                  )),
            ]),
          );
        }),
        if (_photos.length < 3)
          GestureDetector(
            onTap: () => showModalBottomSheet(context: context,
                builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Galeri'),
                      onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); }),
                  ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Kamera'),
                      onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); }),
                ]))),
            child: Container(width: 72, height: 72,
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border)),
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined, color: AppTheme.textTertiary, size: 24),
                SizedBox(height: 4),
                Text('Tambah', style: TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _card({required IconData icon, required String title, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 15, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 4),
      child: Text(t, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)));

  Widget _pressBox(String label, TextEditingController ctrl, Color color, Color bg) =>
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(controller: ctrl, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
            decoration: InputDecoration(hintText: '0', suffixText: 'bar',
              hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.3)),
              suffixStyle: TextStyle(fontSize: 13, color: color),
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero, isDense: true),
          ),
        ]),
      );

  Widget _chips(Map<String, String> opts, String? selected, ValueChanged<String> onSelect,
      Map<String, Color> colors) =>
      Wrap(spacing: 8, runSpacing: 6,
        children: opts.entries.map((e) {
          final sel = selected == e.key;
          final c = colors[e.key] ?? AppTheme.primary;
          return GestureDetector(
            onTap: () => onSelect(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? c.withValues(alpha: 0.12) : AppTheme.surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: sel ? c : AppTheme.border, width: sel ? 1.5 : 0.5),
              ),
              child: Text(e.value, style: TextStyle(fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  color: sel ? c : AppTheme.textSecondary)),
            ),
          );
        }).toList(),
      );
}

class _PhotoEntry {
  final File file;
  String? url;
  _PhotoEntry({required this.file});
}
