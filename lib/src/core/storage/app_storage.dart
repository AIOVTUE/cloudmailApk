import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  AppStorage(this._prefs, this._secureStorage);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  static const tokenKey = 'auth.token';
  static const rememberKey = 'auth.remember';
  static const siteUrlKey = 'auth.siteUrl';
  static const emailKey = 'auth.email';
  static const draftKey = 'mail.localDraft';
  static const inboxCacheKey = 'mail.inbox.cache';
  static const sentCacheKey = 'mail.sent.cache';
  static const themeModeKey = 'ui.themeMode';
  static const themeConfigKey = 'ui.themeConfig';
  static const navVisibilityKey = 'ui.navVisibility';

  static Future<AppStorage> build() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    return AppStorage(prefs, secureStorage);
  }

  Future<void> saveToken(String token) => _secureStorage.write(key: tokenKey, value: token);
  Future<String?> readToken() => _secureStorage.read(key: tokenKey);
  Future<void> clearToken() => _secureStorage.delete(key: tokenKey);

  bool get rememberMe => _prefs.getBool(rememberKey) ?? false;
  Future<void> setRememberMe(bool value) => _prefs.setBool(rememberKey, value);

  String get siteUrl => _prefs.getString(siteUrlKey) ?? '';
  Future<void> setSiteUrl(String value) => _prefs.setString(siteUrlKey, value);

  String get email => _prefs.getString(emailKey) ?? '';
  Future<void> setEmail(String value) => _prefs.setString(emailKey, value);

  String? get draft => _prefs.getString(draftKey);
  Future<void> setDraft(Map<String, dynamic> draft) => _prefs.setString(draftKey, jsonEncode(draft));
  Future<void> clearDraft() => _prefs.remove(draftKey);

  List<Map<String, dynamic>> readMailCache(bool isInbox) {
    final raw = _prefs.getString(isInbox ? inboxCacheKey : sentCacheKey);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list;
  }

  Future<void> writeMailCache(bool isInbox, List<Map<String, dynamic>> list) =>
      _prefs.setString(isInbox ? inboxCacheKey : sentCacheKey, jsonEncode(list));

  String get themeMode => _prefs.getString(themeModeKey) ?? 'system';
  Future<void> setThemeMode(String mode) => _prefs.setString(themeModeKey, mode);

  Map<String, dynamic>? get themeConfig {
    final raw = _prefs.getString(themeConfigKey);
    if (raw == null || raw.isEmpty) return null;
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  Future<void> setThemeConfig(Map<String, dynamic> config) => _prefs.setString(themeConfigKey, jsonEncode(config));

  Map<String, dynamic>? get navVisibility {
    final raw = _prefs.getString(navVisibilityKey);
    if (raw == null || raw.isEmpty) return null;
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  Future<void> setNavVisibility(Map<String, dynamic> config) =>
      _prefs.setString(navVisibilityKey, jsonEncode(config));

  Future<void> clearAllLocalData() async {
    await _secureStorage.deleteAll();
    await _prefs.clear();
  }
}
