import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();

  String _name        = '';
  String _email       = '';
  String _role        = '';
  String _companyName = '';

  // Client/sales
  List<dynamic> _equipment = [];

  // Teknisi
  int    _totalJobs  = 0;
  int    _monthJobs  = 0;
  List<dynamic> _recentJobs = [];

  bool _loading = true;

  bool get _isClient  => _role == AppConstants.roleClient || _role == AppConstants.roleSales;
  bool get _isTeknisi => _role == AppConstants.roleTeknisi;

  int get _navIndex {
    switch (_role) {
      case AppConstants.roleManager: return 3;
      case AppConstants.roleTeknisi: return 3;
      default:                       return 3;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _name        = await _storage.read(key: AppConstants.userNameKey)    ?? '';
    _email       = await _storage.read(key: AppConstants.userIDKey)      ?? '';
    _role        = await _storage.read(key: AppConstants.userRoleKey)    ?? '';
    _companyName = await _storage.read(key: AppConstants.companyNameKey) ?? '';
    final companyId = await _storage.read(key: AppConstants.companyIdKey) ?? '';

    // Fetch email from /auth/me
    try {
      final me = await ApiClient.instance.get('/auth/me');
      _email = me.data['data']?['email'] ?? '';
    } catch (_) {}

    if (_isClient && companyId.isNotEmpty) {
      try {
        final res = await ApiClient.instance
            .get('/equipment?company_id=$companyId');
        _equipment = res.data['data'] ?? [];
      } catch (_) {}
    }

    if (_isTeknisi) {
      try {
        final res = await ApiClient.instance.get('/my-jobs');
        final jobs = List<dynamic>.from(res.data['data'] ?? []);
        _totalJobs = jobs.length;
        final now   = DateTime.now();
        _monthJobs  = jobs.where((j) {
          try {
            final d = DateTime.parse(j['updated_at'] ?? '');
            return d.year == now.year && d.month == now.month &&
                j['status'] == 'done';
          } catch (_) {
            return false;
          }
        }).length;
        _recentJobs = jobs
            .where((j) => j['status'] == 'done')
            .take(3)
            .toList();
      } catch (_) {}
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    await ApiClient.clearToken();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isTeknisi ? 'Profil Teknisi' : 'Profil'),
      ),
      bottomNavigationBar: BottomNav(currentIndex: _navIndex),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAvatarSection(),
                  const SizedBox(height: 20),
                  if (_isTeknisi) ...[
                    _buildTeknisiStats(),
                    const SizedBox(height: 16),
                    _buildRecentJobs(),
                  ] else if (_isClient) ...[
                    _buildCompanyInfo(),
                    const SizedBox(height: 16),
                    _buildEquipmentSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildLogoutButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ─── AVATAR ───────────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : '?';
    final roleBadge = _isTeknisi ? 'Teknisi' : _isClient ? 'Client PIC' : _role;

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppTheme.primaryLight,
          child: Text(initial,
              style: const TextStyle(
                  fontSize: 32,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        Text(_name,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w600)),
        if (_email.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(_email,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(roleBadge,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.primary)),
        ),
      ],
    );
  }

  // ─── TEKNISI: STATS ───────────────────────────────────────────────────────

  Widget _buildTeknisiStats() {
    return Row(
      children: [
        _statCard('$_monthJobs', 'Job bulan ini'),
        const SizedBox(width: 10),
        _statCard('$_totalJobs', 'Total job'),
        const SizedBox(width: 10),
        _statCard('-', 'Rating'),
      ],
    );
  }

  Widget _statCard(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  // ─── TEKNISI: RECENT JOBS ─────────────────────────────────────────────────

  Widget _buildRecentJobs() {
    if (_recentJobs.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Riwayat job terbaru',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._recentJobs.map((j) => _recentJobRow(j)),
        ],
      ),
    );
  }

  Widget _recentJobRow(dynamic j) {
    final desc = j['description'] ?? '-';
    final company = j['company_name'] ?? '';
    final type = j['service_type'] ?? '';
    final date = _formatDate(j['updated_at'] ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$desc — $company',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('$date · ${_capitalize(type)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        ],
      ),
    );
  }

  // ─── CLIENT: COMPANY INFO ─────────────────────────────────────────────────

  Widget _buildCompanyInfo() {
    if (_companyName.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Info perusahaan',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _infoRow('Perusahaan', _companyName),
        ],
      ),
    );
  }

  // ─── CLIENT: EQUIPMENT ────────────────────────────────────────────────────

  Widget _buildEquipmentSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Equipment perusahaan',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () => context.go('/booking/create'),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Icon(Icons.add,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_equipment.isEmpty)
            const Text('Belum ada equipment',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary))
          else
            ..._equipment.map(_equipmentRow),
        ],
      ),
    );
  }

  Widget _equipmentRow(dynamic e) {
    final name   = e['name'] ?? '-';
    final brand  = e['brand'] ?? '';
    final serial = e['serial_number'] ?? '';
    final pressure = e['max_pressure_bar'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text(
                  [
                    if (brand.isNotEmpty) brand,
                    if (pressure != null) '$pressure bar',
                    if (serial.isNotEmpty) serial,
                  ].join(' · '),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text('Aktif',
                style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ─── LOGOUT ───────────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: const Row(
        children: [
          Icon(Icons.logout, color: AppTheme.danger, size: 18),
          SizedBox(width: 8),
          Text('Logout',
              style: TextStyle(
                  color: AppTheme.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 100,
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

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
