import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bottom_nav.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _storage = const FlutterSecureStorage();
  String _name = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await _storage.read(key: AppConstants.userNameKey) ?? '';
    final role = await _storage.read(key: AppConstants.userRoleKey) ?? '';
    setState(() {
      _name = name;
      _role = role;
    });
  }

  Future<void> _logout() async {
    await ApiClient.clearToken();
    if (mounted) context.go('/login');
  }

  int get _navIndex {
    switch (_role) {
      case AppConstants.roleManager: return 3;
      case AppConstants.roleTeknisi: return 2;
      default: return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      bottomNavigationBar: BottomNav(currentIndex: _navIndex),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryLight,
              child: Text(
                _name.isNotEmpty ? _name.substring(0, 1) : '?',
                style: const TextStyle(
                    fontSize: 32,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
            Text(_name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(_role,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.primary)),
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: const Text('Logout',
                  style: TextStyle(color: AppTheme.danger)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}