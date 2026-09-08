import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  TokenStore._();

  static final TokenStore instance = TokenStore._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool get _usePreferencesFallback => !kIsWeb && Platform.isMacOS;

  Future<String?> read(String key) async {
    if (_usePreferencesFallback) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }

    return _secureStorage.read(key: key);
  }

  Future<void> write(String key, String value) async {
    if (_usePreferencesFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }

    await _secureStorage.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    if (_usePreferencesFallback) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }

    await _secureStorage.delete(key: key);
  }
}
