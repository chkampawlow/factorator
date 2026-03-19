import 'package:shared_preferences/shared_preferences.dart';

class ApiBaseUrlService {
  static const String _key = 'api_base_url';

  static const String defaultBaseUrl =
      'https://deployment-airfare-insights-regulations.trycloudflare.com/ready';

  Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);

    if (saved == null || saved.trim().isEmpty) {
      return defaultBaseUrl;
    }

    return _normalize(saved);
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _normalize(url));
  }

  String _normalize(String url) {
    var value = url.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}