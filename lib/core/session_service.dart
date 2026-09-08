import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'user_session.dart';

class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();
  static const _sessionKey = 'authenticated_user_session';

  UserSession? _current;

  UserSession? get current => _current;

  Future<UserSession?> restore() async {
    if (_current != null) return _current;

    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_sessionKey);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      _current = UserSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
      return _current;
    } on Object {
      await preferences.remove(_sessionKey);
      return null;
    }
  }

  Future<UserSession> saveAuthResponse(Map<String, dynamic> response) async {
    final session = UserSession.fromAuthResponse(response);
    await save(session);
    return session;
  }

  Future<void> save(UserSession session) async {
    _current = session;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> updateUser(Map<String, dynamic> user) async {
    final existing = _current ?? await restore();
    if (existing == null) return;
    await save(existing.mergeUser(user));
  }

  Future<void> clear() async {
    _current = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
