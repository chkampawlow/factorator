import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _currencyKey = "currency";
  static const _languageKey = "language";

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

    // normalize to lowercase
    await prefs.setString(_languageKey, language.toLowerCase());
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    // normalize to lowercase
    return (prefs.getString(_languageKey) ?? "en").toLowerCase();
  }
}