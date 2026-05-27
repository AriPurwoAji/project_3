import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'HydroServ';

  // API
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8080/api/v1';
  
  // Storage keys
  static const String accessTokenKey  = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey     = 'user_role';
  static const String userIDKey       = 'user_id';
  static const String userNameKey     = 'user_name';
  static const String companyIdKey    = 'company_id';
  static const String companyNameKey  = 'company_name';

  // Roles
  static const String roleClient   = 'client';
  static const String roleSales    = 'sales';
  static const String roleTeknisi  = 'teknisi';
  static const String roleManager  = 'manager';

  // Service types
  static const List<String> serviceTypes = [
    'repair', 'inspeksi', 'maintenance'
  ];

  // Urgency
  static const List<String> urgencyLevels = ['emergency', 'standard'];

  // Booking status
  static const List<String> bookingStatuses = [
    'open', 'in_progress', 'on_the_way', 'on_site', 'done', 'cancelled'
  ];

  // Item types inspeksi
  static const List<String> inspectionItemTypes = ['hose', 'cylinder', 'pump'];

  // Fitting standards
  static const List<String> fittingStandards = [
    'ORFS', 'BSP', 'NPT', 'JIC', 'Metric', 'SAE_F61', 'SAE_F62'
  ];

  // Fitting angles
  static const List<String> fittingAngles = [
    'straight', '45', '90', '90_long'
  ];

  // Fitting gender
  static const List<String> fittingGenders = ['male', 'female'];
}