import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/cache/page_cache.dart';
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
  bool    _loading      = true;
  bool    _hasData      = false;
  int     _unreadCount  = 0;
  String? _error;

  // Paginasi hanya untuk open jobs
  bool   _loadingMore  = false;
  bool   _hasMore      = true;
  int    _openOffset   = 0;
  static const _limit  = 20;
  final  _openScrollCtrl = ScrollController();

  String _name  = '';
  String _query = '';
  Timer? _debounce;
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
    final cached = PageCache.get<Map<String, dynamic>>('job_board');
    if (cached != null) {
      _openJobs   = cached['open']   as List<dynamic>;
      _activeJobs = cached['active'] as List<dynamic>;
      _unreadCount = cached['unread'] as int;
      _name       = cached['name']   as String;
      _loading    = false;
      _hasData    = true;
      _loadData(silent: true);
    } else {
      _loadData();
    }
    _openScrollCtrl.addListener(_onOpenScroll);
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _query = _searchCtrl.text);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
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

  Future<void> _loadData({bool silent = false}) async {
    _name = await _storage.read(key: AppConstants.userNameKey) ?? '';
    if (mounted) {
      setState(() {
        if (!silent && !_hasData) _loading = true;
        _openOffset = 0;
        _hasMore    = true;
        if (!silent) _openJobs = [];
        _error      = null;
      });
    }
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/job-board?limit=$_limit&offset=0'),
        ApiClient.instance.get('/my-jobs'),
        ApiClient.instance.get('/notifications/unread-count'),
      ]);
      if (mounted) {
        final open   = List<dynamic>.from(results[0].data['data'] ?? []);
        final all    = List<dynamic>.from(results[1].data['data'] ?? []);
        final active = all.where((j) => j['status'] != 'done' && j['status'] != 'cancelled').toList();
        final unread = (results[2].data['data']['unread_count'] as num?)?.toInt() ?? 0;

        PageCache.set('job_board', {
          'open':   open,
          'active': active,
          'unread': unread,
          'name':   _name,
        });

        setState(() {
          _openJobs    = open;
          _hasMore     = open.length == _limit;
          _openOffset  = open.length;
          _activeJobs  = active;
          _unreadCount = unread;
          _loading     = false;
          _hasData     = true;
        });
      }
    } catch (_) {
      if (!silent && mounted) {
        setState(() {
          _loading = false;
          _error   = 'Gagal memuat data. Periksa koneksi internet lalu tarik untuk refresh.';
        });
      }
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

  Future<void> _claimJob(dynamic job) async {
    final String bookingID = job['id'];
    try {
      await ApiClient.instance.post('/bookings/$bookingID/claim');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Job berhasil diambil!'),
        backgroundColor: AppTheme.secondary,
      ));
      PageCache.remove('job_board');
      await _loadData();
      if (mounted) _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      final msg = (e is DioException)
          ? (e.response?.data?['message'] as String? ?? 'Gagal mengambil job')
          : 'Gagal mengambil job';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  Future<void> _updateStatus(dynamic job) async {
    final status = job['status'] ?? '';
    if (status == 'on_site' || status == 'needs_revision') {
      await _showReportSheet(job);
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
      PageCache.remove('job_board');
      _loadData();
    } catch (e) {
      if (!mounted) return;
      final msg = (e is DioException)
          ? (e.response?.data?['message'] as String? ?? 'Gagal update status')
          : 'Gagal update status';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  Future<void> _showReportSheet(dynamic job) async {
    List<dynamic> reports = [];
    try {
      final res = await ApiClient.instance.get('/reports/${job['id']}/all');
      reports = List<dynamic>.from(res.data['data'] ?? []);
    } catch (_) {}
    if (!mounted) return;

    final equip1Id   = (job['equipment_id']   as String?) ?? '';
    final equip1Name = (job['equipment_name'] as String?) ?? 'Equipment 1';
    final equip2Id   = (job['equipment_id_2'] as String?) ?? '';
    final equip2Name = (job['equipment_name_2'] as String?) ?? 'Equipment 2';
    final hasEquip2  = equip2Id.isNotEmpty;

    Map<String, dynamic>? findReport(String equipId) {
      if (equipId.isEmpty) return null;
      for (final r in reports) {
        if ((r['equipment_id'] as String?) == equipId) {
          return Map<String, dynamic>.from(r);
        }
      }
      return null;
    }

    if (!hasEquip2) {
      final report = reports.isNotEmpty ? Map<String, dynamic>.from(reports.first) : null;
      if (report == null) {
        if (mounted) await context.push('/report/create', extra: Map<String, dynamic>.from(job));
      } else if ((report['status'] as String?) == 'rejected') {
        if (mounted) {
          await context.push('/report/edit/${report['id']}',
              extra: {'report': report, 'booking': Map<String, dynamic>.from(job)});
        }
      }
      if (mounted) {
        PageCache.remove('job_board');
        _loadData();
      }
      return;
    }

    final r1 = findReport(equip1Id);
    final r2 = findReport(equip2Id);

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(children: [
                const Text('Pilih Equipment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
              ]),
            ),
            const Divider(height: 1),
            _equipSheetTile(ctx, job, equip1Id, equip1Name, r1),
            _equipSheetTile(ctx, job, equip2Id, equip2Name, r2),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mounted) _loadData();
  }

  Widget _equipSheetTile(BuildContext ctx, dynamic job, String equipId,
      String equipName, Map<String, dynamic>? report) {
    final status      = (report?['status'] as String?) ?? 'none';
    final isSubmitted = status == 'submitted';
    final isRejected  = status == 'rejected';

    final subLabel = isSubmitted
        ? 'Sudah dilaporkan ✓'
        : isRejected
            ? 'Ditolak — perlu perbaikan'
            : 'Belum dilaporkan';
    final subColor = isSubmitted
        ? AppTheme.secondary
        : isRejected
            ? AppTheme.danger
            : AppTheme.textTertiary;
    final btnLabel = isSubmitted ? 'Terkirim' : isRejected ? 'Edit Laporan' : 'Buat Laporan';
    final btnColor = isRejected ? AppTheme.danger : AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isRejected ? AppTheme.dangerLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isRejected
                ? AppTheme.danger.withValues(alpha: 0.3)
                : isSubmitted
                    ? AppTheme.secondary.withValues(alpha: 0.3)
                    : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSubmitted ? Icons.check_circle : isRejected ? Icons.error_outline : Icons.build_outlined,
              color: isSubmitted ? AppTheme.secondary : isRejected ? AppTheme.danger : AppTheme.textTertiary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(equipName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subLabel, style: TextStyle(fontSize: 11, color: subColor)),
              ]),
            ),
            if (!isSubmitted)
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (isRejected) {
                    await context.push('/report/edit/${report!['id']}',
                        extra: {'report': report, 'booking': Map<String, dynamic>.from(job)});
                  } else {
                    final extra = Map<String, dynamic>.from(job)
                      ..['_force_equipment_id']   = equipId
                      ..['_force_equipment_name'] = equipName;
                    await context.push('/report/create', extra: extra);
                  }
                  if (context.mounted) {
                    PageCache.remove('job_board');
                    _loadData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(btnLabel, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
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
      case 'on_the_way':
      case 'waiting_confirmation': return AppTheme.warning;
      case 'on_site':              return AppTheme.primary;
      case 'needs_revision':       return AppTheme.danger;
      default:                     return AppTheme.textTertiary;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'in_progress':          return 'In Progress';
      case 'on_the_way':           return 'On The Way';
      case 'on_site':              return 'On Site';
      case 'waiting_confirmation': return 'Menunggu Konfirmasi';
      case 'needs_revision':       return 'Perlu Perbaikan';
      default:                     return s;
    }
  }

  String _nextStatusLabel(String s) {
    switch (s) {
      case 'in_progress':          return 'Berangkat';
      case 'on_the_way':           return 'Tiba di Lokasi';
      case 'on_site':              return 'Submit Laporan';
      case 'needs_revision':       return 'Perbaiki Laporan';
      case 'waiting_confirmation': return 'Menunggu Konfirmasi Client';
      default:                     return 'Update';
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
                  : _error != null && _openJobs.isEmpty && _activeJobs.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: 300,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_outlined,
                                    size: 48, color: AppTheme.textTertiary),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(_error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary, fontSize: 13)),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _loadData,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Coba lagi'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
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
            () {
              final e1 = job['equipment_name'] as String? ?? '-';
              final e2 = job['equipment_name_2'] as String?;
              final equip = (e2 != null && e2.isNotEmpty) ? '$e1 + $e2' : e1;
              return '$equip  ·  ${job['site_city'] ?? '-'}';
            }(),
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
                    onPressed: () => _claimJob(job),
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
                    onPressed: status == 'waiting_confirmation'
                        ? null
                        : () => _updateStatus(job),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'on_site'
                          ? AppTheme.secondary
                          : status == 'needs_revision'
                              ? AppTheme.danger
                              : status == 'waiting_confirmation'
                                  ? AppTheme.textTertiary
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
