import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../cache/page_cache.dart';
import '../constants/app_constants.dart';

class ApiClient {
  static Dio? _dio;
  static bool _isRefreshing = false;
  static const _storage = FlutterSecureStorage();
  static String? _cachedToken;
  static String _cachedRole = '';

  static Dio get instance {
    _dio ??= _createDio();
    return _dio!;
  }

  static String get cachedRole => _cachedRole;

  static void cacheToken(String token) => _cachedToken = token;
  static void cacheRole(String role)   => _cachedRole  = role;

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token =
            _cachedToken ?? await _storage.read(key: AppConstants.accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final is401     = error.response?.statusCode == 401;
        final isRefresh = error.requestOptions.path.contains('/auth/refresh');

        if (is401 && !isRefresh && !_isRefreshing) {
          _isRefreshing = true;
          try {
            final refreshToken =
                await _storage.read(key: AppConstants.refreshTokenKey);
            if (refreshToken == null) throw Exception('no refresh token');

            final refreshDio = Dio(BaseOptions(
              baseUrl: AppConstants.baseUrl,
              headers: {'Content-Type': 'application/json'},
            ));
            final res = await refreshDio.post(
              '/auth/refresh',
              data: {'refresh_token': refreshToken},
            );

            final newToken = res.data['data']['access_token'] as String;
            _cachedToken = newToken;
            await _storage.write(
                key: AppConstants.accessTokenKey, value: newToken);

            error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final retried = await _dio!.fetch(error.requestOptions);
            return handler.resolve(retried);
          } catch (_) {
            _cachedToken = null;
            _cachedRole  = '';
            PageCache.clearAll();
            await _storage.deleteAll();
            _dio = null;
          } finally {
            _isRefreshing = false;
          }
        }

        return handler.next(error);
      },
    ));

    return dio;
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    _cachedRole  = '';
    PageCache.clearAll();
    await _storage.deleteAll();
    _dio = null;
  }
}
