import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _currencyKey = "currency";
  static const _languageKey = "language";
  static const _appColorKey = "app_color";

  Future<void> setCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, currency);
  }

  Future<String> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyKey) ?? "TND";
  }

  Future<void> setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.toLowerCase());
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? '';
  }

  Future<void> setAppColor(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_appColorKey, colorValue);
  }

  Future<int?> getAppColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_appColorKey);
  }
}