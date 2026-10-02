import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/system_alert.dart';
import 'alert_repository.dart';
import 'auth_service.dart';

class AlertService implements AlertRepository {
  AlertService({
    http.Client? client,
    FlutterSecureStorage? storage,
    String baseUrl = ApiConfig.baseUrl,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  static const _accessTokenKey = 'rmutt_access_token';
  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _baseUrl;

  @override
  Future<List<SystemAlert>> fetchAlerts({int limit = 30}) async {
    final data = await _request('GET', '/alerts?limit=$limit');
    final values = data['alerts'];
    if (values is! List) {
      throw const ApiException('The server returned invalid alert data.');
    }
    return values
        .whereType<Map<String, dynamic>>()
        .map(SystemAlert.fromJson)
        .toList();
  }

  @override
  Future<SystemAlert> acknowledge(String id) async {
    final data = await _request('POST', '/alerts/$id/acknowledge');
    final value = data['alert'];
    if (value is! Map<String, dynamic>) {
      throw const ApiException('The server returned invalid alert data.');
    }
    return SystemAlert.fromJson(value);
  }

  Future<Map<String, dynamic>> _request(String method, String path) async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null || token.isEmpty) {
      throw const ApiException('Please sign in again.', statusCode: 401);
    }
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        });
      final streamed = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) data = decoded;
        } catch (_) {
          // ข้อความที่ไม่ใช่ JSON จะตกไปใช้ข้อความสำรองด้านล่าง
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          data['message'] as String? ?? 'The server returned an error.',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Could not connect to the server. Check API_BASE_URL.',
      );
    }
  }
}
