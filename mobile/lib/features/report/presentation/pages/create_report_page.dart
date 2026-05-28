import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class CreateReportPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  const CreateReportPage({super.key, required this.booking});

  @override
  State<CreateReportPage> createState() => _CreateReportPageState();
}

class _CreateReportPageState extends State<CreateReportPage> {
  final _formKey = GlobalKey<FormState>();

  final _descCtrl        = TextEditingController();
  final _recsCtrl        = TextEditingController();
  final _pressBeforeCtrl = TextEditingController();
  final _pressAfterCtrl  = TextEditingController();
  final _leakLocCtrl     = TextEditingController();

  String? _oilCondition;
  String? _oilLevel;
  String? _leakSeverity;

  final List<Map<String, dynamic>> _inspectionItems = [];

  final List<Map<String, dynamic>> _maintenanceChecklist = [
    {'item': 'Cek level oli',               'status': 'done', 'notes': ''},
    {'item': 'Ganti filter oli',            'status': 'done', 'notes': ''},
    {'item': 'Cek kebocoran semua fitting', 'status': 'done', 'notes': ''},
    {'item': 'Cek tekanan sistem',          'status': 'done', 'notes': ''},
    {'item': 'Bersihkan strainer',          'status': 'done', 'notes': ''},
    {'item': 'Cek kondisi hose',            'status': 'done', 'notes': ''},
  ];

  bool _loading = false;

  // Foto before/after/kerusakan — File lokal + URL setelah upload
  final List<_PhotoEntry> _photos = [];
  final _picker = ImagePicker();

  String get _serviceType   => widget.booking['service_type'] ?? '';
  bool   get _isInspeksi    => _serviceType == 'inspeksi';
  bool   get _isMaintenance => _serviceType == 'maintenance';

  @override
  void dispose() {
    _descCtrl.dispose();
    _recsCtrl.dispose();
    _pressBeforeCtrl.dispose();
    _pressAfterCtrl.dispose();
    _leakLocCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isInspeksi && _inspectionItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tambahkan minimal 1 item inspeksi'),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }

    // Block submit if any photo is still uploading
    if (_photos.any((p) => p.url == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tunggu hingga semua foto selesai diupload'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    setState(() => _loading = true);

    final photoUrls = _photos.asMap().entries.map((e) {
      final types = ['before', 'after', 'damage'];
      final type  = e.key < types.length ? types[e.key] : 'damage';
      return {'url': e.value.url!, 'type': type};
    }).toList();

    final data = <String, dynamic>{
      'work_description':      _descCtrl.text.trim(),
      'recommendations':       _recsCtrl.text.trim(),
      'parts_replaced':        [],
      'photo_urls':            photoUrls,
      'inspection_items':      _inspectionItems,
      'maintenance_checklist': _isMaintenance ? _maintenanceChecklist : [],
    };

    if (_pressBeforeCtrl.text.isNotEmpty) {
      data['pressure_before_bar'] = int.tryParse(_pressBeforeCtrl.text);
    }
    if (_pressAfterCtrl.text.isNotEmpty) {
      data['pressure_after_bar'] = int.tryParse(_pressAfterCtrl.text);
    }
    if (_oilCondition != null)        data['oil_condition'] = _oilCondition;
    if (_oilLevel != null)            data['oil_level']     = _oilLevel;
    if (_leakLocCtrl.text.isNotEmpty) data['leak_location'] = _leakLocCtrl.text.trim();
    if (_leakSeverity != null)        data['leak_severity'] = _leakSeverity;

    try {
      await ApiClient.instance.post(
        '/reports/${widget.booking['id']}',
        data: data,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Laporan berhasil dikirim! Booking selesai.'),
        backgroundColor: AppTheme.secondary,
      ));
      context.go('/job-board');
    } catch (e) {
      String msg = 'Gagal mengirim laporan';
      if (e is DioException) {
        msg = e.response?.data['message'] ?? msg;
        debugPrint('Report error: ${e.response?.data}');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Laporan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/job-board'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _bookingSummaryCard(),
            const SizedBox(height: 16),
            _sectionCard(
              icon: Icons.description_outlined,
              title: 'Deskripsi Pekerjaan',
              child: _deskripsiSection(),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              icon: Icons.settings_outlined,
              title: 'Kondisi Hydraulic',
              child: _kondisiSection(),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              icon: Icons.photo_camera_outlined,
              title: 'Foto Before & After (opsional)',
              child: _fotoSection(),
            ),
            if (_isInspeksi) ...[
              const SizedBox(height: 12),
              _sectionCard(
                icon: Icons.checklist_outlined,
                title: 'Item Inspeksi',
                trailing: _addButton('Tambah', _showAddInspectionSheet),
                child: _inspectionSection(),
              ),
            ],
            if (_isMaintenance) ...[
              const SizedBox(height: 12),
              _sectionCard(
                icon: Icons.checklist_outlined,
                title: 'Checklist Maintenance',
                child: _maintenanceSection(),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit laporan & generate PDF',
                      style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── SECTION WIDGETS ──────────────────────────────────────────────────────

  Widget _bookingSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 15, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text('Info Booking',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(_serviceType,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.warning)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.booking['company_name'] ?? '-',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(widget.booking['equipment_name'] ?? '-',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 13, color: AppTheme.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${widget.booking['site_address'] ?? '-'}, '
                  '${widget.booking['site_city'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textTertiary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deskripsiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Deskripsi pekerjaan yang dilakukan *'),
        TextFormField(
          controller: _descCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
              hintText: 'Jelaskan pekerjaan yang telah dilakukan...'),
          validator: (v) =>
              v == null || v.isEmpty ? 'Deskripsi wajib diisi' : null,
        ),
        const SizedBox(height: 12),
        _label('Rekomendasi tindak lanjut'),
        TextFormField(
          controller: _recsCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
              hintText: 'Masukkan rekomendasi (opsional)'),
        ),
      ],
    );
  }

  Widget _kondisiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pressure colored boxes
        Row(
          children: [
            Expanded(
              child: _pressureBox(
                label: 'Tekanan Sebelum',
                ctrl: _pressBeforeCtrl,
                color: AppTheme.danger,
                bgColor: AppTheme.dangerLight,
                icon: Icons.arrow_downward,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _pressureBox(
                label: 'Tekanan Sesudah',
                ctrl: _pressAfterCtrl,
                color: AppTheme.secondary,
                bgColor: AppTheme.secondaryLight,
                icon: Icons.arrow_upward,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Kondisi Oli chips
        _label('Kondisi Oli'),
        const SizedBox(height: 6),
        _chipSelector(
          options: const {
            'good': 'Baik',
            'contaminated': 'Terkontaminasi',
            'critical': 'Kritis',
          },
          selected: _oilCondition,
          onSelect: (v) => setState(() => _oilCondition = v),
          activeColors: const {
            'good': AppTheme.secondary,
            'contaminated': AppTheme.warning,
            'critical': AppTheme.danger,
          },
        ),
        const SizedBox(height: 12),

        // Level Oli chips
        _label('Level Oli'),
        const SizedBox(height: 6),
        _chipSelector(
          options: const {
            'low': 'Rendah',
            'normal': 'Normal',
            'overfill': 'Kelebihan',
          },
          selected: _oilLevel,
          onSelect: (v) => setState(() => _oilLevel = v),
          activeColors: const {
            'low': AppTheme.danger,
            'normal': AppTheme.secondary,
            'overfill': AppTheme.warning,
          },
        ),
        const SizedBox(height: 12),

        // Tingkat Kebocoran chips
        _label('Tingkat Kebocoran'),
        const SizedBox(height: 6),
        _chipSelector(
          options: const {
            'none': 'Tidak ada',
            'minor': 'Minor',
            'moderate': 'Sedang',
            'severe': 'Parah',
          },
          selected: _leakSeverity,
          onSelect: (v) => setState(() => _leakSeverity = v),
          activeColors: const {
            'none': AppTheme.secondary,
            'minor': AppTheme.warning,
            'moderate': AppTheme.warning,
            'severe': AppTheme.danger,
          },
        ),

        // Lokasi kebocoran — only if not 'none'
        if (_leakSeverity != null && _leakSeverity != 'none') ...[
          const SizedBox(height: 12),
          _label('Lokasi Kebocoran'),
          TextFormField(
            controller: _leakLocCtrl,
            decoration:
                const InputDecoration(hintText: 'Contoh: Selang utama'),
          ),
        ],
      ],
    );
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil foto'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1920,
    );
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
          content: Text('Gagal upload foto, coba lagi'),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  Widget _fotoSection() {
    const typeLabels = ['Before', 'After', 'Kerusakan'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._photos.asMap().entries.map((e) {
          final i     = e.key;
          final entry = e.value;
          return SizedBox(
            width: 72, height: 72,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    entry.file,
                    width: 72, height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                // Upload progress overlay
                if (entry.url == null)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        color: Colors.black45,
                        child: const Center(
                          child: SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Type label
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(10)),
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        i < typeLabels.length ? typeLabels[i] : 'Foto',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 9, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                // Delete (only when upload done)
                if (entry.url != null)
                  Positioned(
                    top: 2, right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.danger,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            size: 10, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        // Add button — max 6 photos
        if (_photos.length < 6)
          GestureDetector(
            onTap: _showPhotoSourcePicker,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AppTheme.textTertiary, size: 24),
                  SizedBox(height: 4),
                  Text('Tambah',
                      style: TextStyle(
                          fontSize: 9, color: AppTheme.textTertiary)),
                ],
              ),
            ),
          ),
      ],
    );
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
    final monitor = _inspectionItems
        .where((i) => i['condition'] == 'wear' || i['condition'] == 'cracked')
        .length;
    final ganti   = _inspectionItems
        .where((i) => i['condition'] == 'leaking' || i['condition'] == 'critical')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary stats
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _inlineStatChip('$total', 'Total', AppTheme.primary),
              const SizedBox(width: 12),
              _inlineStatChip('$baik', 'Baik', AppTheme.secondary),
              const SizedBox(width: 12),
              _inlineStatChip('$monitor', 'Monitor', AppTheme.warning),
              const SizedBox(width: 12),
              _inlineStatChip('$ganti', 'Ganti', AppTheme.danger),
            ],
          ),
        ),
        // Item cards
        ..._inspectionItems.asMap().entries.map((e) {
          final i    = e.key;
          final item = e.value;
          final cColor    = _conditionColor(item['condition'] ?? '');
          final typeColor = _itemTypeColor(item['item_type'] ?? '');

          return Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left:   BorderSide(color: typeColor, width: 3),
                right:  const BorderSide(color: AppTheme.border, width: 0.5),
                top:    const BorderSide(color: AppTheme.border, width: 0.5),
                bottom: const BorderSide(color: AppTheme.border, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _badge(_itemTypeLabel(item['item_type'] ?? ''),
                              typeColor.withValues(alpha: 0.12), typeColor),
                          const SizedBox(width: 6),
                          if ((item['item_code'] ?? '').isNotEmpty)
                            Text(item['item_code'],
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500)),
                        ],
                      ),
                      if ((item['location_desc'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(item['location_desc'],
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _badge(_conditionLabel(item['condition'] ?? ''),
                              cColor.withValues(alpha: 0.12), cColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _recommendationLabel(
                                  item['recommendation'] ?? ''),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textTertiary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _inspectionItems.removeAt(i)),
                  child: const Icon(Icons.close,
                      size: 16, color: AppTheme.danger),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _maintenanceSection() {
    const statusOptions = ['done', 'skip', 'not_applicable'];
    const statusLabels  = {
      'done': 'Done', 'skip': 'Skip', 'not_applicable': 'N/A'
    };
    const statusColors = <String, Color>{
      'done':           AppTheme.secondary,
      'skip':           AppTheme.warning,
      'not_applicable': AppTheme.textTertiary,
    };

    return Column(
      children: _maintenanceChecklist.asMap().entries.map((e) {
        final i             = e.key;
        final item          = e.value;
        final currentStatus = item['status'] as String;

        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item['item'] as String,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Row(
                    children: statusOptions.map((s) {
                      final selected = currentStatus == s;
                      final color    = statusColors[s]!;
                      return GestureDetector(
                        onTap: () => setState(
                            () => _maintenanceChecklist[i]['status'] = s),
                        child: Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selected ? color : AppTheme.border,
                            ),
                          ),
                          child: Text(
                            statusLabels[s]!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selected ? color : AppTheme.textTertiary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: item['notes'] as String,
                onChanged: (v) =>
                    setState(() => _maintenanceChecklist[i]['notes'] = v),
                decoration: const InputDecoration(
                  hintText: 'Catatan (opsional)',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── DIALOGS ──────────────────────────────────────────────────────────────

  Future<void> _showAddInspectionSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddInspectionItemSheet(),
    );
    if (result != null) setState(() => _inspectionItems.add(result));
  }

  // ─── HELPER WIDGETS ───────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _addButton(String label, VoidCallback onTap) => TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );

  Widget _pressureBox({
    required String label,
    required TextEditingController ctrl,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color.withValues(alpha: 0.3)),
              suffixText: 'bar',
              suffixStyle: TextStyle(fontSize: 13, color: color),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipSelector({
    required Map<String, String> options,
    required String? selected,
    required ValueChanged<String> onSelect,
    required Map<String, Color> activeColors,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options.entries.map((e) {
        final isSelected = selected == e.key;
        final color = activeColors[e.key] ?? AppTheme.primary;
        return GestureDetector(
          onTap: () => onSelect(e.key),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.12) : AppTheme.surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: isSelected ? color : AppTheme.border,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Text(
              e.value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : AppTheme.textSecondary),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _inlineStatChip(String value, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      );

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 10, color: fg)),
      );

  Color _conditionColor(String c) {
    switch (c) {
      case 'good':    return AppTheme.secondary;
      case 'wear':
      case 'cracked': return AppTheme.warning;
      case 'leaking':
      case 'critical': return AppTheme.danger;
      default:        return AppTheme.textTertiary;
    }
  }

  Color _itemTypeColor(String t) {
    switch (t) {
      case 'hose':     return AppTheme.primary;
      case 'cylinder': return AppTheme.warning;
      case 'pump':     return AppTheme.secondary;
      default:         return AppTheme.textTertiary;
    }
  }

  String _itemTypeLabel(String t) {
    const m = {'hose': 'Selang', 'cylinder': 'Silinder', 'pump': 'Pompa'};
    return m[t] ?? t;
  }

  String _conditionLabel(String c) {
    const m = {
      'good': 'Baik', 'wear': 'Aus', 'cracked': 'Retak',
      'leaking': 'Bocor', 'critical': 'Kritis',
    };
    return m[c] ?? c;
  }

  String _recommendationLabel(String r) {
    const m = {
      'no_action':        'Tidak perlu tindakan',
      'monitor':          'Perlu dipantau',
      'schedule_replace': 'Jadwalkan penggantian',
      'urgent_replace':   'Ganti segera',
    };
    return m[r] ?? r;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo entry: local file + uploaded URL
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoEntry {
  final File file;
  String? url;
  _PhotoEntry({required this.file});
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheet: Tambah Item Inspeksi
// ─────────────────────────────────────────────────────────────────────────────

class _AddInspectionItemSheet extends StatefulWidget {
  const _AddInspectionItemSheet();

  @override
  State<_AddInspectionItemSheet> createState() =>
      _AddInspectionItemSheetState();
}

class _AddInspectionItemSheetState extends State<_AddInspectionItemSheet> {
  final _formKey = GlobalKey<FormState>();

  String _itemType       = 'hose';
  String _condition      = 'good';
  String _recommendation = 'no_action';

  final _codeCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();

  // Hose specs
  final _hoseLengthCtrl   = TextEditingController();
  final _hoseDiamCtrl     = TextEditingController();
  final _hosePressCtrl    = TextEditingController();
  final _hoseMaterialCtrl = TextEditingController();
  final _hoseQtyCtrl      = TextEditingController(text: '1');
  String _fit1Std = 'ORFS'; String _fit1Angle = 'straight'; String _fit1Gender = 'male';
  String _fit2Std = 'ORFS'; String _fit2Angle = 'straight'; String _fit2Gender = 'male';

  // Cylinder specs
  final _cylBoreCtrl   = TextEditingController();
  final _cylStrokeCtrl = TextEditingController();
  final _cylPressCtrl  = TextEditingController();
  String _cylRodCond  = 'good';
  String _cylSealCond = 'good';

  // Pump specs
  final _pumpTypeCtrl  = TextEditingController();
  final _pumpFlowCtrl  = TextEditingController();
  final _pumpPressCtrl = TextEditingController();
  final _pumpNoiseCtrl = TextEditingController();
  final _pumpTempCtrl  = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose(); _locationCtrl.dispose(); _notesCtrl.dispose();
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
          'fitting_end1': {
            'standard': _fit1Std,
            'angle': _fit1Angle,
            'gender': _fit1Gender
          },
          'fitting_end2': {
            'standard': _fit2Std,
            'angle': _fit2Angle,
            'gender': _fit2Gender
          },
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
      'item_code':      _codeCtrl.text.trim(),
      'location_desc':  _locationCtrl.text.trim(),
      'condition':      _condition,
      'recommendation': _recommendation,
      'notes':          _notesCtrl.text.trim(),
      'specifications': _buildSpecs(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
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
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Tambah Item Inspeksi',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _lbl('Tipe Item *'),
              DropdownButtonFormField<String>(
                value: _itemType,
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
                Expanded(child: _field('Kode Item', _codeCtrl, hint: 'H-001')),
                const SizedBox(width: 12),
                Expanded(child: _field('Lokasi', _locationCtrl, hint: 'Mesin utama')),
              ]),
              const SizedBox(height: 12),

              Row(children: [
                Expanded(child: _dropdownField2(
                  'Kondisi *', _condition,
                  const {
                    'good': 'Baik', 'wear': 'Aus', 'cracked': 'Retak',
                    'leaking': 'Bocor', 'critical': 'Kritis'
                  },
                  (v) => setState(() => _condition = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: _dropdownField2(
                  'Rekomendasi *', _recommendation,
                  const {
                    'no_action': 'Tidak ada', 'monitor': 'Pantau',
                    'schedule_replace': 'Jadwal ganti',
                    'urgent_replace': 'Ganti segera'
                  },
                  (v) => setState(() => _recommendation = v!),
                )),
              ]),
              const SizedBox(height: 12),

              if (_itemType == 'hose')     _hoseSpecs(),
              if (_itemType == 'cylinder') _cylinderSpecs(),
              if (_itemType == 'pump')     _pumpSpecs(),

              _lbl('Catatan'),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    hintText: 'Catatan tambahan (opsional)'),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _submit,
                child: const Text('Tambah Item',
                    style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hoseSpecs() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subHeader('Spesifikasi Selang'),
          Row(children: [
            Expanded(child: _field('Panjang (m)', _hoseLengthCtrl,
                hint: '1.5', isDecimal: true)),
            const SizedBox(width: 10),
            Expanded(child: _field('Diameter (inch)', _hoseDiamCtrl, hint: '1/2"')),
            const SizedBox(width: 10),
            Expanded(child: _numberField2('Tekanan (bar)', _hosePressCtrl)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('Material', _hoseMaterialCtrl, hint: 'Rubber')),
            const SizedBox(width: 10),
            Expanded(child: _numberField2('Qty', _hoseQtyCtrl)),
          ]),
          const SizedBox(height: 10),
          _fittingRow('Fitting End 1', _fit1Std, _fit1Angle, _fit1Gender,
              (v) => setState(() => _fit1Std = v!),
              (v) => setState(() => _fit1Angle = v!),
              (v) => setState(() => _fit1Gender = v!)),
          const SizedBox(height: 10),
          _fittingRow('Fitting End 2', _fit2Std, _fit2Angle, _fit2Gender,
              (v) => setState(() => _fit2Std = v!),
              (v) => setState(() => _fit2Angle = v!),
              (v) => setState(() => _fit2Gender = v!)),
          const SizedBox(height: 12),
        ],
      );

  Widget _cylinderSpecs() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subHeader('Spesifikasi Silinder'),
          Row(children: [
            Expanded(child: _numberField2('Bore (mm)', _cylBoreCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _numberField2('Stroke (mm)', _cylStrokeCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _numberField2('Tekanan (bar)', _cylPressCtrl)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _dropdownField2('Kondisi Rod', _cylRodCond,
                const {'good':'Baik','wear':'Aus','cracked':'Retak','leaking':'Bocor'},
                (v) => setState(() => _cylRodCond = v!))),
            const SizedBox(width: 10),
            Expanded(child: _dropdownField2('Kondisi Seal', _cylSealCond,
                const {'good':'Baik','wear':'Aus','cracked':'Retak','leaking':'Bocor'},
                (v) => setState(() => _cylSealCond = v!))),
          ]),
          const SizedBox(height: 12),
        ],
      );

  Widget _pumpSpecs() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subHeader('Spesifikasi Pompa'),
          Row(children: [
            Expanded(child: _field('Tipe Pompa', _pumpTypeCtrl, hint: 'Gear pump')),
            const SizedBox(width: 10),
            Expanded(child: _field('Flow (lpm)', _pumpFlowCtrl,
                hint: '20', isDecimal: true)),
            const SizedBox(width: 10),
            Expanded(child: _numberField2('Tekanan (bar)', _pumpPressCtrl)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('Noise level', _pumpNoiseCtrl, hint: 'Normal')),
            const SizedBox(width: 10),
            Expanded(child: _field('Suhu (°C)', _pumpTempCtrl,
                hint: '40', isDecimal: true)),
          ]),
          const SizedBox(height: 12),
        ],
      );

  Widget _fittingRow(String title, String std, String angle, String gender,
      ValueChanged<String?> onStd,
      ValueChanged<String?> onAngle,
      ValueChanged<String?> onGender) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _miniDropdown('Standar', std,
                AppConstants.fittingStandards, onStd)),
            const SizedBox(width: 6),
            Expanded(child: _miniDropdown('Sudut', angle,
                AppConstants.fittingAngles, onAngle)),
            const SizedBox(width: 6),
            Expanded(child: _miniDropdown('Gender', gender,
                AppConstants.fittingGenders, onGender)),
          ]),
        ],
      );

  Widget _miniDropdown(String label, String value,
      List<String> opts, ValueChanged<String?> onChange) =>
      DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        items: opts
            .map((s) => DropdownMenuItem(
                value: s,
                child: Text(s,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: onChange,
      );

  Widget _field(String label, TextEditingController ctrl,
      {String hint = '', bool isDecimal = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lbl(label),
          TextFormField(
            controller: ctrl,
            keyboardType: isDecimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      );

  Widget _numberField2(String label, TextEditingController ctrl) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lbl(label),
          TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: '0'),
          ),
        ],
      );

  Widget _dropdownField2(String label, String value,
      Map<String, String> items, ValueChanged<String?> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lbl(label),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            decoration: _dropDeco(),
            items: items.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      );

  Widget _subHeader(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
      );

  Widget _lbl(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
      );

  InputDecoration _dropDeco() => InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
