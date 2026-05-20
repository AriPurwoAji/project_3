import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  const BottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: const FlutterSecureStorage()
          .read(key: AppConstants.userRoleKey),
      builder: (context, snapshot) {
        final role = snapshot.data ?? '';
        return NavigationBar(
          selectedIndex: currentIndex,
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.primaryLight,
          destinations: _getDestinations(role),
          onDestinationSelected: (i) =>
              _onTap(context, i, role),
        );
      },
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
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Teknisi'),
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
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'My Jobs'),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil'),
        ];
      default:
        return const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
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

  void _onTap(BuildContext context, int index, String role) {
    if (role == AppConstants.roleManager) {
      switch (index) {
        case 0: context.go('/dashboard'); break;
        case 1: context.go('/bookings'); break;
        case 2: context.go('/technicians'); break;
        case 3: context.go('/profile'); break;
      }
    } else if (role == AppConstants.roleTeknisi) {
      switch (index) {
        case 0: context.go('/job-board'); break;
        case 1: context.go('/my-jobs'); break;
        case 2: context.go('/profile'); break;
      }
    } else {
      switch (index) {
        case 0: context.go('/bookings'); break;
        case 1: context.go('/booking/create'); break;
        case 2: context.go('/bookings'); break;
        case 3: context.go('/profile'); break;
      }
    }
  }
}