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
  final _storage = const FlutterSecureStorage();

  List<dynamic> _openJobs = [];
  List<dynamic> _doneJobs = [];
  bool   _loading = true;
  String _name    = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _name = await _storage.read(key: AppConstants.userNameKey) ?? '';
    try {
      final results = await Future.wait([
        ApiClient.instance.get('/job-board'),
        ApiClient.instance.get('/my-jobs'),
      ]);
      if (mounted) {
        final allMyJobs = List<dynamic>.from(
            results[1].data['data'] ?? []);
        setState(() {
          _openJobs = results[0].data['data'] ?? [];
          _doneJobs = allMyJobs
              .where((j) => j['status'] == 'done')
              .toList();
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
                              width: 7,
                              height: 7,
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _statBox('Job tersedia', '${_openJobs.length}'),
                      const SizedBox(width: 12),
                      _statBox('Selesai', '${_doneJobs.length}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primary,
                    tabs: [
                      Tab(text: 'Open (${_openJobs.length})'),
                      Tab(text: 'Selesai (${_doneJobs.length})'),
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
                        _jobList(_openJobs, isOpen: true),
                        _jobList(_doneJobs, isDone: true),
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

  Widget _jobList(List<dynamic> jobs,
      {bool isOpen = false, bool isDone = false}) {
    final emptyMsg = isOpen
        ? 'Tidak ada job tersedia'
        : 'Belum ada job selesai';

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
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
              itemBuilder: (_, i) =>
                  _buildJobCard(jobs[i], isOpen: isOpen, isDone: isDone),
            ),
    );
  }

  Widget _buildJobCard(dynamic job,
      {bool isOpen = false, bool isDone = false}) {
    final urgency     = job['urgency_level'] ?? 'standard';
    final isEmergency = urgency == 'emergency';
    final serviceType = job['service_type'] ?? '';

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
              Text(_timeAgo(job['created_at']),
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textTertiary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${job['description'] ?? '-'} — ${job['company_name'] ?? ''}',
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
          if (isOpen) ...[
            const SizedBox(height: 12),
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
                            color: AppTheme.textSecondary,
                            fontSize: 13)),
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
          ] else if (isDone) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                await context.push('/booking/${job['id']}');
                if (mounted) _loadData();
              },
              child: const Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 13, color: AppTheme.primary),
                  SizedBox(width: 4),
                  Text('Lihat laporan',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.primary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
