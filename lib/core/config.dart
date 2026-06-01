import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // Markaziy server manzili — nginx port 80 orqali
  static const centralUrl = 'http://192.168.35.230';

  static const _keyBaseUrl   = 'base_url';
  static const _keyTenantId  = 'tenant_id';
  static const _keyToken     = 'token';
  static const _keyUserName  = 'user_name';
  static const _keyUserRole  = 'user_role';
  static const _keyUserId    = 'user_id';
  static const _keyCafeCode  = 'cafe_code';
  static const _keyCafeName  = 'cafe_name';

  static Future<String> getBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_keyBaseUrl);
    return (saved != null && saved.isNotEmpty) ? saved : centralUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await p.setString(_keyBaseUrl, clean);
  }

  static Future<void> resetToDefault() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyBaseUrl);
  }

  static Future<bool> isUsingCustomUrl() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_keyBaseUrl);
    return saved != null && saved.isNotEmpty && saved != centralUrl;
  }

  static Future<int> getTenantId() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyTenantId) ?? 1;
  }

  static Future<void> setTenantId(int id) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyTenantId, id);
  }

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyToken);
  }

  static Future<void> setToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyToken, token);
  }

  static Future<void> saveUser(int id, String name, String role) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyUserId, id);
    await p.setString(_keyUserName, name);
    await p.setString(_keyUserRole, role);
  }

  static Future<String?> getUserName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyUserName);
  }

  static Future<String?> getUserRole() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyUserRole);
  }

  static Future<int> getUserId() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyUserId) ?? 0;
  }

  static Future<String?> getCafeCode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyCafeCode);
  }

  static Future<String?> getCafeName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyCafeName);
  }

  static Future<void> saveCafe(String code, String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyCafeCode, code);
    await p.setString(_keyCafeName, name);
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyToken);
    await p.remove(_keyUserName);
    await p.remove(_keyUserRole);
    await p.remove(_keyUserId);
    // cafeCode va cafeName saqlab qolamiz — qayta kirish osonroq
  }

  static Future<bool> isConfigured() async => true; // centralUrl har doim bor

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}