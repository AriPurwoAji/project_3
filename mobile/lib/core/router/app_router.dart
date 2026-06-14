import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/job_board/presentation/pages/job_board_page.dart';
import '../../features/job_board/presentation/pages/my_jobs_page.dart';
import '../../features/booking/presentation/pages/booking_list_page.dart';
import '../../features/booking/presentation/pages/booking_detail_page.dart';
import '../../features/booking/presentation/pages/create_booking_page.dart';
import '../../features/booking/presentation/pages/home_client_page.dart';
import '../../features/booking/presentation/pages/riwayat_page.dart';
import '../../features/booking/presentation/pages/technician_list_page.dart';
import '../../features/booking/presentation/pages/team_page.dart';
import '../../features/report/presentation/pages/create_report_page.dart';
import '../../features/report/presentation/pages/laporan_page.dart';
import '../../features/report/presentation/pages/report_detail_page.dart';
import '../../features/notification/presentation/pages/notification_page.dart';
import '../constants/app_constants.dart';

const _storage = FlutterSecureStorage();

/// Bungkus widget dengan fade transition 180ms.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    final isLoggedIn   = token != null;
    final loc          = state.matchedLocation;
    final isPublicPage = loc == '/login' || loc == '/register';

    if (!isLoggedIn && !isPublicPage) return '/login';
    if (isLoggedIn && loc == '/login') {
      final role = await _storage.read(key: AppConstants.userRoleKey);
      return _getHomeRoute(role ?? '');
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login',
        pageBuilder: (c, s) => _fade(s, const LoginPage())),
    GoRoute(path: '/register',
        pageBuilder: (c, s) => _fade(s, const RegisterPage())),

    // ── Manager ──────────────────────────────────────────────────────────
    GoRoute(path: '/dashboard',
        pageBuilder: (c, s) => _fade(s, const DashboardPage())),
    GoRoute(path: '/team',
        pageBuilder: (c, s) => _fade(s, const TeamPage())),
    GoRoute(path: '/technicians',
        pageBuilder: (c, s) => _fade(s, const TechnicianListPage())),

    // ── Teknisi ──────────────────────────────────────────────────────────
    GoRoute(path: '/job-board',
        pageBuilder: (c, s) => _fade(s, const JobBoardPage())),
    GoRoute(path: '/my-jobs',
        pageBuilder: (c, s) => _fade(s, const MyJobsPage())),
    GoRoute(path: '/laporan',
        pageBuilder: (c, s) => _fade(s, const LaporanPage())),

    // ── Client / Sales ───────────────────────────────────────────────────
    GoRoute(path: '/home',
        pageBuilder: (c, s) => _fade(s, const HomeClientPage())),
    GoRoute(path: '/riwayat',
        pageBuilder: (c, s) => _fade(s, const RiwayatPage())),

    // ── Shared ───────────────────────────────────────────────────────────
    GoRoute(path: '/bookings',
        pageBuilder: (c, s) => _fade(s, const BookingListPage())),
    GoRoute(path: '/booking/create',
        pageBuilder: (c, s) => _fade(s, const CreateBookingPage())),
    GoRoute(
      path: '/booking/:id',
      pageBuilder: (c, s) => _fade(s,
          BookingDetailPage(bookingId: s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/report/create',
      pageBuilder: (c, s) => _fade(s,
          CreateReportPage(booking: s.extra as Map<String, dynamic>)),
    ),
    GoRoute(path: '/notifications',
        pageBuilder: (c, s) => _fade(s, const NotificationPage())),
    GoRoute(
      path: '/report/:bookingId',
      pageBuilder: (c, s) => _fade(s,
          ReportDetailPage(bookingId: s.pathParameters['bookingId']!)),
    ),
    GoRoute(path: '/profile',
        pageBuilder: (c, s) => _fade(s, const ProfilePage())),
  ],
);

String _getHomeRoute(String role) {
  switch (role) {
    case AppConstants.roleManager:  return '/dashboard';
    case AppConstants.roleTeknisi:  return '/job-board';
    case AppConstants.roleClient:   return '/home';
    case AppConstants.roleSales:    return '/bookings';
    default:                        return '/login';
  }
}
