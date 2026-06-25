import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/cache/page_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class MyJobsPage extends StatefulWidget {
  const MyJobsPage({super.key});

  @override
  State<MyJobsPage> createState() => _MyJobsPageState();
}

class _MyJobsPageState extends State<MyJobsPage> {
  List<dynamic> _activeJobs = [];
  bool _loading = true;
  bool _hasData = false;

  static const _cacheKey = 'my_jobs';

  @override
  void initState() {
    super.initState();
    final cached = PageCache.get<List<dynamic>>(_cacheKey);
    if (cached != null) {
      _activeJobs = cached;
      _loading    = false;
      _hasData    = true;
      _loadData(silent: true);
    } else {
      _loadData();
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && !_hasData && mounted) setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/my-jobs');
      if (mounted) {
        final all = List<dynamic>.from(res.data['data'] ?? []);
        final active = all.where((j) => j['status'] != 'done' && j['status'] != 'cancelled').toList();
        PageCache.set(_cacheKey, active);
        setState(() {
          _activeJobs = active;
          _loading    = false;
          _hasData    = true;
        });
      }
    } catch (_) {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(dynamic job) async {
    final status = job['status'] ?? '';

    // on_site → buka sheet pilih laporan; needs_revision → perbaiki laporan
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
      _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Gagal update status'),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  /// Bottom sheet: pilih equipment & status laporan sebelum navigasi ke form
  Future<void> _showReportSheet(dynamic job) async {
    // Ambil daftar laporan yang sudah ada untuk booking ini
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

    // Cari laporan berdasarkan equipment_id
    Map<String, dynamic>? findReport(String equipId) {
      if (equipId.isEmpty) return null;
      for (final r in reports) {
        if ((r['equipment_id'] as String?) == equipId) {
          return Map<String, dynamic>.from(r);
        }
      }
      // Single-equipment booking: laporan tidak punya equipment_id
      return null;
    }

    // Untuk single equipment, langsung navigate tanpa sheet
    if (!hasEquip2) {
      // Coba cari laporan (bisa dengan equipment_id null/kosong)
      final report = reports.isNotEmpty ? Map<String, dynamic>.from(reports.first) : null;
      if (report == null) {
        // Belum ada laporan → buat baru
        if (mounted) {
          await context.push('/report/create', extra: Map<String, dynamic>.from(job));
        }
      } else if ((report['status'] as String?) == 'rejected') {
        // Laporan ditolak → edit
        if (mounted) {
          await context.push('/report/edit/${report['id']}',
              extra: {'report': report, 'booking': Map<String, dynamic>.from(job)});
        }
      }
      // submitted → tidak ada aksi (tombol sudah disabled di luar)
      if (mounted) _loadData();
      return;
    }

    // Multi-equipment → tampilkan sheet
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
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (isRejected) {
                    context.push('/report/edit/${report!['id']}',
                        extra: {'report': report, 'booking': Map<String, dynamic>.from(job)});
                  } else {
                    final extra = Map<String, dynamic>.from(job)
                      ..['_force_equipment_id']   = equipId
                      ..['_force_equipment_name'] = equipName;
                    context.push('/report/create', extra: extra);
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

  // ─── HELPERS ───────────────────────────────────────────────────────────

  Color _statusColor(String s) {
    switch (s) {
      case 'in_progress':
      case 'on_the_way':           return AppTheme.warning;
      case 'on_site':              return AppTheme.primary;
      case 'waiting_confirmation': return AppTheme.warning;
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
      default:                     return 'Update Status';
    }
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

  // ─── BUILD ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('My Jobs (${_activeJobs.length})'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _activeJobs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_outlined,
                              size: 48, color: AppTheme.textTertiary),
                          SizedBox(height: 12),
                          Text('Belum ada job aktif',
                              style: TextStyle(
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _activeJobs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) => _jobCard(_activeJobs[i]),
                    ),
            ),
    );
  }

  Widget _jobCard(dynamic job) {
    final urgency     = job['urgency_level'] ?? 'standard';
    final isEmergency = urgency == 'emergency';
    final status      = job['status'] ?? '';
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
          // Action button
          const SizedBox(height: 12),
          Row(
            children: [
              // Detail button
              OutlinedButton(
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
      ),
    );
  }
}
