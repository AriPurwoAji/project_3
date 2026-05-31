import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class JobBoardPage extends StatefulWidget {
  const JobBoardPage({super.key});

  @override
  State<JobBoardPage> createState() => _JobBoardPageState();
}

class _JobBoardPageState extends State<JobBoardPage>
    with SingleTickerProviderStateMixin {
  final _storage    = const FlutterSecureStorage();
  final _searchCtrl = TextEditingController();

  List<dynamic> _openJobs   = [];
  List<dynamic> _activeJobs = []; // in_progress / on_the_way / on_site
  bool   _loading      = true;
  int    _unreadCount  = 0;

  // Paginasi hanya untuk open jobs
  bool   _loadingMore  = false;
  bool   _hasMore      = true;
  int    _openOffset   = 0;
  static const _limit  = 20;
  final  _openScrollCtrl = ScrollController();

  String _name  = '';
  String _query = '';
  late TabController _tabController;

  List<dynamic> _applyFilter(List<dynamic> jobs) {
    if (_query.isEmpty) return jobs;
    final q = _query.toLowerCase();
    return jobs.where((j) =>
        (j['description']    ?? '').toLowerCase().contains(q) ||
        (j['company_name']   ?? '').toLowerCase().contains(q) ||
        (j['equipment_name'] ?? '').toLowerCase().contains(q) ||
        (j['site_city']      ?? '').toLowerCase().contains(q) ||
        (j['site_address']   ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _openScrollCtrl.addListener(_onOpenScroll);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _openScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onOpenScroll() {
    if (_openScrollCtrl.position.pixels >=
            _openScrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMoreOpen();
    }
  }

  Future<void> _loadData() async {
    _name = await _storage.read(key: AppConstants.userNameKey) ?? '';
    setState(() {
      _loading    = true;
      _openOffset = 0;
      _hasMore    = true;
      _openJobs   = [];
    });
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/job-board?limit=$_limit&offset=0'),
        ApiClient.instance.get('/my-jobs'),
        ApiClient.instance.get('/notifications/unread-count'),
      ]);
      if (mounted) {
        final open = List<dynamic>.from(results[0].data['data'] ?? []);
        final all  = List<dynamic>.from(results[1].data['data'] ?? []);
        setState(() {
          _openJobs   = open;
          _hasMore    = open.length == _limit;
          _openOffset = open.length;
          _activeJobs = all.where((j) => j['status'] != 'done').toList();
          _unreadCount = (results[2].data['data']['unread_count'] as num?)
                            ?.toInt() ?? 0;
          _loading    = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreOpen() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final res  = await ApiClient.instance
          .get('/job-board?limit=$_limit&offset=$_openOffset');
      final data = List<dynamic>.from(res.data['data'] ?? []);
      if (mounted) {
        setState(() {
          _openJobs.addAll(data);
          _hasMore     = data.length == _limit;
          _openOffset += data.length;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _claimJob(String bookingID) async {
    try {
      await ApiClient.instance.post('/bookings/$bookingID/claim');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Job berhasil diambil!'),
        backgroundColor: AppTheme.secondary,
      ));
      _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal mengambil job'),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  Future<void> _updateStatus(dynamic job) async {
    final status = job['status'] ?? '';
    if (status == 'on_site') {
      await context.push('/report/create',
          extra: Map<String, dynamic>.from(job));
      if (mounted) _loadData();
      return;
    }
    final nextStatus = status == 'in_progress' ? 'on_the_way' : 'on_site';
    try {
      await ApiClient.instance.patch(
        '/bookings/${job['id']}/status',
        data: {'status': nextStatus},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Status diupdate ke $nextStatus'),
        backgroundColor: AppTheme.secondary,
      ));
      _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal update status'),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi,';
    if (h < 15) return 'Selamat siang,';
    if (h < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  Color _urgencyColor(String u) =>
      u == 'emergency' ? AppTheme.danger : AppTheme.primary;
  Color _urgencyBg(String u) =>
      u == 'emergency' ? AppTheme.dangerLight : AppTheme.primaryLight;

  Color _serviceTypeColor(String s) {
    switch (s) {
      case 'repair':      return AppTheme.danger;
      case 'inspeksi':    return AppTheme.primary;
      case 'maintenance': return AppTheme.warning;
      default:            return AppTheme.textTertiary;
    }
  }

  Color _serviceTypeBg(String s) {
    switch (s) {
      case 'repair':      return AppTheme.dangerLight;
      case 'inspeksi':    return AppTheme.primaryLight;
      case 'maintenance': return AppTheme.warningLight;
      default:            return AppTheme.surface;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'in_progress':
      case 'on_the_way':  return AppTheme.warning;
      case 'on_site':     return AppTheme.primary;
      default:            return AppTheme.textTertiary;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'in_progress': return 'In Progress';
      case 'on_the_way':  return 'On The Way';
      case 'on_site':     return 'On Site';
      default:            return s;
    }
  }

  String _nextStatusLabel(String s) {
    switch (s) {
      case 'in_progress': return 'Berangkat';
      case 'on_the_way':  return 'Tiba di Lokasi';
      case 'on_site':     return 'Submit Laporan';
      default:            return 'Update';
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
      if (diff.inHours   < 24) return '${diff.inHours} jam lalu';
      if (diff.inDays    < 7)  return '${diff.inDays} hari lalu';
      const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${dt.day} ${m[dt.month]}';
    } catch (_) {
      return '';
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: const BottomNav(currentIndex: 0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: AppTheme.surface,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: greeting + bell
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting(),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary)),
                            Text(_name,
                                style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7, height: 7,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text('Available',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.secondary,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Badge(
                            label: Text('$_unreadCount'),
                            isLabelVisible: _unreadCount > 0,
                            child: IconButton(
                              icon: Icon(
                                _unreadCount > 0
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_outlined,
                                color: _unreadCount > 0
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                                size: 22,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                await context.push('/notifications');
                                if (mounted) _loadData();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stat boxes
                  Row(
                    children: [
                      _statBox('Job tersedia', '${_openJobs.length}'),
                      const SizedBox(width: 12),
                      _statBox('Aktif', '${_activeJobs.length}'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search bar
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cari deskripsi, perusahaan, kota...',
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
                  const SizedBox(height: 10),

                  // Tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primary,
                    tabs: [
                      Tab(text: 'Tersedia (${_openJobs.length})'),
                      Tab(text: 'Aktif (${_activeJobs.length})'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _jobList(_applyFilter(_openJobs),
                            isOpen: true,
                            scrollCtrl: _openScrollCtrl,
                            loadingMore: _loadingMore),
                        _jobList(_applyFilter(_activeJobs),
                            isActive: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );

  Widget _jobList(
    List<dynamic> jobs, {
    bool isOpen   = false,
    bool isActive = false,
    ScrollController? scrollCtrl,
    bool loadingMore = false,
  }) {
    final emptyMsg = isOpen
        ? 'Tidak ada job tersedia'
        : 'Tidak ada job aktif';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: jobs.isEmpty
          ? ListView(children: [
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(emptyMsg,
                      style: const TextStyle(
                          color: AppTheme.textSecondary)),
                ),
              ),
            ])
          : ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length + (loadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == jobs.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                return _buildJobCard(jobs[i],
                    isOpen: isOpen, isActive: isActive);
              },
            ),
    );
  }

  Widget _buildJobCard(dynamic job,
      {bool isOpen = false, bool isActive = false}) {
    final urgency     = job['urgency_level'] ?? 'standard';
    final isEmergency = urgency == 'emergency';
    final serviceType = job['service_type'] ?? '';
    final status      = job['status'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmergency ? AppTheme.danger : AppTheme.border,
          width: isEmergency ? 1.5 : 0.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _urgencyBg(urgency),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(urgency.toUpperCase(),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _urgencyColor(urgency))),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _serviceTypeBg(serviceType),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(serviceType,
                    style: TextStyle(
                        fontSize: 9,
                        color: _serviceTypeColor(serviceType))),
              ),
              const Spacer(),
              if (isOpen)
                Text(_timeAgo(job['created_at']),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textTertiary))
              else if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(_statusLabel(status),
                      style: TextStyle(
                          fontSize: 9,
                          color: _statusColor(status),
                          fontWeight: FontWeight.w500)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            '${job['description'] ?? '-'}  —  ${job['company_name'] ?? ''}',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${job['equipment_name'] ?? '-'}  ·  ${job['site_city'] ?? '-'}',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          // Action buttons
          if (isOpen) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await context.push('/booking/${job['id']}');
                      if (mounted) _loadData();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.border),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Detail',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _claimJob(job['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEmergency
                          ? AppTheme.danger
                          : AppTheme.primary,
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Ambil job',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ] else if (isActive) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await context.push('/booking/${job['id']}');
                      if (mounted) _loadData();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.border),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Detail',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(job),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'on_site'
                          ? AppTheme.secondary
                          : AppTheme.primary,
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(_nextStatusLabel(status),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
