import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const _keyBaseUrl   = 'base_url';
  static const _keyTenantId  = 'tenant_id';
  static const _keyToken     = 'token';
  static const _keyUserName  = 'user_name';
  static const _keyUserRole  = 'user_role';
  static const _keyUserId    = 'user_id';

  static Future<String?> getBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyBaseUrl);
  }

  static Future<void> setBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await p.setString(_keyBaseUrl, clean);
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

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyToken);
    await p.remove(_keyUserName);
    await p.remove(_keyUserRole);
    await p.remove(_keyUserId);
  }

  static Future<bool> isConfigured() async {
    final url = await getBaseUrl();
    return url != null && url.isNotEmpty;
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}