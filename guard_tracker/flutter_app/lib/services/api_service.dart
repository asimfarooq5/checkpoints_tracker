import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = await _headers();

    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(ApiConfig.timeout);
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(ApiConfig.timeout);
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(ApiConfig.timeout);
          break;
        default:
          throw ApiException('Unsupported method: $method', 0);
      }
    } on SocketException {
      throw ApiException(
        'Cannot connect to server. Check that the backend is running and the IP is correct.',
        0,
      );
    } on TimeoutException {
      throw ApiException(
        'Connection timed out after ${ApiConfig.timeout.inSeconds}s. '
        'Verify the server is running at ${ApiConfig.baseUrl} and your device can reach it.',
        0,
      );
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', 0);
    }

    return response;
  }

  Future<dynamic> get(String path) async {
    final response = await _request('GET', path);
    return _handleResponse(response);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final response = await _request('POST', path, body: body);
    return _handleResponse(response);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final response = await _request('PATCH', path, body: body);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      deleteToken();
      throw AuthException('Session expired. Please login again.');
    }

    if (response.statusCode >= 400) {
      final decoded = _tryDecode(response.body);
      throw ApiException(
        decoded?['error'] ?? 'Request failed (${response.statusCode})',
        response.statusCode,
      );
    }

    return jsonDecode(response.body);
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
