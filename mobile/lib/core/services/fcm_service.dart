import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';

class FCMService {
  static final _messaging         = FirebaseMessaging.instance;
  static final _localNotif        = FlutterLocalNotificationsPlugin();
  static const _channelId         = 'hydroserv_notif';
  static const _channelName       = 'HydroServ Notifikasi';
  static const _channelDesc       = 'Notifikasi booking dan status servis';

  // ─── Init local notification plugin + Android channel ───────────────────

  static Future<void> initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotif.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onNotifTap,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    ));
  }

  // ─── Setup setelah login berhasil ────────────────────────────────────────

  static Future<void> setup(GlobalKey<NavigatorState> navigatorKey) async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await _messaging.getToken();
    if (token != null) await _sendToken(token);

    _messaging.onTokenRefresh.listen(_sendToken);

    // Notifikasi saat app FOREGROUND → tampilkan via local notification
    FirebaseMessaging.onMessage.listen(_showLocal);

    // User tap notifikasi saat app BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen(_navigate);

    // App dibuka via notifikasi saat TERMINATED
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _navigate(initial);
  }

  // ─── Kirim FCM token ke backend ──────────────────────────────────────────

  static Future<void> _sendToken(String token) async {
    try {
      await ApiClient.instance
          .patch('/auth/fcm-token', data: {'fcm_token': token});
    } catch (_) {}
  }

  // ─── Tampilkan notifikasi lokal saat app foreground ──────────────────────

  static Future<void> _showLocal(RemoteMessage msg) async {
    final notif = msg.notification;
    if (notif == null) return;

    await _localNotif.show(
      msg.hashCode,
      notif.title ?? 'HydroServ',
      notif.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(msg.data),
    );
  }

  // ─── Tap notifikasi lokal (foreground) → navigasi ke booking ─────────────

  static void _onNotifTap(NotificationResponse res) {
    if (res.payload == null || res.payload!.isEmpty) return;
    try {
      final data      = jsonDecode(res.payload!) as Map<String, dynamic>;
      final bookingId = data['booking_id'] as String?;
      if (bookingId != null) {
        appRouter.push('/booking/$bookingId');
      }
    } catch (_) {}
  }

  // ─── Tap notifikasi push (background / terminated) → navigasi ke booking ─

  static void _navigate(RemoteMessage msg) {
    final bookingId = msg.data['booking_id'] as String?;
    if (bookingId != null) {
      appRouter.push('/booking/$bookingId');
    }
  }
}
