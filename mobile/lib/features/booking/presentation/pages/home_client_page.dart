import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class HomeClientPage extends StatefulWidget {
  const HomeClientPage({super.key});

  @override
  State<HomeClientPage> createState() => _HomeClientPageState();
}

class _HomeClientPageState extends State<HomeClientPage> {
  final _storage = const FlutterSecureStorage();

  String _name        = '';
  String _companyName = '';
  bool   _loading     = true;
  int    _unreadCount = 0;

  Map<String, dynamic>? _activeBooking;
  List<dynamic>         _recentDone = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _name        = await _storage.read(key: AppConstants.userNameKey)    ?? '';
    _companyName = await _storage.read(key: AppConstants.companyNameKey) ?? '';
    final companyId = await _storage.read(key: AppConstants.companyIdKey) ?? '';

    try {
      final countRes = await ApiClient.instance
          .get('/notifications/unread-count');
      if (mounted) {
        setState(() {
          _unreadCount =
              (countRes.data['data']['unread_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (_) {}

    try {
      final query = companyId.isNotEmpty ? '?company_id=$companyId' : '';
      final res   = await ApiClient.instance.get('/bookings$query');
      final all   = List<dynamic>.from(res.data['data'] ?? []);

      const activeStatuses = {'in_progress', 'on_the_way', 'on_site'};
      final active = all
          .where((b) => activeStatuses.contains(b['status'] ?? ''))
          .toList();

      final activeId = active.isNotEmpty ? active.first['id'] : null;
      final recent = all.where((b) => b['id'] != activeId).toList();
      recent.sort((a, b) =>
          (b['updated_at'] ?? '').compareTo(a['updated_at'] ?? ''));

      if (mounted) {
        setState(() {
          _activeBooking = active.isNotEmpty
              ? Map<String, dynamic>.from(active.first)
              : null;
          _recentDone = recent.take(3).toList();
          _loading    = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi,';
    if (h < 15) return 'Selamat siang,';
    if (h < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'in_progress':
      case 'on_the_way':  return AppTheme.warning;
      case 'on_site':     return AppTheme.primary;
      case 'done':        return AppTheme.secondary;
      default:            return AppTheme.textTertiary;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'open':        return 'Open';
      case 'in_progress': return 'In Progress';
      case 'on_the_way':  return 'On The Way';
      case 'on_site':     return 'On Site';
      case 'done':        return 'Selesai';
      case 'cancelled':   return 'Dibatalkan';
      default:            return s;
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
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    if (_activeBooking != null) ...[
                      _buildActiveCard(_activeBooking!),
                      const SizedBox(height: 20),
                    ],
                    _buildQuickBooking(),
                    const SizedBox(height: 24),
                    _buildRecentHistory(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(),
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
              Text(_name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              if (_companyName.isNotEmpty)
                Text(_companyName,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        Badge(
          label: Text('$_unreadCount'),
          isLabelVisible: _unreadCount > 0,
          child: IconButton(
            onPressed: () async {
              await context.push('/notifications');
              if (mounted) _loadData();
            },
            icon: Icon(
              _unreadCount > 0
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_outlined,
            ),
            color: _unreadCount > 0
                ? AppTheme.primary
                : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─── ACTIVE BOOKING CARD ──────────────────────────────────────────────────

  Widget _buildActiveCard(Map<String, dynamic> b) {
    final status      = b['status'] ?? '';
    final isEmergency = b['urgency_level'] == 'emergency';

    return GestureDetector(
      onTap: () async {
        await context.push('/booking/${b['id']}');
        if (mounted) _loadData();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEmergency ? AppTheme.dangerLight : AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEmergency
                ? AppTheme.danger.withValues(alpha: 0.3)
                : AppTheme.primary.withValues(alpha: 0.3),
          ),
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
                    color: isEmergency
                        ? AppTheme.danger.withValues(alpha: 0.12)
                        : AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(_statusLabel(status),
                      style: TextStyle(
                          fontSize: 11,
                          color: isEmergency
                              ? AppTheme.danger
                              : AppTheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios,
                    size: 12,
                    color: isEmergency
                        ? AppTheme.danger
                        : AppTheme.primary),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              b['description'] ?? '-',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isEmergency
                      ? AppTheme.danger
                      : AppTheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if ((b['technician_name'] ?? '').isNotEmpty) ...[
                  const Icon(Icons.person_outline,
                      size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(b['technician_name'],
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary)),
                  const SizedBox(width: 6),
                  const Text('·',
                      style: TextStyle(color: AppTheme.textTertiary)),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(b['site_city'] ?? '-',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── QUICK BOOKING ────────────────────────────────────────────────────────

  Widget _buildQuickBooking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Buat booking',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _quickCard(
              icon: Icons.warning_amber_rounded,
              label: 'Emergency',
              sublabel: 'Respon < 4 jam',
              color: AppTheme.danger,
              bg: AppTheme.dangerLight,
              urgency: 'emergency',
            )),
            const SizedBox(width: 12),
            Expanded(child: _quickCard(
              icon: Icons.build_outlined,
              label: 'Standard',
              sublabel: 'Terjadwal',
              color: AppTheme.primary,
              bg: AppTheme.primaryLight,
              urgency: 'standard',
            )),
          ],
        ),
      ],
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required Color bg,
    required String urgency,
  }) {
    return GestureDetector(
      onTap: () => context.go('/booking/create'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color)),
            Text(sublabel,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ─── RECENT HISTORY ───────────────────────────────────────────────────────

  Widget _buildRecentHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Riwayat terbaru',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            GestureDetector(
              onTap: () => context.go('/riwayat'),
              child: const Text('Lihat semua',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_recentDone.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('Belum ada riwayat selesai',
                  style: TextStyle(color: AppTheme.textSecondary,
                      fontSize: 13)),
            ),
          )
        else
          ..._recentDone.map(_recentCard),
      ],
    );
  }

  Widget _recentCard(dynamic b) {
    final status      = b['status'] ?? '';
    final statusColor = _statusColor(status);
    final serviceType = b['service_type'] ?? '';
    const serviceLabel = {
      'repair':      'Repair',
      'inspeksi':    'Inspeksi',
      'maintenance': 'Maintenance',
    };

    return GestureDetector(
      onTap: () async {
        await context.push('/booking/${b['id']}');
        if (mounted) _loadData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b['description'] ?? '-',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if ((b['equipment_name'] ?? '').isNotEmpty)
                        b['equipment_name'],
                      if ((b['technician_name'] ?? '').isNotEmpty)
                        b['technician_name'],
                    ].join('  ·  '),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatDate(b['updated_at'] ?? ''),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textTertiary),
                      ),
                      if (serviceLabel[serviceType] != null) ...[
                        const Text('  ·  ',
                            style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 11)),
                        Text(serviceLabel[serviceType]!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textTertiary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
