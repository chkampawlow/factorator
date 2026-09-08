class AuthCookieParser {
  const AuthCookieParser._();

  static const _cookieStorageKeys = {
    'ef_access': 'access_token',
    'ef_refresh': 'refresh_token',
  };

  static Map<String, String> parse(String? setCookieHeader) {
    if (setCookieHeader == null || setCookieHeader.isEmpty) return const {};

    final result = <String, String>{};
    for (final entry in _cookieStorageKeys.entries) {
      final match = RegExp(
        '(?:^|,\\s*)${entry.key}=([^;,]+)',
      ).firstMatch(setCookieHeader);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        result[entry.value] = value;
      }
    }
    return result;
  }
}
