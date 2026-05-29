import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class BookingListPage extends StatefulWidget {
  const BookingListPage({super.key});

  @override
  State<BookingListPage> createState() => _BookingListPageState();
}

class _BookingListPageState extends State<BookingListPage> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _bookings = [];
  bool _loading = true;
  String _role = '';
  String _name = '';
  String _companyId = '';
  String _companyName = '';
  String _selectedStatus = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _role = await _storage.read(key: AppConstants.userRoleKey) ?? '';
    _name = await _storage.read(key: AppConstants.userNameKey) ?? '';
    _companyId = await _storage.read(key: AppConstants.companyIdKey) ?? '';
    _companyName = await _storage.read(key: AppConstants.companyNameKey) ?? '';
    try {
      final params = <String, String>{};
      if (_selectedStatus.isNotEmpty) params['status'] = _selectedStatus;
      if (_companyId.isNotEmpty &&
          (_role == AppConstants.roleClient || _role == AppConstants.roleSales)) {
        params['company_id'] = _companyId;
      }
      final query = params.isEmpty
          ? ''
          : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
      final res = await ApiClient.instance.get('/bookings$query');
      setState(() {
        _bookings = res.data['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open': return AppTheme.primary;
      case 'in_progress':
      case 'on_the_way':
      case 'on_site': return AppTheme.warning;
      case 'done': return AppTheme.secondary;
      case 'cancelled': return AppTheme.textTertiary;
      default: return AppTheme.textTertiary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open': return 'Open';
      case 'in_progress': return 'In Progress';
      case 'on_the_way': return 'On The Way';
      case 'on_site': return 'On Site';
      case 'done': return 'Selesai';
      case 'cancelled': return 'Dibatalkan';
      default: return status;
    }
  }

  int get _navIndex {
    switch (_role) {
      case AppConstants.roleManager: return 1;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            if (_companyName.isNotEmpty)
              Text(_companyName,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          if (_role == AppConstants.roleClient ||
              _role == AppConstants.roleSales)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/booking/create'),
            ),
        ],
      ),
      bottomNavigationBar: BottomNav(currentIndex: _navIndex),
      body: Column(
        children: [
          // Filter status
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _filterChip('Semua', ''),
                _filterChip('Open', 'open'),
                _filterChip('In Progress', 'in_progress'),
                _filterChip('On The Way', 'on_the_way'),
                _filterChip('On Site', 'on_site'),
                _filterChip('Selesai', 'done'),
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
                            child: Text('Belum ada booking',
                                style: TextStyle(
                                    color: AppTheme.textSecondary)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _bookings.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final b = _bookings[i];
                              final status = b['status'] ?? '';
                              final statusColor = _statusColor(status);
                              final isEmergency =
                                  b['urgency_level'] == 'emergency';
                              return GestureDetector(
                                onTap: () async {
                                  await context.push('/booking/${b['id']}');
                                  if (mounted) _loadData();
                                },
                                child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isEmergency
                                        ? AppTheme.danger
                                        : AppTheme.border,
                                    width: isEmergency ? 1.5 : 0.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            _statusLabel(status),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            if (isEmergency)
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 6,
                                                    vertical: 3),
                                                decoration: BoxDecoration(
                                                  color:
                                                      AppTheme.dangerLight,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          99),
                                                ),
                                                child: const Text(
                                                  'EMERGENCY',
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color:
                                                          AppTheme.danger,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ),
                                            const SizedBox(width: 6),
                                            Text(
                                              b['service_type'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppTheme.textTertiary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      b['company_name'] ?? '-',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      b['equipment_name'] ?? '-',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                            Icons.location_on_outlined,
                                            size: 14,
                                            color: AppTheme.textTertiary),
                                        const SizedBox(width: 4),
                                        Text(
                                          b['site_city'] ?? '-',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textTertiary),
                                        ),
                                        if (b['technician_name'] != null &&
                                            b['technician_name'] != '') ...[
                                          const SizedBox(width: 12),
                                          const Icon(
                                              Icons.person_outline,
                                              size: 14,
                                              color: AppTheme.textTertiary),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              b['technician_name'],
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppTheme.textTertiary),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ));
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton:
          (_role == AppConstants.roleClient ||
                  _role == AppConstants.roleSales)
              ? FloatingActionButton(
                  onPressed: () => context.go('/booking/create'),
                  backgroundColor: AppTheme.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = value;
          _loading = true;
        });
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}