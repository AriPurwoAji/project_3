import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';

class BottomNav extends StatefulWidget {
  final int currentIndex;
  const BottomNav({super.key, required this.currentIndex});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  static const _storage = FlutterSecureStorage();

  // Ambil dari cache langsung — tidak perlu await jika sudah login
  String _role = ApiClient.cachedRole;

  @override
  void initState() {
    super.initState();
    if (_role.isEmpty) {
      // Cold start: baca storage sekali, tidak ada FutureBuilder rebuild berulang
      _storage.read(key: AppConstants.userRoleKey).then((r) {
        if (mounted && r != null && r != _role) {
          setState(() => _role = r);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _getDestinations(_role);
    final safeIndex    = widget.currentIndex.clamp(0, destinations.length - 1);
    return NavigationBar(
      selectedIndex: safeIndex,
      backgroundColor: AppTheme.surface,
      indicatorColor: AppTheme.primaryLight,
      destinations: destinations,
      onDestinationSelected: (i) => _onTap(context, i),
    );
  }

  List<NavigationDestination> _getDestinations(String role) {
    switch (role) {
      case AppConstants.roleManager:
        return const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Booking'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Tim'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ];
      case AppConstants.roleTeknisi:
        return const [
          NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'Job Board'),
          NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Laporan'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ];
      case AppConstants.roleSales:
        return const [
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Booking'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Riwayat'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ];
      default: // client
        return const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Booking'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Riwayat'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ];
    }
  }

  void _onTap(BuildContext context, int index) {
    switch (_role) {
      case AppConstants.roleManager:
        switch (index) {
          case 0: context.go('/dashboard'); break;
          case 1: context.go('/bookings');  break;
          case 2: context.go('/team');      break;
          case 3: context.go('/profile');   break;
        }
      case AppConstants.roleTeknisi:
        switch (index) {
          case 0: context.go('/job-board'); break;
          case 1: context.go('/laporan');   break;
          case 2: context.go('/profile');   break;
        }
      case AppConstants.roleSales:
        switch (index) {
          case 0: context.go('/bookings'); break;
          case 1: context.go('/riwayat');  break;
          case 2: context.go('/profile');  break;
        }
      default: // client
        switch (index) {
          case 0: context.go('/home');     break;
          case 1: context.go('/bookings'); break;
          case 2: context.go('/riwayat');  break;
          case 3: context.go('/profile');  break;
        }
    }
  }
}
