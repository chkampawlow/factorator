import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    debugPrint('--- AuthService.login START ---');
    debugPrint('Email: $email');
    debugPrint('Remember me: $rememberMe');

    final Map<String, dynamic> data = await _api.post(
      ApiConfig.login,
      body: {
        'email': email,
        'password': password,
        'remember_me': rememberMe,
      },
    ) as Map<String, dynamic>;

    debugPrint('AuthService.login response: $data');

    if (data['success'] == true) {
      final accessToken = (data['access_token'] ?? '').toString();
      final refreshToken = (data['refresh_token'] ?? '').toString();

      debugPrint('Access token exists: ${accessToken.isNotEmpty}');
      debugPrint('Refresh token exists: ${refreshToken.isNotEmpty}');

      if (accessToken.isEmpty || refreshToken.isEmpty) {
        debugPrint('Missing tokens in response');
        throw Exception('Missing authentication tokens');
      }

      debugPrint('Writing access_token to secure storage...');
      await _storage.write(key: 'access_token', value: accessToken);

      debugPrint('Writing refresh_token to secure storage...');
      await _storage.write(key: 'refresh_token', value: refreshToken);

      debugPrint('Writing remember_me to secure storage...');
      await _storage.write(
        key: 'remember_me',
        value: rememberMe ? 'true' : 'false',
      );

      debugPrint('--- AuthService.login SUCCESS ---');
      return data;
    }

    debugPrint('AuthService.login failed: ${data['message']}');
    throw Exception(data['message'] ?? 'Login failed');
  }


  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  Future<bool> shouldAutoLogin() async {
    final accessToken = await _storage.read(key: 'access_token');
    final rememberMe = await _storage.read(key: 'remember_me');

    return accessToken != null &&
        accessToken.isNotEmpty &&
        rememberMe == 'true';
  }

  Future<bool> refreshAccessToken() async {
    return await _api.refreshAccessTokenPublic();
  }

  Future<Map<String, dynamic>> signup({
    required String organizationName,
    required String fiscalId,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      ApiConfig.signup,
      body: {

        'organization_name': organizationName,
        'fiscal_id': fiscalId,
        'email': email,
        'phone': phone,
        'password': password,
        'confirm_password': confirmPassword,
      },
    ) as Map<String, dynamic>;

    if (data['success'] == true) {
      return data;
    }

    throw Exception(data['message'] ?? 'Signup failed');
  }
  Future<Map<String, dynamic>> me() async {
  final Map<String, dynamic> data = await _api.get(
    ApiConfig.me,
    authRequired: true,
  ) as Map<String, dynamic>;

  if (data['success'] == true) {
    return Map<String, dynamic>.from(data['user'] as Map);
  }

  throw Exception(data['message'] ?? 'Invalid session');
}

  Future<void> logout() async {
    await _api.clearTokens();
  }
  
}