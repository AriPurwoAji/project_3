import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _storage = const FlutterSecureStorage();
  String _name = '';
  Map<String, dynamic>? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _name = await _storage.read(key: AppConstants.userNameKey) ?? '';
    try {
      final res = await ApiClient.instance.get('/dashboard/summary');
      setState(() {
        _summary = res.data['data'];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
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
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text('Selamat datang,',
                      style: TextStyle(fontSize: 14,
                        color: AppTheme.textSecondary)),
                    Text(_name,
                      style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w500)),
                    const SizedBox(height: 20),

                    // Summary cards
                    if (_summary != null) ...[
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _statCard('Total Booking',
                            '${_summary!['total_bookings']}',
                            AppTheme.primary, AppTheme.primaryLight),
                          _statCard('Selesai',
                            '${_summary!['completed_bookings']}',
                            AppTheme.secondary, AppTheme.secondaryLight),
                          _statCard('Open',
                            '${_summary!['open_bookings']}',
                            AppTheme.warning, AppTheme.warningLight),
                          _statCard('Rata-rata waktu',
                            '${_summary!['avg_completion_hours'].toStringAsFixed(1)} jam',
                            AppTheme.danger, AppTheme.dangerLight),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
            style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 6),
          Text(value,
            style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}