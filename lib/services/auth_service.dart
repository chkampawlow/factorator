import 'package:flutter/material.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/core/api_config.dart';
import 'package:my_app/core/session_service.dart';
import 'package:my_app/core/token_store.dart';

class AuthService {
  final TokenStore _storage = TokenStore.instance;
  final ApiClient _api = ApiClient.instance;
  final SessionService _sessions = SessionService.instance;

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
      if (data['requires_2fa'] == true) {
        debugPrint('2FA required, skipping token storage for now.');
        return data;
      }

      final accessToken =
          (data['access_token'] ?? await _storage.read('access_token') ?? '')
              .toString();
      final refreshToken =
          (data['refresh_token'] ?? await _storage.read('refresh_token') ?? '')
              .toString();

      debugPrint('Access token exists: ${accessToken.isNotEmpty}');
      debugPrint('Refresh token exists: ${refreshToken.isNotEmpty}');

      if (accessToken.isEmpty || refreshToken.isEmpty) {
        debugPrint('Missing tokens in response');
        throw Exception('Missing authentication tokens');
      }

      debugPrint('Writing access_token to secure storage...');
      await _storage.write('access_token', accessToken);

      debugPrint('Writing refresh_token to secure storage...');
      await _storage.write('refresh_token', refreshToken);

      debugPrint('Writing remember_me to secure storage...');
      await _storage.write('remember_me', rememberMe ? 'true' : 'false');
      await _sessions.saveAuthResponse(data);

      debugPrint('--- AuthService.login SUCCESS ---');
      return data;
    }

    debugPrint('AuthService.login failed: ${data['message']}');
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<String?> getAccessToken() async {
    return await _storage.read('access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read('refresh_token');
  }

  Future<bool> shouldAutoLogin() async {
    final accessToken = await _storage.read('access_token');
    final rememberMe = await _storage.read('remember_me');

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
    bool isFodec = false,
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
        'fodec': isFodec ? 1 : 0,
        'is_fodec': isFodec,
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
      final user = Map<String, dynamic>.from(data['user'] as Map);
      final existing = _sessions.current ?? await _sessions.restore();
      if (existing == null) {
        await _sessions.saveAuthResponse({
          ...data,
          'user': user,
          'permissions': data['permissions'] ?? user['permissions'] ?? [],
        });
      } else {
        final membership = data['membership'] ??
            {
              'id': existing.membershipId,
              'tenant_id': existing.tenantId,
              'company_id': existing.companyId,
              'role': existing.role,
              'status': existing.membershipStatus,
            };
        await _sessions.saveAuthResponse({
          ...data,
          'user': {...existing.user, ...user},
          'company': data['company'] ?? existing.company,
          'membership': membership,
          'permissions': data['permissions'] ??
              user['permissions'] ??
              existing.permissions.toList(),
        });
      }
      return user;
    }

    throw Exception(data['message'] ?? 'Invalid session');
  }

  Future<void> logout() async {
    await _api.clearTokens();
  }

  Future<void> sendVerificationEmail(String language) async {
    await _api.post(
      ApiConfig.sendVerificationEmail,
      authRequired: true,
      body: {
        'language': language,
      },
    );
  }

  Future<void> verifyEmail(String code) async {
    await _api.post(
      ApiConfig.verifyEmail,
      authRequired: true,
      body: {
        'code': code,
      },
    );
  }

  Future<void> forgotPassword(String email, String language) async {
    await _api.post(
      ApiConfig.forgotPassword,
      body: {
        'email': email,
        'language': language,
      },
    );
  }

  Future<Map<String, dynamic>> verify2faLogin({
    required String email,
    required String code,
    required bool rememberMe,
  }) async {
    final Map<String, dynamic> data = await _api.post(
      ApiConfig.verify2faLogin,
      body: {
        'email': email,
        'code': code,
        'remember_me': rememberMe,
      },
    ) as Map<String, dynamic>;

    if (data['success'] == true) {
      final accessToken =
          (data['access_token'] ?? await _storage.read('access_token') ?? '')
              .toString();
      final refreshToken =
          (data['refresh_token'] ?? await _storage.read('refresh_token') ?? '')
              .toString();

      if (accessToken.isEmpty || refreshToken.isEmpty) {
        throw Exception('Missing authentication tokens');
      }

      await _storage.write('access_token', accessToken);
      await _storage.write('refresh_token', refreshToken);
      await _storage.write('remember_me', rememberMe ? 'true' : 'false');
      await _sessions.saveAuthResponse(data);

      return data;
    }

    throw Exception(data['message'] ?? '2FA verification failed');
  }

  Future<void> resetPassword(String code, String password) async {
    await _api.post(
      ApiConfig.resetPassword,
      body: {
        'code': code,
        'password': password,
      },
    );
  }

  Future<void> confirm2fa(String code) async {
    final Map<String, dynamic> data = await _api.post(
      ApiConfig.confirm2fa,
      authRequired: true,
      body: {
        'code': code,
      },
    ) as Map<String, dynamic>;

    if (data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Failed to confirm 2FA');
  }

  Future<Map<String, dynamic>> enable2fa() async {
    final Map<String, dynamic> data = await _api.post(
      ApiConfig.enable2fa,
      authRequired: true,
    ) as Map<String, dynamic>;

    if (data['success'] == true) {
      return data;
    }

    throw Exception(data['message'] ?? 'Failed to initialize 2FA');
  }

  Future<void> disable2fa(String code) async {
    final Map<String, dynamic> data = await _api.post(
      ApiConfig.disable2fa,
      authRequired: true,
      body: {
        'code': code,
      },
    ) as Map<String, dynamic>;

    if (data['success'] == true) {
      return;
    }

    throw Exception(data['message'] ?? 'Failed to disable 2FA');
  }

  Future<bool> get2faStatus() async {
    final Map<String, dynamic> data = await _api.get(
      ApiConfig.twofaStatus,
      authRequired: true,
    ) as Map<String, dynamic>;

    if (data['success'] == true) {
      return data['enabled'] == true;
    }

    throw Exception(data['message'] ?? 'Failed to fetch 2FA status');
  }
}
