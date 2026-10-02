import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/provisioning.dart';
import 'auth_service.dart';
import 'occupancy_sensor_repository.dart';

class OccupancySensorService implements OccupancySensorRepository {
  OccupancySensorService({
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
  Future<OccupancyProvisioningReservation> reserve(
    OccupancyProvisioningRequest request,
  ) async {
    final data = await _request(
      'POST',
      '/occupancy-sensors/reservations',
      body: request.toReservationJson(),
    );
    final value = data['reservation'];
    if (value is! Map<String, dynamic>) {
      throw const ApiException('The server returned an invalid reservation.');
    }
    return OccupancyProvisioningReservation.fromJson(value);
  }

  @override
  Future<void> enterSetupMode(String deviceId) async {
    await _request('POST', '/occupancy-sensors/$deviceId/setup-mode');
  }

  @override
  Future<void> remove(String deviceId) async {
    await _request('DELETE', '/occupancy-sensors/$deviceId');
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
        // The readable fallback below handles a non-JSON server response.
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
