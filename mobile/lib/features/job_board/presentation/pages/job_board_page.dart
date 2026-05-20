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
  List<dynamic> _myJobs = [];
  bool _loading = true;
  String _name = '';
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
      setState(() {
        _openJobs = results[0].data['data'] ?? [];
        _myJobs = results[1].data['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _claimJob(String bookingID) async {
    try {
      await ApiClient.instance.post('/bookings/$bookingID/claim');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job berhasil diambil!'),
          backgroundColor: AppTheme.secondary,
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengambil job'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Color _urgencyColor(String urgency) =>
      urgency == 'emergency' ? AppTheme.danger : AppTheme.primary;

  Color _urgencyBgColor(String urgency) =>
      urgency == 'emergency' ? AppTheme.dangerLight : AppTheme.primaryLight;

  Color _statusColor(String status) {
    switch (status) {
      case 'in_progress': return AppTheme.warning;
      case 'on_the_way': return AppTheme.warning;
      case 'on_site': return AppTheme.primary;
      case 'done': return AppTheme.secondary;
      default: return AppTheme.textTertiary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress': return 'In Progress';
      case 'on_the_way': return 'On The Way';
      case 'on_site': return 'On Site';
      case 'done': return 'Selesai';
      default: return status;
    }
  }

  Widget _buildJobCard(dynamic job, {bool isMyJob = false}) {
    final urgency = job['urgency_level'] ?? 'standard';
    final isEmergency = urgency == 'emergency';
    final status = job['status'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                  color: _urgencyBgColor(urgency),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  urgency.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _urgencyColor(urgency),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  job['service_type'] ?? '',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.warning),
                ),
              ),
              if (isMyJob) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                        fontSize: 10,
                        color: _statusColor(status),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job['company_name'] ?? '-',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            job['equipment_name'] ?? '-',
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppTheme.textTertiary),
              const SizedBox(width: 4),
              Text(
                job['site_city'] ?? '-',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textTertiary),
              ),
            ],
          ),
          if (!isMyJob) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
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
          ],
          if (isMyJob && status != 'done') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _updateStatus(job),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  _nextStatusLabel(status),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _nextStatusLabel(String status) {
    switch (status) {
      case 'in_progress': return 'Berangkat (On The Way)';
      case 'on_the_way': return 'Tiba di Lokasi (On Site)';
      case 'on_site': return 'Submit Laporan';
      default: return 'Update Status';
    }
  }

  Future<void> _updateStatus(dynamic job) async {
    final status = job['status'] ?? '';
    String nextStatus = '';
    switch (status) {
      case 'in_progress': nextStatus = 'on_the_way'; break;
      case 'on_the_way': nextStatus = 'on_site'; break;
      case 'on_site':
        // Nanti navigasi ke form laporan
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fitur laporan segera hadir!')));
        return;
    }
    try {
      await ApiClient.instance.patch(
        '/bookings/${job['id']}/status',
        data: {'status': nextStatus},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status diupdate ke $nextStatus'),
          backgroundColor: AppTheme.secondary,
        ),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal update status'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Job Board'),
            Text('Halo, $_name',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: AppTheme.textSecondary)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: [
            Tab(text: 'Open (${_openJobs.length})'),
            Tab(text: 'My Jobs (${_myJobs.length})'),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Open jobs
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _openJobs.isEmpty
                      ? const Center(
                          child: Text('Tidak ada job tersedia',
                              style: TextStyle(
                                  color: AppTheme.textSecondary)))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: _openJobs
                              .map((j) => _buildJobCard(j))
                              .toList(),
                        ),
                ),
                // My jobs
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _myJobs.isEmpty
                      ? const Center(
                          child: Text('Belum ada job yang diambil',
                              style: TextStyle(
                                  color: AppTheme.textSecondary)))
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: _myJobs
                              .map((j) =>
                                  _buildJobCard(j, isMyJob: true))
                              .toList(),
                        ),
                ),
              ],
            ),
    );
  }
}