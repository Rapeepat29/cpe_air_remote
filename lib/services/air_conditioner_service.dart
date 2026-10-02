import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/air_conditioner.dart';
import '../models/provisioning.dart';
import 'air_conditioner_repository.dart';
import 'auth_service.dart';

class AirConditionerService implements AirConditionerRepository {
  AirConditionerService({
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
  Future<List<AirConditioner>> fetchAll() async {
    final data = await _request('GET', '/air-conditioners');
    final values = data['airConditioners'];
    if (values is! List) {
      throw const ApiException('The server returned invalid device data.');
    }
    return values
        .whereType<Map<String, dynamic>>()
        .map(AirConditioner.fromJson)
        .toList();
  }

  @override
  Future<AirProvisioningReservation> reserve(
    AirProvisioningRequest request,
  ) async {
    final data = await _request(
      'POST',
      '/air-conditioners/reservations',
      body: request.toReservationJson(),
    );
    final value = data['reservation'];
    if (value is! Map<String, dynamic>) {
      throw const ApiException('The server returned an invalid reservation.');
    }
    return AirProvisioningReservation.fromJson(value);
  }

  @override
  Future<void> sendCommand(AirConditioner air) async {
    final deviceId = air.deviceId;
    if (deviceId == null) {
      throw const ApiException('This air conditioner has no ESP32 Device ID.');
    }
    await _request(
      'POST',
      '/air-conditioners/$deviceId/command',
      body: air.toCommandJson(),
    );
  }

  @override
  Future<void> enterSetupMode(String deviceId) async {
    await _request(
      'POST',
      '/air-conditioners/$deviceId/setup-mode',
    );
  }

  @override
  Future<void> rename(String deviceId, String name) async {
    await _request(
      'PATCH',
      '/air-conditioners/$deviceId',
      body: {'name': name},
    );
  }

  @override
  Future<void> remove(String deviceId) {
    return _request('DELETE', '/air-conditioners/$deviceId');
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
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        });
      if (body != null) request.body = jsonEncode(body);

      final streamed = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
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

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {
        // The readable fallback below is used for non-JSON responses.
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message'] as String? ?? 'The server returned an error.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }
}
