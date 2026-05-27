import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      onTap: () => context.push('/booking/${booking['id'] ?? ''}'),
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
                if (r['pdf_url'] != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.picture_as_pdf_outlined,
                      size: 13, color: AppTheme.primary),
                  const SizedBox(width: 4),
                  const Text('PDF tersedia',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.primary)),
                ],
              ],
            ),
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
