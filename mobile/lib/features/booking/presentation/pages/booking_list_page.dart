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
  final _storage    = const FlutterSecureStorage();
  final _scrollCtrl = ScrollController();

  List<dynamic> _bookings = [];
  bool   _loading     = true;
  bool   _loadingMore = false;
  bool   _hasMore     = true;
  int    _offset      = 0;
  static const _limit = 20;

  String _role        = '';
  String _name        = '';
  String _companyId   = '';
  String _companyName = '';
  String _selectedStatus = '';
  String _query          = '';
  final _searchCtrl = TextEditingController();

  List<dynamic> get _filtered {
    return _bookings.where((b) {
      final q = _query.toLowerCase();
      final matchQ = q.isEmpty ||
          (b['description']      ?? '').toLowerCase().contains(q) ||
          (b['company_name']     ?? '').toLowerCase().contains(q) ||
          (b['equipment_name']   ?? '').toLowerCase().contains(q) ||
          (b['technician_name']  ?? '').toLowerCase().contains(q) ||
          (b['created_by_name']  ?? '').toLowerCase().contains(q) ||
          (b['site_address']     ?? '').toLowerCase().contains(q) ||
          (b['site_city']        ?? '').toLowerCase().contains(q);
      return matchQ;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    _role        = await _storage.read(key: AppConstants.userRoleKey)    ?? '';
    _name        = await _storage.read(key: AppConstants.userNameKey)    ?? '';
    _companyId   = await _storage.read(key: AppConstants.companyIdKey)   ?? '';
    _companyName = await _storage.read(key: AppConstants.companyNameKey) ?? '';

    setState(() {
      _loading = true;
      _offset  = 0;
      _hasMore = true;
      _bookings = [];
    });

    try {
      final params = _buildParams(offset: 0);
      final res = await ApiClient.instance.get('/bookings?$params');
      final data = List<dynamic>.from(res.data['data'] ?? []);
      if (mounted) {
        setState(() {
          _bookings = data;
          _hasMore  = data.length == _limit;
          _offset   = data.length;
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final params = _buildParams(offset: _offset);
      final res  = await ApiClient.instance.get('/bookings?$params');
      final data = List<dynamic>.from(res.data['data'] ?? []);
      if (mounted) {
        setState(() {
          _bookings.addAll(data);
          _hasMore      = data.length == _limit;
          _offset      += data.length;
          _loadingMore  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  String _buildParams({required int offset}) {
    final params = <String, String>{
      'limit':  '$_limit',
      'offset': '$offset',
    };
    if (_selectedStatus.isNotEmpty) params['status'] = _selectedStatus;
    if (_companyId.isNotEmpty &&
        (_role == AppConstants.roleClient ||
            _role == AppConstants.roleSales)) {
      params['company_id'] = _companyId;
    }
    return params.entries.map((e) => '${e.key}=${e.value}').join('&');
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
      case AppConstants.roleTeknisi: return 0;
      default: return 1; // manager(1), client(1), sales(1)
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
            Text(
              _role == AppConstants.roleSales
                  ? 'Sales · Semua booking perusahaan'
                  : _companyName.isNotEmpty
                      ? _companyName
                      : '',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: const [],
      ),
      bottomNavigationBar: BottomNav(currentIndex: _navIndex),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari booking...',
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
          // Filter status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _query.isNotEmpty
                                      ? Icons.search_off
                                      : Icons.list_alt_outlined,
                                  size: 48,
                                  color: AppTheme.textTertiary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _query.isNotEmpty
                                      ? 'Tidak ada booking yang cocok'
                                      : 'Belum ada booking',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(
                                16, 8, 16, 24),
                            itemCount: _filtered.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              if (i == _filtered.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }
                              final b = _filtered[i];
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
                                    // Sales: tampilkan siapa yang buat booking
                                    if (_role == AppConstants.roleSales &&
                                        (b['created_by_name'] ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.badge_outlined,
                                              size: 13,
                                              color: AppTheme.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Dibuat oleh: ${b['created_by_name']}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ],
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