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
  List<dynamic> _reports = [];
  bool          _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Saya')),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _reports.isEmpty
                  ? const Center(
                      child: Text('Belum ada laporan',
                          style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _reportCard(_reports[i]),
                    ),
            ),
    );
  }

  Widget _reportCard(dynamic r) {
    final booking    = r['booking_info'] as Map<String, dynamic>? ?? {};
    final serviceType = booking['service_type'] ?? '';
    final companyName = booking['company_name'] ?? r['company_name'] ?? '-';
    final createdAt   = r['created_at'] ?? '';

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
            Text(
              r['work_description'] ?? '-',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(companyName,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
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
                  _pdfButton(r['pdf_url'] as String, r['id'] as String? ?? ''),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          strokeWidth: 1.5, color: AppTheme.primary)),
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
    final c = colors[type] ?? [AppTheme.textTertiary, AppTheme.surface];
    final labels = {
      'repair': 'Repair',
      'inspeksi': 'Inspeksi',
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
