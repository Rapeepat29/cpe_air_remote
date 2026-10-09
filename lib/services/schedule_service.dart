import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/class_schedule.dart';
import '../models/room_calendar.dart';
import '../models/schedule_import.dart';
import 'auth_service.dart';
import 'schedule_repository.dart';

class ScheduleService implements ScheduleRepository {
  ScheduleService({
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
  Future<List<ClassSchedule>> fetchSchedules() async {
    return (await fetchScheduleBundle()).schedules;
  }

  @override
  Future<ScheduleBundle> fetchScheduleBundle() async {
    final data = await _request('GET', '/schedules');
    final schedules = data['schedules'];
    if (schedules is! List) {
      throw const ApiException('The server returned invalid schedule data.');
    }

    return ScheduleBundle(
      schedules: schedules
          .whereType<Map<String, dynamic>>()
          .map(ClassSchedule.fromJson)
          .toList(),
      timetable: TimetableInfo.fromJson(data['timetable']),
      supportsTimetable: data.containsKey('timetable'),
    );
  }

  @override
  Future<AcademicCalendar> fetchAcademicCalendar() async {
    final data = await _request('GET', '/schedules/terms');
    return AcademicCalendar.fromJson(data);
  }

  @override
  Future<AcademicTerm> saveAcademicTerm(AcademicTerm term) async {
    final data = await _request(
      'PUT',
      '/schedules/terms',
      body: term.toRequestJson(),
    );
    return AcademicTerm.fromJson(_map(data['term']));
  }

  @override
  Future<void> deleteAcademicTerm(String semester) async {
    await _request(
      'DELETE',
      '/schedules/terms?semester=${Uri.encodeQueryComponent(semester)}',
    );
  }

  @override
  Future<List<RoomBooking>> fetchBookings({
    required String from,
    required String to,
  }) async {
    final data = await _request('GET', '/bookings?from=$from&to=$to');
    final bookings = data['bookings'];
    if (bookings is! List) return const [];
    return bookings
        .whereType<Map<String, dynamic>>()
        .map(RoomBooking.fromJson)
        .toList();
  }

  @override
  Future<void> createBooking(RoomBooking booking) async {
    await _request('POST', '/bookings', body: booking.toRequestJson());
  }

  @override
  Future<void> updateBooking(RoomBooking booking) async {
    await _request(
      'PUT',
      '/bookings/${Uri.encodeComponent(booking.id)}',
      body: booking.toRequestJson(),
    );
  }

  @override
  Future<void> deleteBooking(String id) async {
    await _request('DELETE', '/bookings/${Uri.encodeComponent(id)}');
  }

  @override
  Future<ClassSchedule> createSchedule(ClassSchedule schedule) async {
    final data = await _request(
      'POST',
      '/schedules',
      body: schedule.toRequestJson(),
    );
    return ClassSchedule.fromJson(_map(data['schedule']));
  }

  @override
  Future<ClassSchedule> updateSchedule(ClassSchedule schedule) async {
    final data = await _request(
      'PUT',
      '/schedules/${schedule.id}',
      body: schedule.toRequestJson(),
    );
    return ClassSchedule.fromJson(_map(data['schedule']));
  }

  @override
  Future<void> deleteSchedule(String id) async {
    await _request('DELETE', '/schedules/$id');
  }

  @override
  Future<int> deleteAllSchedules() async {
    final data = await _request('DELETE', '/schedules');
    final result = _map(data['result']);
    final deletedCount = result['deletedCount'];
    if (deletedCount is! num) {
      throw const ApiException('The server returned invalid schedule data.');
    }
    return deletedCount.toInt();
  }

  @override
  Future<ScheduleImportPreview> previewScheduleFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null || token.isEmpty) {
      throw const ApiException('Please sign in again.', statusCode: 401);
    }

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/schedules/import/preview'),
      )
        ..headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/octet-stream',
          'Authorization': 'Bearer $token',
          'X-File-Name': Uri.encodeComponent(fileName),
        })
        ..bodyBytes = bytes;

      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);
      final data = _decode(response);
      return ScheduleImportPreview.fromJson(_map(data['preview']));
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Could not connect to the server. Check the network and API_BASE_URL.',
      );
    }
  }

  @override
  Future<ScheduleImportResult> importSchedulePreview(
    ScheduleImportPreview preview,
  ) async {
    final data = await _request(
      'POST',
      '/schedules/import/commit',
      body: preview.toCommitJson(),
    );
    return ScheduleImportResult.fromJson(_map(data['result']));
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
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamedResponse = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Could not connect to the server. Check the network and API_BASE_URL.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        // A readable fallback error is returned below.
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

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw const ApiException('The server returned invalid schedule data.');
  }
}
