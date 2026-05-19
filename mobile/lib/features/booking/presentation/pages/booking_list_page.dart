import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BookingListPage extends StatefulWidget {
  const BookingListPage({super.key});

  @override
  State<BookingListPage> createState() => _BookingListPageState();
}

class _BookingListPageState extends State<BookingListPage> {
  final _storage = const FlutterSecureStorage();
  List<dynamic> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      final res = await ApiClient.instance.get('/bookings');
      setState(() {
        _bookings = res.data['data'] ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Booking'),
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
              onRefresh: _loadBookings,
              child: _bookings.isEmpty
                  ? const Center(
                      child: Text('Belum ada booking',
                        style: TextStyle(color: AppTheme.textSecondary)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final b = _bookings[i];
                        final status = b['status'] ?? '';
                        final statusColor = _statusColor(status);
                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.border, width: 0.5),
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(99),
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
                                  Text(
                                    b['service_type'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                b['company_name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                b['equipment_name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                    size: 14,
                                    color: AppTheme.textTertiary),
                                  const SizedBox(width: 4),
                                  Text(
                                    b['site_city'] ?? '-',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                  if (b['technician_name'] != null &&
                                    b['technician_name'] != '') ...[
                                    const SizedBox(width: 12),
                                    const Icon(Icons.person_outline,
                                      size: 14,
                                      color: AppTheme.textTertiary),
                                    const SizedBox(width: 4),
                                    Text(
                                      b['technician_name'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                  ],
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