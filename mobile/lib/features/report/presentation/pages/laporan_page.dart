import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});

  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  List<dynamic> _reports    = [];
  bool          _loading    = true;
  String        _filterType = ''; // '' = semua
  String        _query      = '';
  final _searchCtrl = TextEditingController();

  // ─── Filtered list (client-side) ─────────────────────────────────────────

  List<dynamic> get _filtered {
    return _reports.where((r) {
      final booking     = r['booking_info'] as Map<String, dynamic>? ?? {};
      final serviceType = (booking['service_type'] ?? '') as String;
      final company     = (booking['company_name'] ?? r['company_name'] ?? '') as String;
      final desc        = (r['work_description'] ?? '') as String;
      final equipment   = (booking['equipment_name'] ?? '') as String;

      final matchType = _filterType.isEmpty || serviceType == _filterType;
      final q = _query.toLowerCase();
      final matchQuery = q.isEmpty ||
          desc.toLowerCase().contains(q) ||
          company.toLowerCase().contains(q) ||
          equipment.toLowerCase().contains(q);

      return matchType && matchQuery;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/reports/my-reports');
      if (mounted) {
        setState(() {
          _reports = res.data['data'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month]}';
    } catch (_) {
      return '-';
    }
  }

  String? _downloadingReportId;

  Future<void> _sharePdf(String url, String reportId) async {
    if (_downloadingReportId != null) return;
    setState(() => _downloadingReportId = reportId);
    try {
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/laporan_$reportId.pdf';
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
      if (mounted) setState(() => _downloadingReportId = null);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari deskripsi, perusahaan, equipment...',
                hintStyle: const TextStyle(
                    fontSize: 13, color: AppTheme.textTertiary),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: AppTheme.textTertiary),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: AppTheme.textTertiary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // ── Filter chips ──────────────────────────────────────────────
          Container(
            color: AppTheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  _filterChip('Semua', ''),
                  _filterChip('Repair', 'repair'),
                  _filterChip('Inspeksi', 'inspeksi'),
                  _filterChip('Maintenance', 'maintenance'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // ── Result count ──────────────────────────────────────────────
          if (!_loading)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} laporan ditemukan',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _query.isNotEmpty || _filterType.isNotEmpty
                                      ? Icons.search_off
                                      : Icons.description_outlined,
                                  size: 48,
                                  color: AppTheme.textTertiary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _query.isNotEmpty || _filterType.isNotEmpty
                                      ? 'Tidak ada laporan yang cocok'
                                      : 'Belum ada laporan',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary),
                                ),
                                if (_query.isNotEmpty ||
                                    _filterType.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {
                                        _query      = '';
                                        _filterType = '';
                                      });
                                    },
                                    child: const Text('Reset filter'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                16, 4, 16, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _reportCard(filtered[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── WIDGETS ──────────────────────────────────────────────────────────────

  Widget _filterChip(String label, String value) {
    final selected = _filterType == value;
    final chipColors = <String, List<Color>>{
      'repair':      [AppTheme.danger, AppTheme.dangerLight],
      'inspeksi':    [AppTheme.primary, AppTheme.primaryLight],
      'maintenance': [AppTheme.warning, AppTheme.warningLight],
    };
    final c = chipColors[value];
    final activeColor = c != null ? c[0] : AppTheme.primary;
    final activeBg    = c != null ? c[1] : AppTheme.primaryLight;

    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeBg : AppTheme.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? activeColor : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? activeColor : AppTheme.textSecondary,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _reportCard(dynamic r) {
    final booking     = r['booking_info'] as Map<String, dynamic>? ?? {};
    final serviceType = booking['service_type'] ?? '';
    final companyName = booking['company_name'] ?? r['company_name'] ?? '-';
    final equipName   = booking['equipment_name'] ?? '';
    final createdAt   = r['created_at'] ?? '';
    final query       = _query.toLowerCase();

    // Highlight matching text helper
    Widget highlighted(String text, {TextStyle? base}) {
      if (query.isEmpty || !text.toLowerCase().contains(query)) {
        return Text(text,
            style: base ??
                const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis);
      }
      final lower = text.toLowerCase();
      final start = lower.indexOf(query);
      final end   = start + query.length;
      return RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: base ??
              const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary),
          children: [
            TextSpan(text: text.substring(0, start)),
            TextSpan(
              text: text.substring(start, end),
              style: const TextStyle(
                  backgroundColor: Color(0xFFFFF176),
                  fontWeight: FontWeight.w700),
            ),
            TextSpan(text: text.substring(end)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        await context.push('/booking/${booking['id'] ?? ''}');
        if (mounted) _loadData();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _serviceTypeBadge(serviceType),
                const Spacer(),
                Text(_formatDate(createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ),
            const SizedBox(height: 8),
            // Equipment di atas
            if (equipName.isNotEmpty) ...[
              highlighted(
                equipName,
                base: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 3),
            ],
            // Deskripsi pekerjaan
            highlighted(
              r['work_description'] ?? '-',
              base: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            // Nama PT paling bawah
            Row(
              children: [
                const Icon(Icons.business_outlined,
                    size: 12, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: highlighted(
                    companyName,
                    base: const TextStyle(
                        fontSize: 11, color: AppTheme.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 13, color: AppTheme.secondary),
                const SizedBox(width: 4),
                const Text('Laporan terkirim',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.secondary)),
                const Spacer(),
                if (r['pdf_url'] != null)
                  _pdfButton(
                      r['pdf_url'] as String,
                      r['id'] as String? ?? ''),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pdfButton(String url, String reportId) {
    final loading = _downloadingReportId == reportId;
    return GestureDetector(
      onTap: loading ? null : () => _sharePdf(url, reportId),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: loading
              ? const [
                  SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppTheme.primary)),
                  SizedBox(width: 4),
                  Text('Mengunduh...',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.primary)),
                ]
              : const [
                  Icon(Icons.share_outlined,
                      size: 12, color: AppTheme.primary),
                  SizedBox(width: 4),
                  Text('Bagikan PDF',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500)),
                ],
        ),
      ),
    );
  }

  Widget _serviceTypeBadge(String type) {
    final colors = <String, List<Color>>{
      'repair':      [AppTheme.danger, AppTheme.dangerLight],
      'inspeksi':    [AppTheme.primary, AppTheme.primaryLight],
      'maintenance': [AppTheme.warning, AppTheme.warningLight],
    };
    final c      = colors[type] ?? [AppTheme.textTertiary, AppTheme.surface];
    final labels = {
      'repair':      'Repair',
      'inspeksi':    'Inspeksi',
      'maintenance': 'Maintenance',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c[1],
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(labels[type] ?? type,
          style: TextStyle(
              fontSize: 10,
              color: c[0],
              fontWeight: FontWeight.w500)),
    );
  }
}
