import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/managed_user.dart';
import 'auth_service.dart';
import 'user_repository.dart';

class UserService implements UserRepository {
  UserService({
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
  Future<List<ManagedUser>> fetchUsers() async {
    final data = await _request('GET', '/users');
    final users = data['users'];
    if (users is! List) {
      throw const ApiException('The server returned invalid user data.');
    }
    return users
        .whereType<Map<String, dynamic>>()
        .map(ManagedUser.fromJson)
        .toList();
  }

  @override
  Future<ManagedUser> createUser({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String role,
  }) async {
    final data = await _request(
      'POST',
      '/users',
      body: {
        'username': username,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'role': role,
      },
    );
    return ManagedUser.fromJson(_map(data['user']));
  }

  @override
  Future<ManagedUser> updateUser(
    String username, {
    String? role,
    bool? isActive,
  }) async {
    final data = await _request(
      'PATCH',
      '/users/${Uri.encodeComponent(username)}',
      body: {
        if (role != null) 'role': role,
        if (isActive != null) 'isActive': isActive,
      },
    );
    return ManagedUser.fromJson(_map(data['user']));
  }

  @override
  Future<void> deleteUser(String username) async {
    await _request('DELETE', '/users/${Uri.encodeComponent(username)}');
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
    throw const ApiException('The server returned invalid user data.');
  }
}
