import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/energy_data.dart';
import 'auth_service.dart';
import 'energy_repository.dart';

class EnergyService implements EnergyRepository {
  EnergyService({
    http.Client? client,
    FlutterSecureStorage? storage,
    String baseUrl = ApiConfig.baseUrl,
  }) : _client = client ?? http.Client(),
       _storage = storage ?? const FlutterSecureStorage(),
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  static const _accessTokenKey = 'rmutt_access_token';
  static const _timeout = Duration(seconds: 20);

  // ไฟล์ Excel ใช้เวลาสร้างนานกว่าคำขอปกติ จึงให้เวลามากกว่า
  static const _downloadTimeout = Duration(seconds: 60);

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _baseUrl;

  @override
  Future<List<EnergyMetric>> fetchMetrics() async {
    final data = await _getJson('/energy/metrics');
    final values = data['metrics'];
    if (values is! List) {
      throw const ApiException(
        'The server returned an invalid list of values.',
      );
    }
    return values
        .whereType<Map<String, dynamic>>()
        .map(EnergyMetric.fromJson)
        .toList();
  }

  @override
  Future<EnergyLiveSnapshot> fetchLive() async {
    return EnergyLiveSnapshot.fromJson(await _getJson('/energy/live'));
  }

  @override
  Future<EnergySourceCatalog> fetchSources() async {
    return EnergySourceCatalog.fromJson(await _getJson('/energy/sources'));
  }

  @override
  Future<EnergySummary> fetchSummary({
    required EnergyPeriodKind kind,
    DateTime? from,
    DateTime? to,
    int? floor,
  }) async {
    final data = await _getJson(
      '/energy/summary',
      query: {
        'period': kind.apiValue,
        if (from != null) 'from': EnergyQuery.formatDate(from),
        if (to != null) 'to': EnergyQuery.formatDate(to),
        if (floor != null) 'floor': floor.toString(),
      },
    );
    return EnergySummary.fromJson(data);
  }

  @override
  Future<EnergyHistoryResult> fetchHistory(EnergyQuery query) async {
    final data = await _getJson(
      '/energy/history',
      query: query.toQueryParameters(),
    );
    return EnergyHistoryResult.fromJson(data);
  }

  @override
  Future<EnergyExportFile> downloadExport(
    EnergyQuery query, {
    bool english = false,
  }) async {
    final parameters = {
      ...query.toQueryParameters(),
      'language': english ? 'en' : 'th',
    };
    final response = await _send(
      'GET',
      '/energy/export',
      query: parameters,
      timeout: _downloadTimeout,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _messageFromBody(response.bodyBytes),
        statusCode: response.statusCode,
      );
    }

    return EnergyExportFile(
      fileName: _fileNameFrom(response.headers),
      bytes: Uint8List.fromList(response.bodyBytes),
      rowCount:
          int.tryParse(response.headers['x-export-rows'] ?? '') ?? 0,
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _send('GET', path, query: query);
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
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null || token.isEmpty) {
      throw const ApiException('Please sign in again.', statusCode: 401);
    }

    var uri = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }

    try {
      final request = http.Request(method, uri)
        ..headers.addAll({
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        });
      final streamed = await _client
          .send(request)
          .timeout(timeout ?? _timeout);
      return http.Response.fromStream(streamed);
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

  /// ชื่อไฟล์ไทยถูกเข้ารหัสมาในหัวข้อ HTTP จึงต้องถอดกลับก่อนใช้
  String _fileNameFrom(Map<String, String> headers) {
    final encoded = headers['x-export-filename'];
    if (encoded != null && encoded.isNotEmpty) {
      try {
        return Uri.decodeComponent(encoded);
      } catch (_) {
        // ถ้าถอดไม่ได้ให้ใช้ชื่อสำรองด้านล่าง
      }
    }
    return 'energy-export.xlsx';
  }

  String _messageFromBody(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // ไม่ใช่ JSON ก็ใช้ข้อความกลาง
    }
    return 'Could not build the Excel file.';
  }
}
