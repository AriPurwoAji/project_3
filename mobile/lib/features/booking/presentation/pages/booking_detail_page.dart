import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class BookingDetailPage extends StatefulWidget {
  final String bookingId;
  const BookingDetailPage({super.key, required this.bookingId});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _booking;
  Map<String, dynamic>? _report;
  bool   _loading   = true;
  String _error     = '';
  String _userRole  = '';

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    _userRole = await _storage.read(key: AppConstants.userRoleKey) ?? '';
    try {
      final res = await ApiClient.instance.get('/bookings/${widget.bookingId}');
      if (!mounted) return;
      final booking = Map<String, dynamic>.from(res.data['data'] ?? {});
      setState(() {
        _booking = booking;
        _loading = false;
      });
      if (booking['status'] == 'done') _loadReport();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = 'Gagal memuat detail booking';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadReport() async {
    try {
      final res = await ApiClient.instance
          .get('/reports/${widget.bookingId}');
      if (mounted) {
        setState(() {
          _report = Map<String, dynamic>.from(res.data['data'] ?? {});
        });
      }
    } catch (_) {}
  }

  bool _downloadingPdf = false;

  Future<void> _sharePdf(String url) async {
    if (_downloadingPdf) return;
    setState(() => _downloadingPdf = true);
    try {
      final dir      = await getTemporaryDirectory();
      final reportId = _report?['id'] as String? ?? 'report';
      final path     = '${dir.path}/laporan_$reportId.pdf';
      if (!File(path).existsSync()) {
        await Dio().download(url, path);
      }
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf')],
        subject: 'Laporan Servis HydroServ',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh PDF')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────

  Color _statusColor(String s) {
    switch (s) {
      case 'open':        return AppTheme.primary;
      case 'in_progress':
      case 'on_the_way':  return AppTheme.warning;
      case 'on_site':     return AppTheme.primary;
      case 'done':        return AppTheme.secondary;
      case 'cancelled':   return AppTheme.danger;
      default:            return AppTheme.textTertiary;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'open':        return 'Open';
      case 'in_progress': return 'In Progress';
      case 'on_the_way':  return 'On The Way';
      case 'on_site':     return 'On Site';
      case 'done':        return 'Selesai';
      case 'cancelled':   return 'Dibatalkan';
      default:            return s;
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month]} · $h:$m';
    } catch (_) {
      return '';
    }
  }

  // ─── TIMELINE LOGIC ───────────────────────────────────────────────────────

  // Returns index of current active step (0-based):
  // 0 = booking dibuat, 1 = teknisi ambil, 2 = proses, 3 = selesai
  int _currentStep(String status) {
    switch (status) {
      case 'open':        return 0;
      case 'in_progress': return 1;
      case 'on_the_way':  return 2;
      case 'on_site':     return 2;
      case 'done':        return 3;
      case 'cancelled':   return 3;
      default:            return 0;
    }
  }

  String _activeStepLabel(String status) {
    switch (status) {
      case 'in_progress': return 'In Progress';
      case 'on_the_way':  return 'Dalam perjalanan';
      case 'on_site':     return 'On Site · Sedang dikerjakan';
      default:            return status;
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Booking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Text(_error,
                      style: const TextStyle(color: AppTheme.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _loadBooking,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildTrackingSection(),
                      if (_userRole == AppConstants.roleManager &&
                          _booking!['status'] == 'open') ...[
                        const SizedBox(height: 16),
                        _buildAssignButton(),
                      ],
                      if ((_booking!['technician_name'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildTechnicianCard(),
                      ],
                      const SizedBox(height: 16),
                      _buildEquipmentCard(),
                      if (_report != null) ...[
                        const SizedBox(height: 16),
                        _buildReportCard(),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  // ─── HEADER CARD ──────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    final b           = _booking!;
    final status      = b['status'] ?? '';
    final statusColor = _statusColor(status);
    final isEmergency = b['urgency_level'] == 'emergency';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(_statusLabel(status),
                    style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w500)),
              ),
              if (isEmergency) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerLight,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text('EMERGENCY',
                      style: TextStyle(
                          fontSize: 9,
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              Text(
                b['service_type'] ?? '',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(b['description'] ?? '-',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(b['company_name'] ?? '-',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 13, color: AppTheme.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${b['site_address'] ?? ''}, ${b['site_city'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textTertiary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: AppTheme.textTertiary),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(b['created_at']).split('·').first.trim(),
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TRACKING TIMELINE ────────────────────────────────────────────────────

  Widget _buildTrackingSection() {
    final b      = _booking!;
    final status = b['status'] ?? '';
    final step   = _currentStep(status);
    final isDone = status == 'done';
    final isCancelled = status == 'cancelled';

    final techName = (b['technician_name'] ?? '').toString();
    final techShort = techName.isNotEmpty
        ? techName.split(' ').first
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tracking status',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _timelineStep(
            completed: true,
            active: false,
            label: 'Booking dibuat',
            time: _formatDateTime(b['created_at']),
            isLast: false,
          ),
          _timelineStep(
            completed: step >= 1,
            active: step == 1,
            label: 'Teknisi mengambil job',
            time: step >= 1
                ? '${_formatDateTime(b['claimed_at'])}${techShort.isNotEmpty ? ' · $techShort' : ''}'
                : '',
            isLast: false,
          ),
          _timelineStep(
            completed: step >= 2,
            active: step == 2,
            label: step == 2 ? _activeStepLabel(status) : 'Proses pengerjaan',
            time: step >= 2 ? _formatDateTime(b['started_at']) : '',
            isLast: false,
            activeColor: AppTheme.warning,
          ),
          _timelineStep(
            completed: isDone,
            active: isCancelled,
            label: isCancelled ? 'Dibatalkan' : 'Selesai',
            time: isDone ? _formatDateTime(b['completed_at']) : '',
            isLast: true,
            pending: !isDone && !isCancelled,
            activeColor: isCancelled ? AppTheme.danger : AppTheme.secondary,
          ),
        ],
      ),
    );
  }

  Widget _timelineStep({
    required bool completed,
    required bool active,
    required String label,
    required String time,
    required bool isLast,
    bool pending = false,
    Color activeColor = AppTheme.primary,
  }) {
    final dotColor = completed
        ? AppTheme.secondary
        : active
            ? activeColor
            : AppTheme.border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dot + line
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: completed
                    ? AppTheme.secondary
                    : active
                        ? activeColor
                        : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: dotColor,
                  width: completed || active ? 0 : 1.5,
                ),
              ),
              child: completed
                  ? const Icon(Icons.check, size: 9, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: completed ? AppTheme.secondary : AppTheme.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Label + time
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 0, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: active
                        ? activeColor
                        : completed
                            ? AppTheme.textPrimary
                            : AppTheme.textTertiary,
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary)),
                ],
                if (pending)
                  const Text('Menunggu...',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── TECHNICIAN CARD ──────────────────────────────────────────────────────

  Widget _buildTechnicianCard() {
    final name = _booking!['technician_name'] ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primary,
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Teknisi yang mengerjakan',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── EQUIPMENT CARD ───────────────────────────────────────────────────────

  Widget _buildEquipmentCard() {
    final b = _booking!;
    final equipName = b['equipment_name'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detail equipment',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _infoRow('Nama', equipName),
          if ((b['description'] ?? '').isNotEmpty)
            _infoRow('Deskripsi', b['description'] ?? ''),
          _infoRow('Lokasi', '${b['site_address'] ?? '-'}, ${b['site_city'] ?? ''}'),
        ],
      ),
    );
  }

  Widget _buildReportCard() {
    final pdfUrl = _report?['pdf_url'] as String?;
    final workDesc = _report?['work_description'] as String? ?? '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  size: 15, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text('Laporan servis',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (pdfUrl != null)
                GestureDetector(
                  onTap: _downloadingPdf ? null : () => _sharePdf(pdfUrl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _downloadingPdf
                          ? const [
                              SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AppTheme.primary)),
                              SizedBox(width: 4),
                              Text('Mengunduh...',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primary)),
                            ]
                          : const [
                              Icon(Icons.share_outlined,
                                  size: 13, color: AppTheme.primary),
                              SizedBox(width: 4),
                              Text('Bagikan PDF',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w500)),
                            ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(workDesc,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ─── ASSIGN TEKNISI (manager only) ───────────────────────────────────────

  Widget _buildAssignButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.person_add_outlined, size: 18),
        label: const Text('Assign Teknisi'),
        onPressed: _showAssignSheet,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showAssignSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _AssignTechnicianSheet(
        bookingId: widget.bookingId,
        onAssigned: () {
          Navigator.pop(ctx);
          _loadBooking();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Teknisi berhasil di-assign')),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ─── ASSIGN TECHNICIAN SHEET ──────────────────────────────────────────────────

class _AssignTechnicianSheet extends StatefulWidget {
  final String bookingId;
  final VoidCallback onAssigned;

  const _AssignTechnicianSheet({
    required this.bookingId,
    required this.onAssigned,
  });

  @override
  State<_AssignTechnicianSheet> createState() =>
      _AssignTechnicianSheetState();
}

class _AssignTechnicianSheetState extends State<_AssignTechnicianSheet> {
  List<dynamic> _teknisi  = [];
  bool          _loading  = true;
  bool          _assigning = false;

  @override
  void initState() {
    super.initState();
    _loadTeknisi();
  }

  Future<void> _loadTeknisi() async {
    try {
      final res = await ApiClient.instance.get('/users/teknisi');
      if (mounted) {
        setState(() {
          _teknisi = res.data['data'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign(String technicianId) async {
    setState(() => _assigning = true);
    try {
      await ApiClient.instance.post(
        '/bookings/${widget.bookingId}/assign',
        data: {'technician_id': technicianId},
      );
      widget.onAssigned();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengassign teknisi')),
        );
        setState(() => _assigning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                const Text('Pilih Teknisi',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else if (_teknisi.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Belum ada teknisi terdaftar',
                  style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: _teknisi.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final t       = _teknisi[i];
                  final name    = t['full_name'] as String? ?? '-';
                  final phone   = t['phone'] as String? ?? '';
                  final initial = name.isNotEmpty
                      ? name[0].toUpperCase()
                      : '?';

                  return GestureDetector(
                    onTap: _assigning
                        ? null
                        : () => _assign(t['id'] as String),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.border, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryLight,
                            child: Text(initial,
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                if (phone.isNotEmpty)
                                  Text(phone,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          if (_assigning)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.chevron_right,
                                size: 18,
                                color: AppTheme.textTertiary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
