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

  // Asosiy so'rov + ulanmasa local URL ga fallback
  static Future<http.Response> _send(
      Future<http.Response> Function(String base) request) async {
    final primary = await AppConfig.getBaseUrl();
    final local   = await AppConfig.getLocalUrl();

    // Aktiv URL belgilangan bo'lsa — to'g'ri ishlatamiz
    if (_activeBase != null) {
      try {
        return await request(_activeBase!);
      } on SocketException {
        // Aktiv URL ishlamay qoldi — qayta urinib ko'ramiz
        _activeBase = null;
      } on Exception {
        rethrow;
      }
    }

    // Asosiy URL ga urinish (qisqaroq timeout — tez aniqlash uchun)
    try {
      final res = await request(primary)
          .timeout(const Duration(seconds: 5));
      _activeBase = primary;
      return res;
    } on Exception {
      // Asosiy URL ishlamasa va local URL mavjud bo'lsa — fallback
      if (local != null && local.isNotEmpty) {
        try {
          final res = await request(local)
              .timeout(const Duration(seconds: 8));
          _activeBase = local;
          return res;
        } on SocketException {
          throw ApiException('Server bilan ulanib bo\'lmadi (online: $primary, offline: $local)');
        }
      }
      throw ApiException('Server bilan ulanib bo\'lmadi');
    }
  }

  static Future<dynamic> get(String path) async {
    try {
      final headers = await _headers();
      final res = await _send((base) =>
          http.get(Uri.parse('$base/api/$path'), headers: headers));
      return _parse(res);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException('Server bilan ulanib bo\'lmadi');
    } catch (e) {
      throw ApiException('Xatolik: $e');
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
      throw ApiException('Server bilan ulanib bo\'lmadi');
    } catch (e) {
      throw ApiException('Xatolik: $e');
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
      throw ApiException('Server bilan ulanib bo\'lmadi');
    } catch (e) {
      throw ApiException('Xatolik: $e');
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
}