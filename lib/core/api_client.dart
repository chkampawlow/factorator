import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_exception.dart';
import 'api_config.dart';
import 'api_collection.dart';
import 'auth_cookie_parser.dart';
import 'session_service.dart';
import 'token_store.dart';

extension _ApiRequestFuture<T> on Future<T> {
  Future<T> withApiErrors(Duration timeout) async {
    try {
      return await this.timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        message: 'The server took too long to respond. Please try again.',
        statusCode: 0,
        code: 'NETWORK_TIMEOUT',
      );
    } on http.ClientException {
      throw const ApiException(
        message:
            'Unable to reach the server. Check your connection and try again.',
        statusCode: 0,
        code: 'NETWORK_UNAVAILABLE',
      );
    }
  }
}

class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(
    super.method,
    super.url,
    this.onProgress,
  );

  final void Function(int sent, int total)? onProgress;

  @override
  http.ByteStream finalize() {
    final stream = super.finalize();
    final total = contentLength;
    var sent = 0;
    onProgress?.call(0, total);
    return http.ByteStream(
      stream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (chunk, sink) {
            sent += chunk.length;
            onProgress?.call(sent, total);
            sink.add(chunk);
          },
        ),
      ),
    );
  }
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();
  static const Duration _requestTimeout = Duration(seconds: 25);
  final TokenStore _storage = TokenStore.instance;
  Future<bool>? _refreshInFlight;

  Future<String?> getAccessToken() async {
    return await _storage.read('access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read('refresh_token');
  }

  Future<void> saveAccessToken(String token) async {
    await _storage.write('access_token', token);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write('refresh_token', token);
  }

  Future<void> clearTokens() async {
    await _storage.delete('access_token');
    await _storage.delete('refresh_token');
    await _storage.delete('remember_me');
    await SessionService.instance.clear();
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
        headers['Cookie'] = 'ef_access=$token';
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
    final activeRefresh = _refreshInFlight;
    if (activeRefresh != null) return activeRefresh;

    final operation = _performRefreshAccessToken();
    _refreshInFlight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _performRefreshAccessToken() async {
    final refreshToken = await getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final response = await http
        .post(
          Uri.parse(ApiConfig.refresh),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ${ApiConfig.staticToken}',
            'Cookie': 'ef_refresh=$refreshToken',
          },
          body: jsonEncode({
            'refresh_token': refreshToken,
          }),
        )
        .withApiErrors(_requestTimeout);

    await _captureAuthCookies(response);

    if (response.statusCode == 401 || response.statusCode == 403) {
      await clearTokens();
      return false;
    }

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
        decoded['success'] == true) {
      final responseToken = decoded['access_token']?.toString();
      if (responseToken != null && responseToken.isNotEmpty) {
        await saveAccessToken(responseToken);
      }
      return (await getAccessToken())?.isNotEmpty == true;
    }

    return false;
  }

  Future<dynamic> get(
    String endpoint, {
    bool authRequired = false,
    Map<String, dynamic>? queryParams,
  }) async {
    http.Response response = await http
        .get(
          _uri(endpoint, queryParams),
          headers: await _headers(authRequired: authRequired),
        )
        .withApiErrors(_requestTimeout);
    await _captureAuthCookies(response);

    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await http
            .get(
              _uri(endpoint, queryParams),
              headers: await _headers(authRequired: authRequired),
            )
            .withApiErrors(_requestTimeout);
        await _captureAuthCookies(response);
      }
    }

    return _handleResponse(response);
  }

  Future<Uint8List> getPdf(
    String endpoint, {
    bool authRequired = true,
    Map<String, dynamic>? queryParams,
  }) async {
    Future<http.Response> send() async => http
        .get(
          _uri(endpoint, queryParams),
          headers: await _headers(authRequired: authRequired),
        )
        .withApiErrors(_requestTimeout);

    var response = await send();
    await _captureAuthCookies(response);
    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await send();
        await _captureAuthCookies(response);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _handleResponse(response);
    }
    final bytes = response.bodyBytes;
    final hasPdfSignature = bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
    if (!hasPdfSignature) {
      throw Exception('Server returned an invalid PDF document.');
    }
    return Uint8List.fromList(bytes);
  }

  /// Loads all available pages from the backend's standard paginated list
  /// contract. [maxPages] is a defensive ceiling, not the normal page count.
  Future<List<Map<String, dynamic>>> getAllPages(
    String endpoint, {
    required String resourceName,
    Iterable<String> keys = const ['data', 'items', 'results'],
    Map<String, dynamic>? queryParams,
    int maxPages = 1000,
  }) async {
    const pageSize = 100;
    return ApiCollection.collectPages(
      fetchPage: (page, requestedPageSize) => get(
        endpoint,
        authRequired: true,
        queryParams: {
          ...?queryParams,
          'page': page,
          'page_size': requestedPageSize,
        },
      ),
      keys: keys,
      resourceName: resourceName,
      pageSize: pageSize,
      maxPages: maxPages.clamp(1, 1000),
    );
  }

  Future<dynamic> post(
    String endpoint, {
    bool authRequired = false,
    Map<String, dynamic>? body,
  }) async {
    http.Response response = await http
        .post(
          _uri(endpoint),
          headers: await _headers(authRequired: authRequired),
          body: jsonEncode(body ?? {}),
        )
        .withApiErrors(_requestTimeout);
    await _captureAuthCookies(response);

    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await http
            .post(
              _uri(endpoint),
              headers: await _headers(authRequired: authRequired),
              body: jsonEncode(body ?? {}),
            )
            .withApiErrors(_requestTimeout);
        await _captureAuthCookies(response);
      }
    }

    return _handleResponse(response);
  }

  Future<dynamic> put(
    String endpoint, {
    bool authRequired = false,
    Map<String, dynamic>? body,
  }) async {
    http.Response response = await http
        .put(
          _uri(endpoint),
          headers: await _headers(authRequired: authRequired),
          body: jsonEncode(body ?? {}),
        )
        .withApiErrors(_requestTimeout);
    await _captureAuthCookies(response);

    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        response = await http
            .put(
              _uri(endpoint),
              headers: await _headers(authRequired: authRequired),
              body: jsonEncode(body ?? {}),
            )
            .withApiErrors(_requestTimeout);
        await _captureAuthCookies(response);
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

    http.StreamedResponse streamed =
        await request.send().withApiErrors(_requestTimeout);
    http.Response response = await http.Response.fromStream(streamed);
    await _captureAuthCookies(response);

    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        request = http.Request('DELETE', _uri(endpoint));
        request.headers.addAll(await _headers(authRequired: authRequired));
        request.body = jsonEncode(body ?? {});

        streamed = await request.send().withApiErrors(_requestTimeout);
        response = await http.Response.fromStream(streamed);
        await _captureAuthCookies(response);
      }
    }

    return _handleResponse(response);
  }

  Future<dynamic> multipartPost(
    String endpoint, {
    required String fileField,
    required String filePath,
    Map<String, String> fields = const {},
    bool authRequired = true,
  }) {
    return multipartPostFiles(
      endpoint,
      fileField: fileField,
      filePaths: [filePath],
      fields: fields,
      authRequired: authRequired,
    );
  }

  Future<dynamic> multipartPostFiles(
    String endpoint, {
    required String fileField,
    required List<String> filePaths,
    Map<String, String> fields = const {},
    bool authRequired = true,
    Duration timeout = const Duration(minutes: 3, seconds: 15),
    void Function(int sent, int total)? onProgress,
  }) async {
    Future<http.Response> send() async {
      final request = _ProgressMultipartRequest(
        'POST',
        _uri(endpoint),
        onProgress,
      );
      final headers = await _headers(authRequired: authRequired);
      headers.remove('Content-Type');
      request.headers.addAll(headers);
      request.fields.addAll(fields);
      for (final filePath in filePaths) {
        request.files.add(
          await http.MultipartFile.fromPath(fileField, filePath),
        );
      }
      final streamed = await request.send().withApiErrors(timeout);
      final response = await http.Response.fromStream(streamed);
      await _captureAuthCookies(response);
      return response;
    }

    var response = await send();
    if (response.statusCode == 401 && authRequired) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) response = await send();
    }
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final body = response.body.trim();

    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
      throw ApiException(
        message: response.statusCode == 404
            ? 'This mobile API endpoint is not installed on the server.'
            : 'The server returned an unexpected response.',
        statusCode: response.statusCode,
        code: response.statusCode == 404
            ? 'ENDPOINT_NOT_FOUND'
            : 'INVALID_SERVER_RESPONSE',
        requestId: response.headers['x-request-id'],
      );
    }

    late final dynamic decoded;
    try {
      decoded = body.isNotEmpty ? jsonDecode(body) : {};
    } on FormatException {
      throw Exception(
        'Server returned an invalid JSON response. Status: ${response.statusCode}',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final envelope = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : const <String, dynamic>{};
    final rawMessage = envelope['message'] ??
        envelope['error'] ??
        envelope['detail'] ??
        envelope['title'];
    final message = rawMessage?.toString().trim();

    throw ApiException(
      message: message == null || message.isEmpty ? 'Request failed' : message,
      statusCode: response.statusCode,
      code: (envelope['code'] ?? envelope['error_code'])?.toString(),
      requestId: (envelope['request_id'] ?? response.headers['x-request-id'])
          ?.toString(),
    );
  }

  Future<void> _captureAuthCookies(http.Response response) async {
    final tokens = AuthCookieParser.parse(response.headers['set-cookie']);
    final accessToken = tokens['access_token'];
    final refreshToken = tokens['refresh_token'];
    if (accessToken != null) {
      await saveAccessToken(accessToken);
    }
    if (refreshToken != null) {
      await saveRefreshToken(refreshToken);
    }
  }

  Future<bool> refreshAccessTokenPublic() async {
    return await _refreshAccessToken();
  }
}
