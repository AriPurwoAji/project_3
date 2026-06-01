import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _storage = const FlutterSecureStorage();
  String _name        = '';
  int    _unreadCount = 0;
  Map<String, dynamic>? _summary;
  List<dynamic> _techPerformance = [];
  List<dynamic> _serviceTrend = [];
  bool _loading = true;

  // Filter tanggal
  DateTime? _filterFrom;
  DateTime? _filterTo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _name = await _storage.read(key: AppConstants.userNameKey) ?? '';
    final params = <String, dynamic>{};
    if (_filterFrom != null) {
      params['from'] = _filterFrom!.toIso8601String();
    }
    if (_filterTo != null) {
      params['to'] = _filterTo!
          .add(const Duration(days: 1))
          .toIso8601String(); // inklusif hari terakhir
    }

    try {
      final results = await Future.wait([
        ApiClient.instance.get('/dashboard/summary',
            queryParameters: params),
        ApiClient.instance.get('/dashboard/technician-performance'),
        ApiClient.instance.get('/dashboard/service-trend',
            queryParameters: params),
        ApiClient.instance.get('/notifications/unread-count'),
      ]);
      setState(() {
        _summary         = results[0].data['data'];
        _techPerformance = results[1].data['data'] ?? [];
        _serviceTrend    = results[2].data['data'] ?? [];
        _unreadCount     = (results[3].data['data']['unread_count'] as num?)
                              ?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_filterFrom ?? now.subtract(const Duration(days: 30)))
          : (_filterTo ?? now),
      firstDate: DateTime(2024),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _filterFrom = picked;
        if (_filterTo != null && _filterTo!.isBefore(picked)) {
          _filterTo = picked;
        }
      } else {
        _filterTo = picked;
        if (_filterFrom != null && _filterFrom!.isAfter(picked)) {
          _filterFrom = picked;
        }
      }
      _loading = true;
    });
    _loadData();
  }

  void _clearFilter() {
    setState(() {
      _filterFrom = null;
      _filterTo   = null;
      _loading    = true;
    });
    _loadData();
  }

  String _fmtDate(DateTime dt) {
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${m[dt.month]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Badge(
            label: Text('$_unreadCount'),
            isLabelVisible: _unreadCount > 0,
            child: IconButton(
              icon: Icon(_unreadCount > 0
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_outlined),
              color: _unreadCount > 0
                  ? AppTheme.primary
                  : null,
              onPressed: () async {
                await context.push('/notifications');
                if (mounted) _loadData();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selamat datang,',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    Text(_name,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 16),

                    // ── Filter tanggal ────────────────────────────────────
                    Row(
                      children: [
                        _dateChip(
                          label: _filterFrom != null
                              ? 'Dari: ${_fmtDate(_filterFrom!)}'
                              : 'Dari',
                          onTap: () => _pickDate(isFrom: true),
                          active: _filterFrom != null,
                        ),
                        const SizedBox(width: 8),
                        _dateChip(
                          label: _filterTo != null
                              ? 'Sampai: ${_fmtDate(_filterTo!)}'
                              : 'Sampai',
                          onTap: () => _pickDate(isFrom: false),
                          active: _filterTo != null,
                        ),
                        if (_filterFrom != null || _filterTo != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _clearFilter,
                            child: const Icon(Icons.close,
                                size: 18, color: AppTheme.textTertiary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_summary != null) ...[
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _statCard('Total Booking',
                              '${_summary!['total_bookings']}',
                              AppTheme.primary, AppTheme.primaryLight),
                          _statCard('Selesai',
                              '${_summary!['completed_bookings']}',
                              AppTheme.secondary, AppTheme.secondaryLight),
                          _statCard('Open',
                              '${_summary!['open_bookings']}',
                              AppTheme.warning, AppTheme.warningLight),
                          _statCard('Rata-rata waktu',
                              '${(_summary!['avg_completion_hours'] as num).toStringAsFixed(1)} jam',
                              AppTheme.danger, AppTheme.dangerLight),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Technician Performance
                      if (_techPerformance.isNotEmpty) ...[
                        const Text('Performa Teknisi',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        ..._techPerformance.map((t) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.border, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppTheme.primaryLight,
                                child: Text(
                                  (t['technician_name'] as String)
                                      .substring(0, 1),
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(t['technician_name'],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                        '${t['completed_jobs']} job selesai',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 20),
                      ],

                      // Service Trend
                      if (_serviceTrend.isNotEmpty) ...[
                        const Text('Tren Layanan',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 10),
                        ..._serviceTrend.map((s) {
                          final total = s['total'] as int;
                          final maxTotal = (_serviceTrend
                              .map((x) => x['total'] as int)
                              .reduce((a, b) => a > b ? a : b));
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(s['service_type'],
                                        style: const TextStyle(
                                            fontSize: 12)),
                                    Text('$total job',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: maxTotal > 0
                                      ? total / maxTotal
                                      : 0,
                                  backgroundColor: AppTheme.border,
                                  color: AppTheme.primary,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _dateChip({
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 13,
                color: active ? AppTheme.primary : AppTheme.textTertiary),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight:
                        active ? FontWeight.w500 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      String label, String value, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: color)),
        ],
      ),
    );
  }
}