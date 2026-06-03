import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class Api {
  // Joriy sessiyada ishlatilayotgan aktiv URL (null = hali aniqlanmagan)
  static String? _activeBase;

  static Future<Map<String, String>> _headers() async {
    final token = await AppConfig.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Aktiv bazani qaytaradi: oldin saqlangan bo'lsa shu, aks holda primary
  static Future<String> _base() async {
    if (_activeBase != null) return _activeBase!;
    return await AppConfig.getBaseUrl();
  }

  static void resetActiveBase() => _activeBase = null;
  static String? get activeBaseUrl => _activeBase;

  // Asosiy serverga ulanish borligini tekshiradi (4 soniya)
  static Future<bool> isCloudReachable() async {
    try {
      final base  = await AppConfig.getBaseUrl();
      final clean = base.replaceAll(RegExp(r'/+$'), '');
      await http.get(Uri.parse('$clean/')).timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    }
  }

  // Mahalliy serverga ulanish borligini tekshiradi (4 soniya)
  static Future<bool> isLocalReachable() async {
    try {
      final local = await AppConfig.getLocalUrl();
      if (local == null || local.isEmpty) return false;
      final clean = local.replaceAll(RegExp(r'/+$'), '');
      await http.get(Uri.parse('$clean/')).timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    }
  }

  // Asosiy so'rov + ulanmasa local URL ga fallback
  static Future<http.Response> _send(
      Future<http.Response> Function(String base) request) async {
    // PRIMARY: foydalanuvchi sozlagan URL (yoki default centralUrl)
    // LOCAL:   ikkinchi fallback — WiFi orqali kompyuter IP
    final primary = await AppConfig.getBaseUrl();
    final local   = await AppConfig.getLocalUrl();

    // Aktiv URL belgilangan bo'lsa — to'g'ri ishlatamiz
    if (_activeBase != null) {
      try {
        return await request(_activeBase!)
            .timeout(const Duration(seconds: 10));
      } on SocketException {
        _activeBase = null; // ishlamay qoldi — qayta urinib ko'ramiz
      } on TimeoutException {
        _activeBase = null;
      } on ApiException {
        rethrow;
      }
    }

    // 1. Asosiy (cloud) URL ga urinish
    try {
      final res = await request(primary)
          .timeout(const Duration(seconds: 5));
      _activeBase = primary;
      return res;
    } on SocketException {
      // Ulanish rad etildi — local ga o'tamiz
    } on TimeoutException {
      // Timeout — local ga o'tamiz
    } on ApiException {
      rethrow;
    }

    // 2. Mahalliy (Wi-Fi) URL ga fallback
    if (local != null && local.isNotEmpty) {
      try {
        final res = await request(local)
            .timeout(const Duration(seconds: 6));
        _activeBase = local;
        return res;
      } on SocketException {
        throw ApiException(
            'Serverga ulanib bo\'lmadi.\nInternet yoki Wi-Fi ulanishini tekshiring.');
      } on TimeoutException {
        throw ApiException(
            'Server javob bermadi.\nInternet yoki Wi-Fi ulanishini tekshiring.');
      } on ApiException {
        rethrow;
      }
    }

    throw ApiException(
        'Serverga ulanib bo\'lmadi.\nInternet ulanishini tekshiring.');
  }

  // statusCode=null → connectivity muammosi (timeout/socket)
  // statusCode bor  → server javob berdi lekin xato (401, 404, 500...)
  static Future<dynamic> get(String path) async {
    try {
      final headers = await _headers();
      final res = await _send((base) =>
          http.get(Uri.parse('$base/api/$path'), headers: headers));
      return _parse(res);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Ulanib bo\'lmadi');       // statusCode=null
    } on TimeoutException {
      throw ApiException('Server javob bermadi');    // statusCode=null
    } catch (_) {
      throw ApiException('Ulanishda xatolik');       // statusCode=null
    }
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final res = await _send((base) =>
          http.post(Uri.parse('$base/api/$path'),
              headers: headers, body: jsonEncode(body)));
      return _parse(res);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Ulanib bo\'lmadi');
    } on TimeoutException {
      throw ApiException('Server javob bermadi');
    } catch (_) {
      throw ApiException('Ulanishda xatolik');
    }
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final res = await _send((base) =>
          http.put(Uri.parse('$base/api/$path'),
              headers: headers, body: jsonEncode(body)));
      return _parse(res);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Ulanib bo\'lmadi');
    } on TimeoutException {
      throw ApiException('Server javob bermadi');
    } catch (_) {
      throw ApiException('Ulanishda xatolik');
    }
  }

  static dynamic _parse(http.Response res) {
    if (res.statusCode == 401) throw ApiException('Kirish huquqi yo\'q', 401);
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = {};
    }
    if (res.statusCode >= 400) {
      throw ApiException(
          (data is Map ? data['message'] : null) ?? 'Xatolik yuz berdi',
          res.statusCode);
    }
    return data;
  }

  static Future<bool> testConnection(String baseUrl, int tenantId) async {
    try {
      final clean = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      final res = await http
          .get(Uri.parse('$clean/api/auth/setup-status?tenantId=$tenantId'))
          .timeout(const Duration(seconds: 6));
      return res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // Mahalliy tarmoq: xodimlar ro'yxatini olish (autentifikatsiyasiz)
  static Future<Map<String, dynamic>> getStaffList(String baseUrl) async {
    final clean = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final res = await http
          .get(Uri.parse('$clean/api/auth/staff-list'))
          .timeout(const Duration(seconds: 8));
      return _parse(res) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Serverga ulanib bo\'lmadi. IP manzilni tekshiring.');
    } on TimeoutException {
      throw ApiException('Server javob bermadi. IP manzilni tekshiring.');
    } catch (_) {
      throw ApiException('Ulanishda xatolik yuz berdi.');
    }
  }

  // Mahalliy tarmoq: to'g'ridan-to'g'ri login (berilgan URL ga)
  static Future<Map<String, dynamic>> loginDirect(
      String baseUrl, String login, String password, int tenantId) async {
    final clean = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final res = await http
          .post(
            Uri.parse('$clean/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'login': login,
              'password': password,
              'tenantId': tenantId,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return _parse(res) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Serverga ulanib bo\'lmadi.');
    } on TimeoutException {
      throw ApiException('Server javob bermadi.');
    } catch (_) {
      throw ApiException('Ulanishda xatolik.');
    }
  }

  // Mahalliy tarmoq: parolsiz tezkor kirish (faqat local IP dan ishlaydi)
  static Future<Map<String, dynamic>> quickLogin(
      String baseUrl, int userId, int tenantId) async {
    final clean = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final res = await http
          .post(
            Uri.parse('$clean/api/auth/quick-login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'tenantId': tenantId}),
          )
          .timeout(const Duration(seconds: 8));
      return _parse(res) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Ulanib bo\'lmadi.');
    } on TimeoutException {
      throw ApiException('Server javob bermadi.');
    } catch (_) {
      throw ApiException('Ulanishda xatolik.');
    }
  }
}