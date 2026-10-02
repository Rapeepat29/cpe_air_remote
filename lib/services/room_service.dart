import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/room.dart';
import 'auth_service.dart';
import 'room_repository.dart';

class RoomService implements RoomRepository {
  RoomService({
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
  Future<List<Room>> fetchRooms() async {
    final data = await _request('GET', '/rooms');
    final rooms = data['rooms'];
    if (rooms is! List) {
      throw const ApiException('The server returned invalid room data.');
    }
    return rooms
        .whereType<Map<String, dynamic>>()
        .map(Room.fromJson)
        .toList();
  }

  @override
  Future<Room> createRoom(Room room) async {
    final data = await _request(
      'POST',
      '/rooms',
      body: room.toRequestJson(),
    );
    return Room.fromJson(_map(data['room']));
  }

  @override
  Future<Room> updateRoom(Room room) async {
    final data = await _request(
      'PUT',
      '/rooms/${Uri.encodeComponent(room.number)}',
      body: room.toRequestJson(includeNumber: false),
    );
    return Room.fromJson(_map(data['room']));
  }

  @override
  Future<void> deleteRoom(String roomNumber) async {
    await _request(
      'DELETE',
      '/rooms/${Uri.encodeComponent(roomNumber)}',
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
    if (value is Map<String, dynamic>) return value;
    throw const ApiException('The server returned invalid room data.');
  }
}
