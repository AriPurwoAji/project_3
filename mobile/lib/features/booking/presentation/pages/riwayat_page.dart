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
  final _storage    = const FlutterSecureStorage();
  final _searchCtrl = TextEditingController();
  List<dynamic> _bookings   = [];
  bool   _loading    = true;
  String _filterType = '';
  String _query      = '';

  List<dynamic> get _filtered {
    if (_query.isEmpty) return _bookings;
    final q = _query.toLowerCase();
    return _bookings.where((b) =>
        (b['description']     ?? '').toLowerCase().contains(q) ||
        (b['equipment_name']  ?? '').toLowerCase().contains(q) ||
        (b['technician_name'] ?? '').toLowerCase().contains(q) ||
        (b['site_city']       ?? '').toLowerCase().contains(q) ||
        (b['site_address']    ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
          // Search bar
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari deskripsi, equipment, teknisi, kota...',
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
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                _chip('Semua', ''),
                _chip('Repair', 'repair'),
                _chip('Inspeksi', 'inspeksi'),
                _chip('Maintenance', 'maintenance'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _filtered.isEmpty
                        ? Center(
                            child: Text(
                              _query.isNotEmpty
                                  ? 'Tidak ada riwayat yang cocok'
                                  : 'Belum ada riwayat',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _riwayatCard(_filtered[i]),
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
    final urgency     = b['urgency_level'] ?? 'standard';
    final isEmergency = urgency == 'emergency';
    final companyName = b['company_name'] ?? '-';
    final equipName   = b['equipment_name'] ?? '';
    final techName    = b['technician_name'] ?? '-';
    final siteCity    = b['site_city'] ?? '';
    final siteAddress = b['site_address'] ?? '';
    final desc        = b['description'] ?? '-';

    const serviceColors = <String, List<Color>>{
      'repair':      [AppTheme.danger,   AppTheme.dangerLight],
      'inspeksi':    [AppTheme.primary,  AppTheme.primaryLight],
      'maintenance': [AppTheme.warning,  AppTheme.warningLight],
    };
    final sc = serviceColors[serviceType] ??
        [AppTheme.textTertiary, AppTheme.surface];
    const serviceLabels = {
      'repair': 'Repair', 'inspeksi': 'Inspeksi', 'maintenance': 'Maintenance'
    };

    return GestureDetector(
      onTap: () => context.push('/booking/${b['id']}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEmergency ? AppTheme.danger : AppTheme.border,
            width: isEmergency ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris 1: urgency + service type badge + tanggal
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isEmergency
                        ? AppTheme.dangerLight
                        : AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    isEmergency ? 'EMERGENCY' : 'STANDARD',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isEmergency
                            ? AppTheme.danger
                            : AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: sc[1],
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    serviceLabels[serviceType] ?? serviceType,
                    style: TextStyle(fontSize: 9, color: sc[0]),
                  ),
                ),
                const Spacer(),
                Text(_formatDate(b['completed_at'] ?? b['updated_at'] ?? ''),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textTertiary)),
              ],
            ),
            const SizedBox(height: 8),
            // Baris 2: deskripsi — nama PT
            Text(
              '$desc  —  $companyName',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Baris 3: equipment
            if (equipName.isNotEmpty)
              Text(equipName,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            // Baris 4: teknisi + lokasi
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 13, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(techName,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ),
                if (siteCity.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppTheme.textTertiary),
                  const SizedBox(width: 3),
                  Text(
                    [siteAddress, siteCity]
                        .where((s) => s.isNotEmpty)
                        .join(', '),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textTertiary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
