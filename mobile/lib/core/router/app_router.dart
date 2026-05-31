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
        builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register',
        builder: (_, __) => const RegisterPage()),

    // ── Manager ──────────────────────────────────────────────────────────
    GoRoute(path: '/dashboard',
        builder: (_, __) => const DashboardPage()),
    GoRoute(path: '/team',
        builder: (_, __) => const TeamPage()),
    GoRoute(path: '/technicians',
        builder: (_, __) => const TechnicianListPage()),

    // ── Teknisi ──────────────────────────────────────────────────────────
    GoRoute(path: '/job-board',
        builder: (_, __) => const JobBoardPage()),
    GoRoute(path: '/my-jobs',
        builder: (_, __) => const MyJobsPage()),
    GoRoute(path: '/laporan',
        builder: (_, __) => const LaporanPage()),

    // ── Client / Sales ───────────────────────────────────────────────────
    GoRoute(path: '/home',
        builder: (_, __) => const HomeClientPage()),
    GoRoute(path: '/riwayat',
        builder: (_, __) => const RiwayatPage()),

    // ── Shared ───────────────────────────────────────────────────────────
    GoRoute(path: '/bookings',
        builder: (_, __) => const BookingListPage()),
    GoRoute(path: '/booking/create',
        builder: (_, __) => const CreateBookingPage()),
    GoRoute(
      path: '/booking/:id',
      builder: (_, state) =>
          BookingDetailPage(bookingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/report/create',
      builder: (_, state) {
        final booking = state.extra as Map<String, dynamic>;
        return CreateReportPage(booking: booking);
      },
    ),
    GoRoute(path: '/notifications',
        builder: (_, __) => const NotificationPage()),
    GoRoute(
      path: '/report/:bookingId',
      builder: (_, state) =>
          ReportDetailPage(bookingId: state.pathParameters['bookingId']!),
    ),
    GoRoute(path: '/profile',
        builder: (_, __) => const ProfilePage()),
  ],
);

String _getHomeRoute(String role) {
  switch (role) {
    case AppConstants.roleManager:  return '/dashboard';
    case AppConstants.roleTeknisi:  return '/job-board';
    case AppConstants.roleClient:
    case AppConstants.roleSales:    return '/home';
    default:                        return '/login';
  }
}
