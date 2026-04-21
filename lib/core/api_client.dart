import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: 'refresh_token', value: token);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'remember_me');
  }

  Future<Map<String, String>> _headers({bool authRequired = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${ApiConfig.staticToken}',
    };

    if (authRequired) {
      final token = await getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['X-Access-Token'] = token;
      }
    }

    return headers;
  }

  Uri _uri(String endpoint, [Map<String, dynamic>? queryParams]) {
    final fullUrl = endpoint.startsWith('http')
        ? endpoint
        : '${ApiConfig.baseUrl}$endpoint';

    return Uri.parse(fullUrl).replace(
      queryParameters: queryParams?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final response = await http.post(
      Uri.parse(ApiConfig.refresh),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${ApiConfig.staticToken}',
      },
      body: jsonEncode({
        'refresh_token': refreshToken,
      }),
    );

    final body = response.body.trim();

    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
      return false;
    }

    late final dynamic decoded;
    try {
      decoded = body.isNotEmpty ? jsonDecode(body) : {};
    } on FormatException {
      final preview = body.length > 160 ? '${body.substring(0, 160)}...' : body;
      throw Exception(
        'Server returned non-JSON response. Check your API file/path. Status: ${response.statusCode}. Body: $preview',
      );
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is Map<String, dynamic> &&
        decoded['success'] == true &&
        decoded['access_token'] != null) {
      await saveAccessToken(decoded['access_token'].toString());
      return true;
    }

    return false;
  }

  Future<dynamic> get(
    String endpoint, {
    bool authRequired = false,
    Map<String, dynamic>? queryParams,
  }) async {
    http.Response response = await http.get(
      _uri(endpoint, queryParams),
      headers: await _headers(authRequired: authRequired),
    );

    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await http.get(
          _uri(endpoint, queryParams),
          headers: await _headers(authRequired: authRequired),
        );
      }
    }

    return _handleResponse(response);
  }

  Future<dynamic> post(
    String endpoint, {
    bool authRequired = false,
    Map<String, dynamic>? body,
  }) async {
    http.Response response = await http.post(
      _uri(endpoint),
      headers: await _headers(authRequired: authRequired),
      body: jsonEncode(body ?? {}),
    );

    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await http.post(
          _uri(endpoint),
          headers: await _headers(authRequired: authRequired),
          body: jsonEncode(body ?? {}),
        );
      }
    }

    return _handleResponse(response);
  }

  Future<dynamic> put(
    String endpoint, {
    bool authRequired = false,
    Map<String, dynamic>? body,
  }) async {
    http.Response response = await http.put(
      _uri(endpoint),
      headers: await _headers(authRequired: authRequired),
      body: jsonEncode(body ?? {}),
    );

    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await http.put(
          _uri(endpoint),
          headers: await _headers(authRequired: authRequired),
          body: jsonEncode(body ?? {}),
        );
      }
    }

    return _handleResponse(response);
  }

  Future<dynamic> delete(
    String endpoint, {
    bool authRequired = false,
    Map<String, dynamic>? body,
  }) async {
    http.Request request = http.Request('DELETE', _uri(endpoint));
    request.headers.addAll(await _headers(authRequired: authRequired));
    request.body = jsonEncode(body ?? {});

    http.StreamedResponse streamed = await request.send();
    http.Response response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        request = http.Request('DELETE', _uri(endpoint));
        request.headers.addAll(await _headers(authRequired: authRequired));
        request.body = jsonEncode(body ?? {});

        streamed = await request.send();
        response = await http.Response.fromStream(streamed);
      }
    }

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final body = response.body.trim();

    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
      throw Exception(
        'Server returned HTML instead of JSON. Check your API path. Status: ${response.statusCode}',
      );
    }

    final dynamic decoded = body.isNotEmpty ? jsonDecode(body) : {};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded is Map<String, dynamic>
        ? (decoded['message'] ?? 'Request failed')
        : 'Request failed';

    throw Exception(message.toString());
  }

  Future<bool> refreshAccessTokenPublic() async {
    return await _refreshAccessToken();
  }
}
