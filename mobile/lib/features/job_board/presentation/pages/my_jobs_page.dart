import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/my-jobs');
      if (mounted) {
        final all = List<dynamic>.from(res.data['data'] ?? []);
        setState(() {
          _activeJobs =
              all.where((j) => j['status'] != 'done').toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    final nextStatus =
        status == 'in_progress' ? 'on_the_way' : 'on_site';
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

  // ─── HELPERS ───────────────────────────────────────────────────────────

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
      default:            return 'Update Status';
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
      ),
    );
  }
}
