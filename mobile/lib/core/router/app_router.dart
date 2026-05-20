import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/job_board/presentation/pages/job_board_page.dart';
import '../../features/booking/presentation/pages/booking_list_page.dart';
import '../constants/app_constants.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/booking/presentation/pages/create_booking_page.dart';

final _storage = const FlutterSecureStorage();

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    final isLoggedIn = token != null;
    final isLoginPage = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginPage) return '/login';
    if (isLoggedIn && isLoginPage) {
      final role = await _storage.read(key: AppConstants.userRoleKey);
      return _getHomeRoute(role ?? '');
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/job-board',
      builder: (context, state) => const JobBoardPage(),
    ),
    GoRoute(
      path: '/bookings',
      builder: (context, state) => const BookingListPage(),
    ),
    GoRoute(
      path: '/my-jobs',
      builder: (context, state) => const JobBoardPage(),
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
    GoRoute(
      path: '/technicians',
      builder: (context, state) => const BookingListPage(),
    ),
    GoRoute(
      path: '/booking/create',
      builder: (context, state) => const CreateBookingPage(),
    ),
  ],
);

String _getHomeRoute(String role) {
  switch (role) {
    case AppConstants.roleManager:
      return '/dashboard';
    case AppConstants.roleTeknisi:
      return '/job-board';
    case AppConstants.roleClient:
    case AppConstants.roleSales:
      return '/bookings';
    default:
      return '/login';
  }
}
