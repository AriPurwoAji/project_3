import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/notifications');
      if (mounted) {
        setState(() {
          _notifications = res.data['data'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ApiClient.instance.patch('/notifications/read-all');
      _loadData();
    } catch (_) {}
  }

  Future<void> _onTapNotif(dynamic n) async {
    final id       = n['id'] as String?;
    final bookingId = n['booking_id'] as String?;
    final isRead   = n['is_read'] as bool? ?? false;

    if (!isRead && id != null) {
      try {
        await ApiClient.instance.patch('/notifications/$id/read');
      } catch (_) {}
    }

    if (!mounted) return;

    if (bookingId != null) {
      context.push('/booking/$bookingId');
    } else {
      _loadData();
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt  = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1)  return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
      if (diff.inHours < 24)   return '${diff.inHours}j lalu';
      if (diff.inDays < 7)     return '${diff.inDays}h lalu';
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month]}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications
        .where((n) => !(n['is_read'] as bool? ?? false))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Baca semua',
                  style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.notifications_none_outlined,
                              size: 52, color: AppTheme.textTertiary),
                          SizedBox(height: 12),
                          Text('Belum ada notifikasi',
                              style: TextStyle(
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 16),
                      itemBuilder: (_, i) =>
                          _notifCard(_notifications[i]),
                    ),
            ),
    );
  }

  Widget _notifCard(dynamic n) {
    final isRead    = n['is_read'] as bool? ?? false;
    final title     = n['title'] as String? ?? '';
    final body      = n['body'] as String? ?? '';
    final time      = _formatTime(n['created_at'] as String?);
    final hasBooking = n['booking_id'] != null;

    return InkWell(
      onTap: () => _onTapNotif(n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isRead ? AppTheme.surface : AppTheme.primaryLight,
          border: Border(
            left: BorderSide(
              color: isRead ? Colors.transparent : AppTheme.primary,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isRead
                    ? AppTheme.background
                    : AppTheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasBooking
                    ? Icons.assignment_outlined
                    : Icons.notifications_outlined,
                size: 18,
                color:
                    isRead ? AppTheme.textTertiary : AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(time,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textTertiary)),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(body,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (!isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ] else if (hasBooking) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppTheme.textTertiary),
            ],
          ],
        ),
      ),
    );
  }
}
