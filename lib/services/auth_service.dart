import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/admin_contact.dart';
import '../models/auth_user.dart';
import '../models/remembered_login.dart';
import 'auth_repository.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthService implements AuthRepository {
  AuthService({
    http.Client? client,
    FlutterSecureStorage? storage,
    String baseUrl = ApiConfig.baseUrl,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage(),
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  static const _tokenKey = 'rmutt_access_token';
  static const _rememberedUsernameKey = 'rmutt_remembered_username';
  static const _rememberedPasswordKey = 'rmutt_remembered_password';
  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String _baseUrl;

  /// จำเฉพาะชื่อผู้ใช้ ไม่เก็บรหัสผ่านลงเครื่อง
  ///
  /// รุ่นก่อนเก็บรหัสผ่านจริงไว้ใน secure storage ถ้ามือถือหายหรือถูกเจาะ
  /// รหัสผ่านจะหลุดไปด้วย (และคนมักใช้รหัสเดียวกันหลายที่) การอยู่ในระบบต่อ
  /// ใช้ token ที่หมดอายุเองแทน ซึ่งยกเลิกได้จากเซิร์ฟเวอร์
  @override
  Future<RememberedLogin?> loadRememberedLogin() async {
    // ลบรหัสผ่านที่รุ่นเก่าเคยเก็บไว้ทิ้งทุกครั้ง
    await _storage.delete(key: _rememberedPasswordKey);
    final username =
        (await _storage.read(key: _rememberedUsernameKey))?.trim() ?? '';
    if (username.isEmpty) return null;
    return RememberedLogin(username: username, password: '');
  }

  @override
  Future<void> saveRememberedLogin({
    required String username,
    required String password,
  }) async {
    await _storage.write(
      key: _rememberedUsernameKey,
      value: username.trim(),
    );
    await _storage.delete(key: _rememberedPasswordKey);
  }

  @override
  Future<void> clearRememberedLogin() async {
    await Future.wait([
      _storage.delete(key: _rememberedUsernameKey),
      _storage.delete(key: _rememberedPasswordKey),
    ]);
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final data = await _get('/auth/me', token: token);
      return AuthUser.fromJson(_map(data['user']));
    } on ApiException {
      await _storage.delete(key: _tokenKey);
      return null;
    }
  }

  @override
  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    final data = await _post(
      '/auth/login',
      body: {
        'username': username.trim(),
        'password': password,
      },
    );

    final token = data['token'] as String? ?? '';
    if (token.isEmpty) {
      throw const ApiException('The server did not return an access token.');
    }

    await _storage.write(key: _tokenKey, value: token);
    return AuthUser.fromJson(_map(data['user']));
  }

  @override
  Future<void> logout() => _storage.delete(key: _tokenKey);

  @override
  Future<String> requestPasswordReset(String identifier) async {
    final data = await _post(
      '/auth/forgot-password',
      body: {'identifier': identifier.trim()},
    );
    final requestId = data['requestId'] as String? ?? '';
    if (requestId.isEmpty) {
      throw const ApiException('Could not create a password reset request.');
    }
    return requestId;
  }

  @override
  Future<String> verifyPasswordResetOtp({
    required String requestId,
    required String otp,
  }) async {
    final data = await _post(
      '/auth/verify-otp',
      body: {
        'requestId': requestId,
        'otp': otp,
      },
    );
    final resetToken = data['resetToken'] as String? ?? '';
    if (resetToken.isEmpty) {
      throw const ApiException('Could not verify the OTP.');
    }
    return resetToken;
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _post(
      '/auth/reset-password',
      body: {
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
  }

  @override
  Future<AuthUser> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      throw const ApiException('Please sign in again.', statusCode: 401);
    }
    final data = await _send(
      'PATCH',
      '/auth/me',
      token: token,
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
      },
    );
    return AuthUser.fromJson(_map(data['user']));
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      throw const ApiException('Please sign in again.', statusCode: 401);
    }
    await _send(
      'POST',
      '/auth/me/password',
      token: token,
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    // Token เดิมถูกยกเลิกที่ Backend แล้ว ลบของที่เก็บไว้ทิ้งด้วย
    await _storage.delete(key: _tokenKey);
    await clearRememberedLogin();
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    try {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll(_headers(token: token))
        ..body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(_timeout);
      return _decode(await http.Response.fromStream(streamed));
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
  Future<AdminContact> getAdminContact() async {
    final data = await _get('/public/admin-contact');
    return AdminContact.fromJson(_map(data['admin']));
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    String? token,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl$path'),
            headers: _headers(token: token),
          )
          .timeout(_timeout);
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

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
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

  Map<String, String> _headers({String? token}) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      // A readable fallback error is returned below.
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
    throw const ApiException('The server returned invalid data.');
  }
}
