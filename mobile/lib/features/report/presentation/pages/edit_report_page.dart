import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/cache/page_cache.dart';
import '../../../../core/constants/app_constants.dart';
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
  List<Map<String, dynamic>> _inspectionItems = [];
  bool get _isInspeksi => (widget.booking['service_type'] as String? ?? '') == 'inspeksi';
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
    final rawItems = r['inspection_items'];
    if (rawItems is List) {
      _inspectionItems = List<Map<String, dynamic>>.from(
          rawItems.map((i) => Map<String, dynamic>.from(i as Map)));
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
      'inspection_items': _inspectionItems,
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
      PageCache.remove('job_board');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Laporan berhasil diperbaiki! Menunggu konfirmasi ulang dari client.'),
        backgroundColor: AppTheme.secondary,
      ));
      context.pop();
    } catch (e) {
      String msg = 'Gagal memperbaiki laporan';
      if (e is DioException) msg = (e.response?.data as Map?)?['message'] as String? ?? msg;
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

            // Item inspeksi (hanya untuk tipe inspeksi)
            if (_isInspeksi) ...[
              _card(
                icon: Icons.checklist_outlined,
                title: 'Item Inspeksi',
                trailing: TextButton.icon(
                  onPressed: _showAddInspectionSheet,
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Tambah', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                child: _inspectionSection(),
              ),
              const SizedBox(height: 12),
            ],

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

  void _showItemPickerSheet() {
    if (_inspectionItems.length == 1) {
      _showEditInspectionSheet(0);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                const Text('Pilih Item', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
            const Divider(height: 1),
            ..._inspectionItems.asMap().entries.map((e) {
              final i    = e.key;
              final item = e.value;
              final tCol = _iTypeColor(item['item_type'] as String? ?? '');
              return ListTile(
                leading: Container(width: 4, height: 36,
                    decoration: BoxDecoration(color: tCol, borderRadius: BorderRadius.circular(2))),
                title: Text(_iTypeLabel(item['item_type'] as String? ?? ''),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text(
                  '${_iConditionLabel(item['condition'] as String? ?? '')} • ${_iRecommendationLabel(item['recommendation'] as String? ?? '')}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                onTap: () {
                  Navigator.pop(context);
                  _showEditInspectionSheet(i);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddInspectionSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddInspectionItemSheet(),
    );
    if (result != null) setState(() => _inspectionItems.add(result));
  }

  Future<void> _showEditInspectionSheet(int index) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddInspectionItemSheet(initialItem: _inspectionItems[index]),
    );
    if (result != null) setState(() => _inspectionItems[index] = result);
  }

  Widget _inspectionSection() {
    if (_inspectionItems.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.dangerLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_outlined, size: 15, color: AppTheme.danger),
            SizedBox(width: 8),
            Expanded(
              child: Text('Minimal 1 item inspeksi wajib ditambahkan',
                  style: TextStyle(fontSize: 12, color: AppTheme.danger)),
            ),
          ],
        ),
      );
    }

    final total   = _inspectionItems.length;
    final baik    = _inspectionItems.where((i) => i['condition'] == 'good').length;
    final monitor = _inspectionItems.where((i) => i['condition'] == 'wear' || i['condition'] == 'cracked').length;
    final ganti   = _inspectionItems.where((i) => i['condition'] == 'leaking' || i['condition'] == 'critical').length;

    final itemCards = List.generate(_inspectionItems.length, (i) {
      final item = _inspectionItems[i];
      final cCol = _iConditionColor(item['condition'] as String? ?? '');
      final tCol = _iTypeColor(item['item_type'] as String? ?? '');
      return Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left:   BorderSide(color: tCol, width: 3),
            right:  const BorderSide(color: AppTheme.border, width: 0.5),
            top:    const BorderSide(color: AppTheme.border, width: 0.5),
            bottom: const BorderSide(color: AppTheme.border, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _iBadge(
                  _iTypeLabel(item['item_type'] as String? ?? ''),
                  tCol.withValues(alpha: 0.12), tCol,
                ),
                const SizedBox(height: 4),
                Row(children: [
                  _iBadge(
                    _iConditionLabel(item['condition'] as String? ?? ''),
                    cCol.withValues(alpha: 0.12), cCol,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _iRecommendationLabel(item['recommendation'] as String? ?? ''),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => _showEditInspectionSheet(i),
              child: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() => _inspectionItems.removeAt(i)),
              child: const Icon(Icons.close, size: 16, color: AppTheme.danger),
            ),
          ]),
        ]),
      );
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            _iStatChip('$total', 'Total', AppTheme.primary),
            const SizedBox(width: 12),
            _iStatChip('$baik', 'Baik', AppTheme.secondary),
            const SizedBox(width: 12),
            _iStatChip('$monitor', 'Monitor', AppTheme.warning),
            const SizedBox(width: 12),
            _iStatChip('$ganti', 'Ganti', AppTheme.danger),
            const Spacer(),
            // Tombol edit — pilih item dari daftar
            GestureDetector(
              onTap: () => _showItemPickerSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 13, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text('Edit', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ]),
        ),
        ...itemCards,
      ],
    );
  }

  Widget _iStatChip(String value, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
    ],
  );

  Widget _iBadge(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 10, color: fg)),
  );

  Color _iConditionColor(String c) {
    switch (c) {
      case 'good':     return AppTheme.secondary;
      case 'wear':
      case 'cracked':  return AppTheme.warning;
      case 'leaking':
      case 'critical': return AppTheme.danger;
      default:         return AppTheme.textTertiary;
    }
  }

  Color _iTypeColor(String t) {
    switch (t) {
      case 'hose':     return AppTheme.primary;
      case 'cylinder': return AppTheme.warning;
      case 'pump':     return AppTheme.secondary;
      default:         return AppTheme.textTertiary;
    }
  }

  String _iTypeLabel(String t) {
    const m = {'hose': 'Selang', 'cylinder': 'Silinder', 'pump': 'Pompa'};
    return m[t] ?? t;
  }

  String _iConditionLabel(String c) {
    const m = {'good': 'Baik', 'wear': 'Aus', 'cracked': 'Retak', 'leaking': 'Bocor', 'critical': 'Kritis'};
    return m[c] ?? c;
  }

  String _iRecommendationLabel(String r) {
    const m = {
      'no_action':        'Tidak perlu tindakan',
      'monitor':          'Perlu dipantau',
      'schedule_replace': 'Jadwalkan penggantian',
      'urgent_replace':   'Ganti segera',
    };
    return m[r] ?? r;
  }

  Widget _card({required IconData icon, required String title, required Widget child, Widget? trailing}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 15, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (trailing != null) ...[const Spacer(), trailing],
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

// ─── Bottom Sheet: Tambah Item Inspeksi ──────────────────────────────────────

class _AddInspectionItemSheet extends StatefulWidget {
  final Map<String, dynamic>? initialItem;
  const _AddInspectionItemSheet({this.initialItem});
  @override
  State<_AddInspectionItemSheet> createState() => _AddInspectionItemSheetState();
}

class _AddInspectionItemSheetState extends State<_AddInspectionItemSheet> {
  final _formKey = GlobalKey<FormState>();

  String _itemType       = 'hose';
  String _condition      = 'good';
  String _recommendation = 'no_action';

  final _notesCtrl      = TextEditingController();
  final _hoseLengthCtrl = TextEditingController();
  final _hoseDiamCtrl   = TextEditingController();
  final _hosePressCtrl  = TextEditingController();
  final _hoseMaterialCtrl = TextEditingController();
  final _hoseQtyCtrl    = TextEditingController(text: '1');
  String _fit1Std = 'ORFS'; String _fit1Angle = 'straight'; String _fit1Gender = 'male';
  String _fit2Std = 'ORFS'; String _fit2Angle = 'straight'; String _fit2Gender = 'male';

  final _cylBoreCtrl   = TextEditingController();
  final _cylStrokeCtrl = TextEditingController();
  final _cylPressCtrl  = TextEditingController();
  String _cylRodCond  = 'good';
  String _cylSealCond = 'good';

  final _pumpTypeCtrl  = TextEditingController();
  final _pumpFlowCtrl  = TextEditingController();
  final _pumpPressCtrl = TextEditingController();
  final _pumpNoiseCtrl = TextEditingController();
  final _pumpTempCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.initialItem;
    if (init == null) return;
    _itemType       = init['item_type']      as String? ?? 'hose';
    _condition      = init['condition']      as String? ?? 'good';
    _recommendation = init['recommendation'] as String? ?? 'no_action';
    _notesCtrl.text = init['notes']          as String? ?? '';
    final specs = (init['specifications'] as Map?)?.cast<String, dynamic>() ?? {};
    switch (_itemType) {
      case 'hose':
        _hoseLengthCtrl.text   = (specs['length_m']      ?? '').toString();
        _hoseDiamCtrl.text     = specs['diameter_inch']  as String? ?? '';
        _hosePressCtrl.text    = (specs['pressure_bar']  ?? '').toString();
        _hoseMaterialCtrl.text = specs['material']       as String? ?? '';
        _hoseQtyCtrl.text      = (specs['qty']           ?? 1).toString();
        final fe1 = (specs['fitting_end1'] as Map?)?.cast<String, dynamic>() ?? {};
        final fe2 = (specs['fitting_end2'] as Map?)?.cast<String, dynamic>() ?? {};
        _fit1Std    = fe1['standard'] as String? ?? 'ORFS';
        _fit1Angle  = fe1['angle']    as String? ?? 'straight';
        _fit1Gender = fe1['gender']   as String? ?? 'male';
        _fit2Std    = fe2['standard'] as String? ?? 'ORFS';
        _fit2Angle  = fe2['angle']    as String? ?? 'straight';
        _fit2Gender = fe2['gender']   as String? ?? 'male';
      case 'cylinder':
        _cylBoreCtrl.text   = (specs['bore_mm']      ?? '').toString();
        _cylStrokeCtrl.text = (specs['stroke_mm']    ?? '').toString();
        _cylPressCtrl.text  = (specs['pressure_bar'] ?? '').toString();
        _cylRodCond  = specs['rod_condition']  as String? ?? 'good';
        _cylSealCond = specs['seal_condition'] as String? ?? 'good';
      case 'pump':
        _pumpTypeCtrl.text  = specs['pump_type']     as String? ?? '';
        _pumpFlowCtrl.text  = (specs['flow_lpm']     ?? '').toString();
        _pumpPressCtrl.text = (specs['pressure_bar'] ?? '').toString();
        _pumpNoiseCtrl.text = specs['noise_level']   as String? ?? '';
        _pumpTempCtrl.text  = (specs['temperature_c'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _hoseLengthCtrl.dispose(); _hoseDiamCtrl.dispose();
    _hosePressCtrl.dispose(); _hoseMaterialCtrl.dispose(); _hoseQtyCtrl.dispose();
    _cylBoreCtrl.dispose(); _cylStrokeCtrl.dispose(); _cylPressCtrl.dispose();
    _pumpTypeCtrl.dispose(); _pumpFlowCtrl.dispose(); _pumpPressCtrl.dispose();
    _pumpNoiseCtrl.dispose(); _pumpTempCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildSpecs() {
    switch (_itemType) {
      case 'hose':
        return {
          'length_m':      double.tryParse(_hoseLengthCtrl.text) ?? 0,
          'diameter_inch': _hoseDiamCtrl.text,
          'pressure_bar':  int.tryParse(_hosePressCtrl.text) ?? 0,
          'material':      _hoseMaterialCtrl.text,
          'qty':           int.tryParse(_hoseQtyCtrl.text) ?? 1,
          'fitting_end1':  {'standard': _fit1Std, 'angle': _fit1Angle, 'gender': _fit1Gender},
          'fitting_end2':  {'standard': _fit2Std, 'angle': _fit2Angle, 'gender': _fit2Gender},
        };
      case 'cylinder':
        return {
          'bore_mm':        int.tryParse(_cylBoreCtrl.text) ?? 0,
          'stroke_mm':      int.tryParse(_cylStrokeCtrl.text) ?? 0,
          'pressure_bar':   int.tryParse(_cylPressCtrl.text) ?? 0,
          'rod_condition':  _cylRodCond,
          'seal_condition': _cylSealCond,
        };
      case 'pump':
        return {
          'pump_type':     _pumpTypeCtrl.text,
          'flow_lpm':      double.tryParse(_pumpFlowCtrl.text) ?? 0,
          'pressure_bar':  int.tryParse(_pumpPressCtrl.text) ?? 0,
          'noise_level':   _pumpNoiseCtrl.text,
          'temperature_c': double.tryParse(_pumpTempCtrl.text) ?? 0,
        };
      default:
        return {};
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'item_type':      _itemType,
      'item_code':      '',
      'location_desc':  '',
      'condition':      _condition,
      'recommendation': _recommendation,
      'notes':          _notesCtrl.text.trim(),
      'specifications': _buildSpecs(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxH   = MediaQuery.sizeOf(context).height * 0.92;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Text(
                  widget.initialItem != null ? 'Edit Item Inspeksi' : 'Tambah Item Inspeksi',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
              const SizedBox(height: 16),
              _lbl('Tipe Item *'),
              DropdownButtonFormField<String>(
                initialValue: _itemType,
                decoration: _dropDeco(),
                items: const [
                  DropdownMenuItem(value: 'hose',     child: Text('Selang (Hose)')),
                  DropdownMenuItem(value: 'cylinder', child: Text('Silinder')),
                  DropdownMenuItem(value: 'pump',     child: Text('Pompa')),
                ],
                onChanged: (v) => setState(() => _itemType = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _drop2('Kondisi *', _condition,
                    const {'good': 'Baik', 'wear': 'Aus', 'cracked': 'Retak', 'leaking': 'Bocor', 'critical': 'Kritis'},
                    (v) { _condition = v!; })),
                const SizedBox(width: 12),
                Expanded(child: _drop2('Rekomendasi *', _recommendation,
                    const {'no_action': 'Tidak ada', 'monitor': 'Pantau', 'schedule_replace': 'Jadwal ganti', 'urgent_replace': 'Ganti segera'},
                    (v) { _recommendation = v!; })),
              ]),
              const SizedBox(height: 12),
              if (_itemType == 'hose')     _hoseSpecs(),
              if (_itemType == 'cylinder') _cylinderSpecs(),
              if (_itemType == 'pump')     _pumpSpecs(),
              _lbl('Catatan'),
              TextFormField(controller: _notesCtrl, maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Catatan tambahan (opsional)')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: Text(
                  widget.initialItem != null ? 'Simpan Perubahan' : 'Tambah Item',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _hoseSpecs() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sub('Spesifikasi Selang'),
    Row(children: [
      Expanded(child: _field('Panjang (m)', _hoseLengthCtrl, hint: '1.5', isDecimal: true)),
      const SizedBox(width: 10),
      Expanded(child: _field('Diameter (inch)', _hoseDiamCtrl, hint: '1/2"')),
      const SizedBox(width: 10),
      Expanded(child: _numField('Tekanan (bar)', _hosePressCtrl)),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _field('Material', _hoseMaterialCtrl, hint: 'Rubber')),
      const SizedBox(width: 10),
      Expanded(child: _numField('Qty', _hoseQtyCtrl)),
    ]),
    const SizedBox(height: 10),
    _fittingRow('Fitting End 1', _fit1Std, _fit1Angle, _fit1Gender,
        (v) { _fit1Std = v!; }, (v) { _fit1Angle = v!; }, (v) { _fit1Gender = v!; }),
    const SizedBox(height: 10),
    _fittingRow('Fitting End 2', _fit2Std, _fit2Angle, _fit2Gender,
        (v) { _fit2Std = v!; }, (v) { _fit2Angle = v!; }, (v) { _fit2Gender = v!; }),
    const SizedBox(height: 12),
  ]);

  Widget _cylinderSpecs() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sub('Spesifikasi Silinder'),
    Row(children: [
      Expanded(child: _numField('Bore (mm)', _cylBoreCtrl)),
      const SizedBox(width: 10),
      Expanded(child: _numField('Stroke (mm)', _cylStrokeCtrl)),
      const SizedBox(width: 10),
      Expanded(child: _numField('Tekanan (bar)', _cylPressCtrl)),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _drop2('Kondisi Rod', _cylRodCond,
          const {'good': 'Baik', 'wear': 'Aus', 'cracked': 'Retak', 'leaking': 'Bocor'},
          (v) { _cylRodCond = v!; })),
      const SizedBox(width: 10),
      Expanded(child: _drop2('Kondisi Seal', _cylSealCond,
          const {'good': 'Baik', 'wear': 'Aus', 'cracked': 'Retak', 'leaking': 'Bocor'},
          (v) { _cylSealCond = v!; })),
    ]),
    const SizedBox(height: 12),
  ]);

  Widget _pumpSpecs() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _sub('Spesifikasi Pompa'),
    Row(children: [
      Expanded(child: _field('Tipe Pompa', _pumpTypeCtrl, hint: 'Gear pump')),
      const SizedBox(width: 10),
      Expanded(child: _field('Flow (lpm)', _pumpFlowCtrl, hint: '20', isDecimal: true)),
      const SizedBox(width: 10),
      Expanded(child: _numField('Tekanan (bar)', _pumpPressCtrl)),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: _field('Noise level', _pumpNoiseCtrl, hint: 'Normal')),
      const SizedBox(width: 10),
      Expanded(child: _field('Suhu (°C)', _pumpTempCtrl, hint: '40', isDecimal: true)),
    ]),
    const SizedBox(height: 12),
  ]);

  Widget _fittingRow(String title, String std, String angle, String gender,
      ValueChanged<String?> onStd, ValueChanged<String?> onAngle, ValueChanged<String?> onGender) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _miniDrop('Standar', std, AppConstants.fittingStandards, onStd)),
          const SizedBox(width: 6),
          Expanded(child: _miniDrop('Sudut', angle, AppConstants.fittingAngles, onAngle)),
          const SizedBox(width: 6),
          Expanded(child: _miniDrop('Gender', gender, AppConstants.fittingGenders, onGender)),
        ]),
      ]);

  Widget _miniDrop(String label, String value, List<String> opts, ValueChanged<String?> onChange) =>
      DropdownButtonFormField<String>(
        initialValue: value, isExpanded: true,
        decoration: InputDecoration(
          labelText: label, labelStyle: const TextStyle(fontSize: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        items: opts.map((s) => DropdownMenuItem(value: s,
            child: Text(s, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChange,
      );

  Widget _field(String label, TextEditingController ctrl, {String hint = '', bool isDecimal = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(label),
        TextFormField(controller: ctrl,
            keyboardType: isDecimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(hintText: hint)),
      ]);

  Widget _numField(String label, TextEditingController ctrl) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(label),
        TextFormField(controller: ctrl, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: '0')),
      ]);

  Widget _drop2(String label, String initialVal, Map<String, String> items, ValueChanged<String?> onChanged) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(label),
        DropdownButtonFormField<String>(
          initialValue: initialVal, isExpanded: true,
          decoration: _dropDeco(),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: onChanged,
        ),
      ]);

  Widget _sub(String text) => Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)));

  Widget _lbl(String text) => Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)));

  InputDecoration _dropDeco() => InputDecoration(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
