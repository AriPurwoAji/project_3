import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/photo_viewer.dart';

class ReportDetailPage extends StatefulWidget {
  final String bookingId;
  const ReportDetailPage({super.key, required this.bookingId});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  Map<String, dynamic>? _report;
  Map<String, dynamic>? _booking;
  bool   _loading         = true;
  bool   _downloadingPdf  = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/reports/${widget.bookingId}'),
        ApiClient.instance.get('/bookings/${widget.bookingId}'),
      ]);
      if (mounted) {
        setState(() {
          _report  = Map<String, dynamic>.from(
              results[0].data['data'] ?? {});
          _booking = Map<String, dynamic>.from(
              results[1].data['data'] ?? {});
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sharePdf(String url) async {
    if (_downloadingPdf) return;
    setState(() => _downloadingPdf = true);
    try {
      final dir  = await getTemporaryDirectory();
      final id   = _report?['id'] as String? ?? 'report';
      final path = '${dir.path}/laporan_$id.pdf';
      if (!File(path).existsSync()) {
        await Dio().download(url, path);
      }
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf')],
        subject: 'Laporan Servis HydroServ',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh PDF')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const m  = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                   'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${dt.day} ${m[dt.month]} ${dt.year}';
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Laporan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_report?['pdf_url'] != null)
            TextButton.icon(
              onPressed: _downloadingPdf
                  ? null
                  : () => _sharePdf(_report!['pdf_url'] as String),
              icon: _downloadingPdf
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.share_outlined, size: 16),
              label: const Text('PDF'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? const Center(
                  child: Text('Laporan tidak ditemukan',
                      style: TextStyle(color: AppTheme.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _buildInfoCard(),
                      if (_isRepairOrMaintenance) ...[
                        const SizedBox(height: 12),
                        _buildHydraulicCard(),
                      ],
                      if (_isMaintenance &&
                          (_report!['maintenance_checklist'] as List?)
                                  ?.isNotEmpty ==
                              true) ...[
                        const SizedBox(height: 12),
                        _buildChecklistCard(),
                      ],
                      if (_isInspeksi &&
                          (_report!['inspection_items'] as List?)
                                  ?.isNotEmpty ==
                              true) ...[
                        const SizedBox(height: 12),
                        _buildInspectionCard(),
                      ],
                      const SizedBox(height: 12),
                      _buildTextSection(
                          'Deskripsi Pekerjaan',
                          _report!['work_description'] ?? '-',
                          Icons.description_outlined),
                      if ((_report!['recommendations'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildTextSection(
                            'Rekomendasi',
                            _report!['recommendations'],
                            Icons.tips_and_updates_outlined),
                      ],
                      if ((_report!['photo_urls'] as List?)?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 12),
                        _buildPhotosCard(),
                      ],
                    ],
                  ),
                ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  String get _serviceType => _booking?['service_type'] ?? '';
  bool get _isRepairOrMaintenance =>
      _serviceType == 'repair' || _serviceType == 'maintenance';
  bool get _isMaintenance => _serviceType == 'maintenance';
  bool get _isInspeksi    => _serviceType == 'inspeksi';

  Widget _sectionHeader(String title, IconData icon, Color color) => Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  // ─── CARDS ────────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    final b         = _booking ?? {};
    final r         = _report  ?? {};
    const stLabels  = {
      'repair':      'Repair / Perbaikan',
      'inspeksi':    'Inspeksi',
      'maintenance': 'Pemeliharaan',
    };
    return _card(children: [
      _sectionHeader(
          'Informasi Laporan', Icons.assignment_outlined, AppTheme.primary),
      const SizedBox(height: 10),
      _infoRow('Tanggal',        _formatDate(r['created_at'] as String?)),
      _infoRow('Tipe Servis',    stLabels[_serviceType] ?? _serviceType),
      _infoRow('Peralatan',      b['equipment_name'] ?? '-'),
      _infoRow('Perusahaan',     b['company_name']   ?? '-'),
      _infoRow('Teknisi',        r['technician_name']?? '-'),
      _infoRow('Lokasi',         '${b['site_address'] ?? '-'}, ${b['site_city'] ?? ''}'),
    ]);
  }

  Widget _buildHydraulicCard() {
    final r         = _report!;
    final pBefore   = r['pressure_before_bar'];
    final pAfter    = r['pressure_after_bar'];
    return _card(children: [
      _sectionHeader(
          'Kondisi Hidrolik', Icons.water_drop_outlined, AppTheme.primary),
      const SizedBox(height: 10),
      if (pBefore != null || pAfter != null)
        Row(
          children: [
            Expanded(
              child: _pressureBox(
                label: 'Sebelum',
                value: pBefore != null ? '$pBefore bar' : '-',
                color: AppTheme.danger,
                bg: AppTheme.dangerLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _pressureBox(
                label: 'Sesudah',
                value: pAfter != null ? '$pAfter bar' : '-',
                color: AppTheme.secondary,
                bg: AppTheme.secondaryLight,
              ),
            ),
          ],
        ),
      if (pBefore != null || pAfter != null) const SizedBox(height: 10),
      if (r['oil_condition'] != null)
        _infoRow('Kondisi Oli',      r['oil_condition']),
      if (r['oil_level'] != null)
        _infoRow('Level Oli',        r['oil_level']),
      if (r['leak_location'] != null)
        _infoRow('Lokasi Kebocoran', r['leak_location']),
      if (r['leak_severity'] != null)
        _infoRow('Keparahan',        r['leak_severity']),
    ]);
  }

  Widget _pressureBox(
          {required String label,
          required String value,
          required Color color,
          required Color bg}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: color)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      );

  Widget _buildChecklistCard() {
    final items = (_report!['maintenance_checklist'] as List?) ?? [];
    final statusIcon = <String, IconData>{
      'done':           Icons.check_circle,
      'skip':           Icons.remove_circle_outline,
      'not_applicable': Icons.cancel_outlined,
    };
    final statusColor = <String, Color>{
      'done':           AppTheme.secondary,
      'skip':           AppTheme.warning,
      'not_applicable': AppTheme.textTertiary,
    };
    final statusLabel = <String, String>{
      'done':           'Selesai',
      'skip':           'Dilewati',
      'not_applicable': 'N/A',
    };

    return _card(children: [
      _sectionHeader('Checklist Pemeliharaan',
          Icons.checklist_outlined, AppTheme.warning),
      const SizedBox(height: 10),
      ...items.map((item) {
        final st    = item['status'] as String? ?? '';
        final color = statusColor[st] ?? AppTheme.textTertiary;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(statusIcon[st] ?? Icons.circle_outlined,
                  size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item['item'] ?? '-',
                    style: const TextStyle(fontSize: 12)),
              ),
              Text(statusLabel[st] ?? st,
                  style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        );
      }),
    ]);
  }

  Widget _buildInspectionCard() {
    final items   = (_report!['inspection_items'] as List?) ?? [];
    const condLabel = <String, String>{
      'good':     'Baik',
      'wear':     'Aus',
      'cracked':  'Retak',
      'leaking':  'Bocor',
      'critical': 'Kritis',
    };
    const condColor = <String, Color>{
      'good':     AppTheme.secondary,
      'wear':     AppTheme.warning,
      'cracked':  AppTheme.warning,
      'leaking':  AppTheme.danger,
      'critical': AppTheme.danger,
    };
    const recLabel = <String, String>{
      'no_action':        'Tidak perlu',
      'monitor':          'Pantau',
      'schedule_replace': 'Jadwal ganti',
      'urgent_replace':   'Ganti segera',
    };

    return _card(children: [
      _sectionHeader('Item Inspeksi',
          Icons.search_outlined, AppTheme.primary),
      const SizedBox(height: 10),
      ...items.asMap().entries.map((e) {
        final i    = e.key;
        final item = e.value as Map<String, dynamic>;
        final cond  = item['condition'] as String? ?? '';
        final color = condColor[cond] ?? AppTheme.textTertiary;
        const typeColors = <String, Color>{
          'hose':     AppTheme.primary,
          'cylinder': AppTheme.warning,
          'pump':     AppTheme.secondary,
        };
        final typeColor = typeColors[item['item_type']] ?? AppTheme.textTertiary;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: typeColor, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${i + 1}. ${(item['item_type'] as String? ?? '').toUpperCase()}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: typeColor),
                  ),
                  const SizedBox(width: 8),
                  if ((item['item_code'] ?? '').isNotEmpty)
                    Text(item['item_code'],
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      condLabel[cond] ?? cond,
                      style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              if ((item['location_desc'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item['location_desc'],
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 4),
              Text(
                'Rekomendasi: ${recLabel[item['recommendation']] ?? item['recommendation'] ?? '-'}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
              _buildItemSpecs(item),
            ],
          ),
        );
      }),
    ]);
  }

  String _fmtFitting(Map<String, dynamic>? fm) {
    if (fm == null) return '-';
    final g = (fm['gender'] as String? ?? '').toUpperCase();
    final s = (fm['standard'] as String? ?? '').toUpperCase();
    String a = fm['angle'] as String? ?? '';
    switch (a) {
      case 'straight': a = 'STRAIGHT'; break;
      case '45':       a = '45DEG';    break;
      case '90':       a = '90DEG';    break;
      case '90_long':  a = '90LONG';   break;
      default:         a = a.toUpperCase();
    }
    return '$g $s $a'.trim();
  }

  Widget _specRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _buildItemSpecs(Map<String, dynamic> item) {
    final type  = item['item_type'] as String? ?? '';
    final specs = (item['specifications'] as Map?)?.cast<String, dynamic>() ?? {};
    if (specs.isEmpty) return const SizedBox.shrink();

    List<Widget> rows = [];

    if (type == 'hose') {
      final f1 = _fmtFitting((specs['fitting_end1'] as Map?)?.cast<String, dynamic>());
      final f2 = _fmtFitting((specs['fitting_end2'] as Map?)?.cast<String, dynamic>());
      rows = [
        _specRow('Panjang',    '${specs['length_m'] ?? '-'} m'),
        _specRow('Diameter',   '${specs['diameter_inch'] ?? '-'}"'),
        _specRow('Tekanan',    '${specs['pressure_bar'] ?? '-'} bar'),
        _specRow('Fitting 1',  f1),
        _specRow('Fitting 2',  f2),
      ];
    } else if (type == 'cylinder') {
      const condMap = <String, String>{
        'good': 'Baik', 'wear': 'Aus', 'cracked': 'Retak', 'leaking': 'Bocor',
      };
      final rod  = condMap[specs['rod_condition']]  ?? specs['rod_condition']  ?? '-';
      final seal = condMap[specs['seal_condition']] ?? specs['seal_condition'] ?? '-';
      rows = [
        _specRow('Bore',          '${specs['bore_mm'] ?? '-'} mm'),
        _specRow('Stroke',        '${specs['stroke_mm'] ?? '-'} mm'),
        _specRow('Tekanan',       '${specs['pressure_bar'] ?? '-'} bar'),
        _specRow('Kondisi Rod',   rod),
        _specRow('Kondisi Seal',  seal),
      ];
    } else if (type == 'pump') {
      rows = [
        if ((specs['pump_type'] as String? ?? '').isNotEmpty)
          _specRow('Tipe Pompa', specs['pump_type'] as String),
        _specRow('Flow',    '${specs['flow_lpm'] ?? '-'} lpm'),
        _specRow('Tekanan', '${specs['pressure_bar'] ?? '-'} bar'),
        if ((specs['noise_level'] as String? ?? '').isNotEmpty)
          _specRow('Noise Level', specs['noise_level'] as String),
        if (specs['temperature_c'] != null)
          _specRow('Suhu', '${specs['temperature_c']} °C'),
      ];
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const Divider(height: 1, color: AppTheme.border),
        const SizedBox(height: 6),
        ...rows,
      ],
    );
  }

  Widget _buildTextSection(String title, String content, IconData icon) =>
      _card(children: [
        _sectionHeader(title, icon, AppTheme.primary),
        const SizedBox(height: 8),
        Text(content,
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: AppTheme.textPrimary)),
      ]);

  Widget _buildPhotosCard() {
    final photos = (_report!['photo_urls'] as List?) ?? [];
    const typeLabel = <String, String>{
      'before': 'Sebelum',
      'after':  'Sesudah',
      'damage': 'Kerusakan',
    };
    const typeColor = <String, Color>{
      'before': AppTheme.warning,
      'after':  AppTheme.secondary,
      'damage': AppTheme.danger,
    };

    final urls   = photos.map<String>((p) => p['url'] as String? ?? '').toList();
    final labels = photos.map<String>((p) {
      final type = p['type'] as String? ?? '';
      return typeLabel[type] ?? type;
    }).toList();

    return _card(children: [
      _sectionHeader(
          'Foto Dokumentasi', Icons.photo_library_outlined, AppTheme.primary),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: photos.asMap().entries.map<Widget>((entry) {
            final i     = entry.key;
            final p     = entry.value;
            final url   = p['url'] as String? ?? '';
            final type  = p['type'] as String? ?? '';
            final color = typeColor[type] ?? AppTheme.textTertiary;
            return GestureDetector(
              onTap: () => showPhotoViewer(
                context, urls,
                labels: labels,
                initialIndex: i,
              ),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 110,
                              height: 110,
                              color: AppTheme.background,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppTheme.textTertiary),
                            ),
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : Container(
                                        width: 110,
                                        height: 110,
                                        color: AppTheme.background,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      ),
                          ),
                        ),
                        // ikon zoom di pojok kanan bawah
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_in,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(typeLabel[type] ?? type,
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
      );
}
