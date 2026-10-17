import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'system_settings_repository.dart';

class SystemSettingsService implements SystemSettingsRepository {
  SystemSettingsService({
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
  Future<SystemSettings> fetchSettings() async {
    return SystemSettings.fromJson(await _request('GET', '/settings'));
  }

  @override
  Future<SystemSettings> setAutoOffEnabled(bool enabled) async {
    return SystemSettings.fromJson(
      await _request(
        'PATCH',
        '/settings/auto-off',
        body: {'enabled': enabled},
      ),
    );
  }

  @override
  Future<SystemSettings> setAutoOffTestMode(bool testMode) async {
    return SystemSettings.fromJson(
      await _request(
        'PATCH',
        '/settings/auto-off',
        body: {'testMode': testMode},
      ),
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null || token.isEmpty) {
      throw const ApiException('Please sign in again.', statusCode: 401);
    }
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          if (body != null) 'Content-Type': 'application/json',
        });
      if (body != null) request.body = jsonEncode(body);

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
