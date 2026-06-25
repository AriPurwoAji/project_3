import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/photo_viewer.dart';

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
  bool   _loading     = true;
  String _error       = '';
  String _userRole    = '';
  String _userId      = '';
  bool   _cancelling  = false;
  bool   _confirming  = false;
  bool   _rejecting   = false;
  List<dynamic> _allReports  = [];

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    _userRole = await _storage.read(key: AppConstants.userRoleKey) ?? '';
    _userId   = await _storage.read(key: AppConstants.userIDKey)   ?? '';
    try {
      final res = await ApiClient.instance.get('/bookings/${widget.bookingId}');
      if (!mounted) return;
      final booking = Map<String, dynamic>.from(res.data['data'] ?? {});
      setState(() {
        _booking = booking;
        _loading = false;
      });
      // Load laporan untuk semua status aktif (termasuk on_site agar teknisi tahu progres)
      if (const {'on_site', 'done', 'waiting_confirmation', 'needs_revision'}
          .contains(booking['status'])) {
        _loadReport();
        _loadAllReports();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = 'Gagal memuat detail booking';
          _loading = false;
        });
      }
    }
  }

  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Booking?'),
        content: const Text(
            'Booking yang dibatalkan tidak bisa dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white),
            child: const Text('Ya, batalkan'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ApiClient.instance
          .patch('/bookings/${widget.bookingId}/cancel');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Booking berhasil dibatalkan'),
              backgroundColor: AppTheme.secondary),
        );
        _loadBooking();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membatalkan booking')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _confirmJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hasil Kerja'),
        content: const Text(
            'Apakah kamu yakin hasil pekerjaan teknisi sudah sesuai dan memuaskan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Belum'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white),
            child: const Text('Ya, Konfirmasi'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _confirming = true);
    try {
      await ApiClient.instance.post('/bookings/${widget.bookingId}/confirm');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Terima kasih! Pekerjaan dinyatakan selesai.'),
              backgroundColor: AppTheme.secondary),
        );
        _loadBooking();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data?['message'] as String?) ?? 'Gagal konfirmasi'
          : 'Gagal konfirmasi';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _loadReport() async {
    try {
      final res = await ApiClient.instance.get('/reports/${widget.bookingId}');
      if (mounted) {
        setState(() {
          _report = Map<String, dynamic>.from(res.data['data'] ?? {});
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAllReports() async {
    try {
      final res = await ApiClient.instance.get('/reports/${widget.bookingId}/all');
      if (mounted) {
        setState(() {
          _allReports = List<dynamic>.from(res.data['data'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _rejectJob() async {
    String reasonInput = '';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Tolak Laporan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Berikan alasan penolakan agar teknisi dapat memperbaiki laporan:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (_, ss) => TextField(
                  controller: ctrl,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Deskripsi pekerjaan kurang lengkap...',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final r = ctrl.text.trim();
                if (r.isEmpty) return;
                reasonInput = r;
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
              child: const Text('Tolak Laporan'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || reasonInput.isEmpty || !mounted) return;
    setState(() => _rejecting = true);
    try {
      await ApiClient.instance.post(
        '/bookings/${widget.bookingId}/reject',
        data: {'reason': reasonInput},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Laporan ditolak. Teknisi akan segera diberitahu.'),
        backgroundColor: AppTheme.warning,
      ));
      _loadBooking();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data?['message'] as String?) ?? 'Gagal menolak laporan'
          : 'Gagal menolak laporan';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
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
      case 'open':                 return AppTheme.primary;
      case 'in_progress':
      case 'on_the_way':           return AppTheme.warning;
      case 'on_site':              return AppTheme.primary;
      case 'waiting_confirmation': return AppTheme.warning;
      case 'needs_revision':       return AppTheme.danger;
      case 'done':                 return AppTheme.secondary;
      case 'cancelled':            return AppTheme.danger;
      default:                     return AppTheme.textTertiary;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'open':                 return 'Open';
      case 'in_progress':          return 'In Progress';
      case 'on_the_way':           return 'On The Way';
      case 'on_site':              return 'On Site';
      case 'waiting_confirmation': return 'Menunggu Konfirmasi';
      case 'needs_revision':       return 'Perlu Perbaikan';
      case 'done':                 return 'Selesai';
      case 'cancelled':            return 'Dibatalkan';
      default:                     return s;
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
  // 0=dibuat 1=teknisi ambil 2=proses 3=menunggu konfirmasi 4=selesai
  int _currentStep(String status) {
    switch (status) {
      case 'open':                 return 0;
      case 'in_progress':          return 1;
      case 'on_the_way':           return 2;
      case 'on_site':              return 2;
      case 'waiting_confirmation': return 3;
      case 'needs_revision':       return 3;
      case 'done':                 return 4;
      case 'cancelled':            return 4;
      default:                     return 0;
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
                      if (_booking!['latitude'] != null &&
                          _booking!['longitude'] != null) ...[
                        const SizedBox(height: 16),
                        _buildMapCard(),
                      ],
                      const SizedBox(height: 16),
                      _buildTrackingSection(),
                      if (_userRole == AppConstants.roleManager &&
                          _booking!['status'] == 'open') ...[
                        const SizedBox(height: 16),
                        _buildAssignButton(),
                      ],
                      // Batalkan booking — untuk client/sales yang buat, atau manager
                      if (_booking!['status'] == 'open' &&
                          (_userRole == AppConstants.roleManager ||
                              _booking!['created_by'] == _userId)) ...[
                        const SizedBox(height: 12),
                        _buildCancelButton(),
                      ],
                      // Tombol konfirmasi + tolak untuk client / manager
                      if (_booking!['status'] == 'waiting_confirmation' &&
                          (_userRole == AppConstants.roleClient ||
                              _userRole == AppConstants.roleManager)) ...[
                        const SizedBox(height: 16),
                        _buildConfirmButton(),
                      ],
                      // Status needs_revision: teknisi perlu perbaiki laporan
                      if (_booking!['status'] == 'needs_revision') ...[
                        const SizedBox(height: 16),
                        _buildNeedsRevisionBanner(),
                      ],
                      // Info menunggu konfirmasi untuk teknisi
                      if (_booking!['status'] == 'waiting_confirmation' &&
                          _userRole == AppConstants.roleTeknisi) ...[
                        const SizedBox(height: 16),
                        _buildWaitingConfirmationInfo(),
                      ],
                      // Referensi dari client — khusus teknisi saat job aktif
                      if (_userRole == AppConstants.roleTeknisi &&
                          const {'in_progress', 'on_the_way', 'on_site', 'waiting_confirmation'}
                              .contains(_booking!['status'])) ...[
                        const SizedBox(height: 16),
                        _buildClientReferenceCard(),
                      ],
                      if ((_booking!['technician_name'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildTechnicianCard(),
                      ],
                      const SizedBox(height: 16),
                      _buildEquipmentCard(),
                      // Checklist equipment — teknisi, job aktif, ada 2 equipment
                      if (_userRole == AppConstants.roleTeknisi &&
                          (_booking!['equipment_id_2'] as String?) != null &&
                          const {'in_progress', 'on_the_way', 'on_site', 'waiting_confirmation'}
                              .contains(_booking!['status'])) ...[
                        const SizedBox(height: 16),
                        _buildEquipmentChecklist(),
                      ],
                      // Daftar item booking (inspeksi/maintenance)
                      if ((_booking!['items'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        _buildBookingItemsCard(),
                      ],
                      // Foto kerusakan — untuk client/manager (teknisi sudah ada di referensi card)
                      if (_userRole != AppConstants.roleTeknisi &&
                          (_booking!['photo_urls'] as List?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 16),
                        _buildBookingPhotosCard(),
                      ],
                      // Tampilkan semua laporan (multi-equipment support)
                      if (_allReports.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildAllReportsCard(),
                      ] else if (_report != null) ...[
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
          if ((b['scheduled_at'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 13, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Dijadwalkan: ${_formatDateTime(b['scheduled_at'])}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── TRACKING TIMELINE ────────────────────────────────────────────────────

  Widget _buildTrackingSection() {
    final b      = _booking!;
    final status = b['status'] ?? '';
    final step   = _currentStep(status);
    final isDone      = status == 'done';
    final isCancelled = status == 'cancelled';
    final isWaiting   = status == 'waiting_confirmation';

    final techName  = (b['technician_name'] ?? '').toString();
    final techShort = techName.isNotEmpty ? techName.split(' ').first : '';

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
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
            completed: step >= 3,
            active: step == 2,
            label: step == 2 ? _activeStepLabel(status) : 'Proses pengerjaan',
            time: step >= 2 ? _formatDateTime(b['started_at']) : '',
            isLast: false,
            activeColor: AppTheme.warning,
          ),
          _timelineStep(
            completed: isDone,
            active: isWaiting,
            label: 'Menunggu konfirmasi client',
            time: (isWaiting || isDone)
                ? _formatDateTime(b['completed_at'])
                : '',
            isLast: false,
            pending: step < 3 && !isCancelled,
            activeColor: AppTheme.warning,
          ),
          _timelineStep(
            completed: isDone,
            active: isCancelled,
            label: isCancelled ? 'Dibatalkan' : 'Selesai',
            time: isDone ? _formatDateTime(b['updated_at']) : '',
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

  // ─── CONFIRM + REJECT BUTTON (client/manager) ────────────────────────────

  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined,
                  size: 16, color: AppTheme.secondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Teknisi telah menyelesaikan pekerjaan dan mengajukan laporan.',
                  style: TextStyle(fontSize: 13, color: AppTheme.secondary,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Silakan periksa laporan di bawah, lalu konfirmasi atau tolak hasilnya.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_confirming || _rejecting) ? null : _rejectJob,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _rejecting
                      ? const SizedBox(height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.danger))
                      : const Icon(Icons.close, size: 18),
                  label: Text(_rejecting ? '...' : 'Tolak',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_confirming || _rejecting) ? null : _confirmJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _confirming
                      ? const SizedBox(height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    _confirming ? 'Memproses...' : 'Konfirmasi',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── NEEDS REVISION BANNER ────────────────────────────────────────────────

  Widget _buildNeedsRevisionBanner() {
    final isTeknisi = _userRole == AppConstants.roleTeknisi;

    // Cari semua laporan yang di-reject (bisa lebih dari 1 jika multi-equipment)
    final rejectedReports = _allReports
        .where((r) => (r['status'] as String?) == 'rejected')
        .toList();

    // Fallback ke _report jika _allReports belum dimuat
    final fallback = _report != null && (_report!['status'] as String?) == 'rejected'
        ? [_report!]
        : <Map<String, dynamic>>[];
    final toShow = rejectedReports.isNotEmpty ? rejectedReports : fallback;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dangerLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cancel_outlined, size: 18, color: AppTheme.danger),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Laporan Ditolak — Perlu Perbaikan',
                  style: TextStyle(fontSize: 13, color: AppTheme.danger,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (!isTeknisi) ...[
            const SizedBox(height: 8),
            const Text('Menunggu teknisi memperbaiki laporan...',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          if (isTeknisi) ...[
            const SizedBox(height: 8),
            ...toShow.map((r) {
              final reason    = (r['rejection_reason'] as String?) ?? '';
              final equipName = (r['equipment_name'] as String?) ?? '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (equipName.isNotEmpty)
                    Text('Equipment: $equipName',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppTheme.danger)),
                  if (reason.isNotEmpty)
                    Text('Alasan: $reason',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.push(
                      '/report/edit/${r['id']}',
                      extra: {'report': r, 'booking': _booking},
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      equipName.isNotEmpty ? 'Perbaiki Laporan — $equipName' : 'Perbaiki Laporan',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  // ─── WAITING INFO (teknisi) ───────────────────────────────────────────────

  Widget _buildWaitingConfirmationInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top_outlined,
              size: 18, color: AppTheme.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Laporan sudah terkirim. Menunggu konfirmasi dari client untuk menyelesaikan job ini.',
              style: TextStyle(fontSize: 13, color: AppTheme.warning,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CLIENT REFERENCE CARD (teknisi only) ────────────────────────────────

  Widget _buildClientReferenceCard() {
    final b       = _booking!;
    final desc    = (b['description'] as String? ?? '').trim();
    final photos  = List<String>.from(b['photo_urls'] as List? ?? []);

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
          const Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: AppTheme.primary),
              SizedBox(width: 6),
              Text('Laporan masalah dari client',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(desc,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      height: 1.5)),
            ),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Foto kerusakan',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: photos.asMap().entries.map((entry) {
                  final i   = entry.key;
                  final url = entry.value;
                  return GestureDetector(
                    onTap: () =>
                        showPhotoViewer(context, photos, initialIndex: i),
                    child: Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                                image: NetworkImage(url),
                                fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.zoom_in,
                                size: 13, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (desc.isEmpty && photos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Client tidak menyertakan deskripsi atau foto.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textTertiary)),
            ),
        ],
      ),
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

  // ─── BOOKING ITEMS CARD ──────────────────────────────────────────────────

  Future<void> _toggleBookingItem(String itemId, bool currentDone) async {
    try {
      await ApiClient.instance.patch(
        '/bookings/${widget.bookingId}/items/$itemId',
        data: {'is_done': !currentDone},
      );
      final res = await ApiClient.instance.get('/bookings/${widget.bookingId}');
      if (!mounted) return;
      setState(() {
        _booking = Map<String, dynamic>.from(res.data['data'] ?? {});
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui item'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Widget _buildBookingItemsCard() {
    final items     = (_booking!['items'] as List?) ?? [];
    final doneCount = items.where((it) => it['is_done'] == true).length;
    final total     = items.length;
    final isTeknisi = _userRole == AppConstants.roleTeknisi;
    final isActive  = const {
      'in_progress', 'on_the_way', 'on_site', 'waiting_confirmation'
    }.contains(_booking!['status']);
    final canToggle = isTeknisi && isActive;

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
              const Text('Daftar Item',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '$doneCount/$total selesai',
                style: TextStyle(
                  fontSize: 12,
                  color: doneCount == total
                      ? AppTheme.secondary
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (canToggle) ...[
            const SizedBox(height: 2),
            const Text(
              'Tap item untuk tandai selesai',
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textTertiary),
            ),
          ],
          const Divider(height: 14),
          ...items.asMap().entries.map((entry) {
            final idx  = entry.key;
            final item = entry.value as Map;
            final done = item['is_done'] == true;
            final id   = item['id'] as String;
            final desc = item['description'] as String? ?? '';

            return InkWell(
              onTap: canToggle ? () => _toggleBookingItem(id, done) : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: done
                          ? AppTheme.secondary
                          : AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${idx + 1}. $desc',
                        style: TextStyle(
                          fontSize: 13,
                          color: done
                              ? AppTheme.textTertiary
                              : AppTheme.textPrimary,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── EQUIPMENT CHECKLIST ─────────────────────────────────────────────────

  Future<void> _toggleEquipmentDone(String equipmentId, bool currentDone) async {
    final newDone = !currentDone;
    try {
      await ApiClient.instance.patch(
        '/bookings/${widget.bookingId}/equipment-done',
        data: {'equipment_id': equipmentId, 'done': newDone},
      );
      // Refresh booking data agar done_equipment_ids terupdate
      final res = await ApiClient.instance.get('/bookings/${widget.bookingId}');
      if (!mounted) return;
      setState(() {
        _booking = Map<String, dynamic>.from(res.data['data'] ?? {});
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui status equipment'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Widget _buildEquipmentChecklist() {
    final b             = _booking!;
    final doneIds       = List<String>.from(b['done_equipment_ids'] ?? []);
    final equip1Id      = b['equipment_id']   as String? ?? '';
    final equip2Id      = b['equipment_id_2'] as String? ?? '';
    final equip1Name    = b['equipment_name']   as String? ?? 'Equipment 1';
    final equip2Name    = b['equipment_name_2'] as String? ?? 'Equipment 2';
    final workEquipId   = b['work_equipment_id'] as String?;

    Widget checkItem(String id, String name) {
      final isDone = doneIds.contains(id);
      final isFirst = id == workEquipId;
      return InkWell(
        onTap: () => _toggleEquipmentDone(id, isDone),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                isDone
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isDone ? AppTheme.secondary : AppTheme.textTertiary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? AppTheme.textTertiary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    if (isFirst)
                      const Text(
                        'Dikerjakan pertama',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.primary),
                      ),
                  ],
                ),
              ),
              if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryLight,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text('Selesai',
                      style: TextStyle(
                          fontSize: 10, color: AppTheme.secondary)),
                ),
            ],
          ),
        ),
      );
    }

    final totalDone = doneIds.length;
    final total = equip2Id.isNotEmpty ? 2 : 1;

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
              const Text('Checklist Equipment',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '$totalDone/$total selesai',
                style: TextStyle(
                  fontSize: 12,
                  color: totalDone == total
                      ? AppTheme.secondary
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap equipment untuk tandai sudah dikerjakan',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
          ),
          const Divider(height: 16),
          if (equip1Id.isNotEmpty) checkItem(equip1Id, equip1Name),
          if (equip2Id.isNotEmpty) ...[
            const SizedBox(height: 4),
            checkItem(equip2Id, equip2Name),
          ],
        ],
      ),
    );
  }

  // ─── EQUIPMENT CARD ───────────────────────────────────────────────────────

  Widget _buildEquipmentCard() {
    final b         = _booking!;
    final equipName  = b['equipment_name']    as String? ?? '-';
    final equipName2 = b['equipment_name_2']  as String?;
    final workEquip  = b['work_equipment_name'] as String?;

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
          _infoRow('Equipment 1', equipName),
          if (equipName2 != null && equipName2.isNotEmpty)
            _infoRow('Equipment 2', equipName2),
          if (workEquip != null && workEquip.isNotEmpty)
            _infoRow('Dikerjakan pertama', workEquip),
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
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () =>
                context.push('/report/${widget.bookingId}'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new,
                    size: 13, color: AppTheme.primary),
                SizedBox(width: 4),
                Text('Lihat Detail Laporan',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── ALL REPORTS CARD (multi-equipment) ─────────────────────────────────

  Widget _buildAllReportsCard() {
    return Column(
      children: _allReports.asMap().entries.map((entry) {
        final i      = entry.key;
        final r      = entry.value as Map<String, dynamic>;
        final pdfUrl = r['pdf_url'] as String?;
        final workDesc   = (r['work_description'] as String?) ?? '-';
        final equipName  = (r['equipment_name']   as String?) ?? '';
        final status     = (r['status']           as String?) ?? 'submitted';
        final isRejected = status == 'rejected';

        return Container(
          margin: i > 0 ? const EdgeInsets.only(top: 10) : EdgeInsets.zero,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRejected ? AppTheme.dangerLight : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRejected
                  ? AppTheme.danger.withValues(alpha: 0.4)
                  : AppTheme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_outlined, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      equipName.isNotEmpty ? 'Laporan — $equipName' : 'Laporan servis',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isRejected
                          ? AppTheme.danger.withValues(alpha: 0.12)
                          : AppTheme.secondaryLight,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      isRejected ? 'Ditolak' : 'Terkirim',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isRejected ? AppTheme.danger : AppTheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(workDesc,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/report/${widget.bookingId}'),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.open_in_new, size: 13, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text('Lihat Detail',
                          style: TextStyle(fontSize: 12, color: AppTheme.primary,
                              fontWeight: FontWeight.w500)),
                    ]),
                  ),
                  if (pdfUrl != null) ...[
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _downloadingPdf ? null : () => _sharePdf(pdfUrl),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.share_outlined, size: 13, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text('Bagikan PDF',
                            style: TextStyle(fontSize: 12, color: AppTheme.primary,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── BOOKING PHOTOS ──────────────────────────────────────────────────────

  Widget _buildBookingPhotosCard() {
    final photos = List<String>.from(_booking!['photo_urls'] as List? ?? []);
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
          const Row(
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 15, color: AppTheme.textSecondary),
              SizedBox(width: 6),
              Text('Foto kerusakan',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: photos.asMap().entries.map((entry) {
                final i   = entry.key;
                final url = entry.value;
                return GestureDetector(
                  onTap: () => showPhotoViewer(context, photos,
                      initialIndex: i),
                  child: Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.zoom_in,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CANCEL BOOKING ──────────────────────────────────────────────────────

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: _cancelling
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.danger))
            : const Icon(Icons.cancel_outlined,
                size: 16, color: AppTheme.danger),
        label: const Text('Batalkan Booking',
            style: TextStyle(color: AppTheme.danger)),
        onPressed: _cancelling ? null : _cancelBooking,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.danger),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
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

  // ─── MAP CARD ─────────────────────────────────────────────────────────────

  Widget _buildMapCard() {
    final lat = (_booking!['latitude'] as num?)?.toDouble();
    final lng = (_booking!['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return const SizedBox.shrink();

    final point = LatLng(lat, lng);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini-map
          SizedBox(
            height: 180,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'com.aripurwoaji.hydraulic_service',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppTheme.danger,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tombol navigasi — geo: URI agar muncul chooser (Google Maps / Waze / dll)
          InkWell(
            onTap: () async {
              final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
              if (await canLaunchUrl(geoUri)) {
                await launchUrl(geoUri,
                    mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              color: AppTheme.primary,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.navigation_outlined,
                      size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Navigasi ke lokasi',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
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
          bottom: MediaQuery.viewInsetsOf(context).bottom),
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
