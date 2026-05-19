import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class JobBoardPage extends StatefulWidget {
  const JobBoardPage({super.key});

  @override
  State<JobBoardPage> createState() => _JobBoardPageState();
}

class _JobBoardPageState extends State<JobBoardPage> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _jobs = [];
  bool _loading = true;
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    _name = await _storage.read(key: AppConstants.userNameKey) ?? '';
    try {
      final res = await ApiClient.instance.get('/job-board');
      setState(() {
        _jobs = res.data['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiClient.clearToken();
    if (mounted) context.go('/login');
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
      _loadJobs();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadJobs,
              child: _jobs.isEmpty
                  ? const Center(
                      child: Text('Tidak ada job tersedia saat ini',
                        style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final job = _jobs[i];
                        final urgency = job['urgency_level'] ?? 'standard';
                        final isEmergency = urgency == 'emergency';
                        return Container(
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
                                  const SizedBox(width: 8),
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
                                        fontSize: 10,
                                        color: AppTheme.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                job['company_name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                job['equipment_name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
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
                                      fontSize: 12,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {},
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: AppTheme.border),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                            BorderRadius.circular(8)),
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
                                        minimumSize: const Size(0, 40),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                            BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Ambil job',
                                        style: TextStyle(fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}