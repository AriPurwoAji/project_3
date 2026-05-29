import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _bookings    = [];
  bool          _loading     = true;
  String        _filterType  = ''; // '' = semua

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final companyId = await _storage.read(key: AppConstants.companyIdKey) ?? '';
    setState(() => _loading = true);
    try {
      final params = <String, String>{'status': 'done'};
      if (companyId.isNotEmpty) params['company_id'] = companyId;
      if (_filterType.isNotEmpty) params['service_type'] = _filterType;

      final query = '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      final res   = await ApiClient.instance.get('/bookings$query');
      if (mounted) {
        setState(() {
          _bookings = res.data['data'] ?? [];
          _loading  = false;
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
      appBar: AppBar(title: const Text('Riwayat Layanan')),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _chip('Semua', ''),
                _chip('Repair', 'repair'),
                _chip('Inspeksi', 'inspeksi'),
                _chip('Maintenance', 'maintenance'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _bookings.isEmpty
                        ? const Center(
                            child: Text('Belum ada riwayat',
                                style: TextStyle(
                                    color: AppTheme.textSecondary)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _bookings.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _riwayatCard(_bookings[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filterType == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filterType = value);
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontWeight:
                  selected ? FontWeight.w500 : FontWeight.normal,
            )),
      ),
    );
  }

  Widget _riwayatCard(dynamic b) {
    final serviceType = b['service_type'] ?? '';
    final hasPressure = b['pressure_before_bar'] != null ||
        b['pressure_after_bar'] != null;

    return GestureDetector(
      onTap: () => context.push('/booking/${b['id']}'),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text('Selesai',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.w500)),
                ),
                const Spacer(),
                Text(_formatDate(b['updated_at'] ?? ''),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${b['description'] ?? '-'} · ${_serviceTypeLabel(serviceType)}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 13, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(b['technician_name'] ?? '-',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary)),
              ],
            ),
            if (hasPressure) ...[
              const SizedBox(height: 8),
              _tag(
                '${b['pressure_before_bar'] ?? '?'} → ${b['pressure_after_bar'] ?? '?'} bar',
                AppTheme.primary,
                AppTheme.primaryLight,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500)),
      );

  String _serviceTypeLabel(String s) {
    switch (s) {
      case 'repair':      return 'Repair';
      case 'inspeksi':    return 'Inspeksi';
      case 'maintenance': return 'Maintenance';
      default:            return s;
    }
  }
}
