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
  static Future<Map<String, String>> _headers() async {
    final token = await AppConfig.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<String> _base() async {
    final url = await AppConfig.getBaseUrl();
    if (url == null || url.isEmpty) throw ApiException('Server sozlanmagan');
    return url;
  }

  static Future<dynamic> get(String path) async {
    try {
      final base = await _base();
      final headers = await _headers();
      final res = await http
          .get(Uri.parse('$base/api/$path'), headers: headers)
          .timeout(const Duration(seconds: 12));
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
      final base = await _base();
      final headers = await _headers();
      final res = await http
          .post(Uri.parse('$base/api/$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));
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
      final base = await _base();
      final headers = await _headers();
      final res = await http
          .put(Uri.parse('$base/api/$path'),
              headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));
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