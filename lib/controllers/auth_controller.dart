import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../models/remembered_login.dart';
import '../services/auth_repository.dart';

enum AuthStatus {
  loading,
  signedOut,
  signedIn,
}

class AuthController extends ChangeNotifier {
  AuthController(this.repository);

  final AuthRepository repository;

  AuthStatus status = AuthStatus.loading;
  AuthUser? user;

  Future<void> initialize() async {
    try {
      user = await repository.restoreSession();
    } catch (_) {
      user = null;
    }
    status = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
    required bool rememberPassword,
  }) async {
    final authenticatedUser = await repository.login(
      username: username,
      password: password,
    );

    if (rememberPassword) {
      await repository.saveRememberedLogin(
        username: username,
        password: password,
      );
    } else {
      await repository.clearRememberedLogin();
    }

    user = authenticatedUser;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<RememberedLogin?> loadRememberedLogin() {
    return repository.loadRememberedLogin();
  }

  Future<void> clearRememberedLogin() {
    return repository.clearRememberedLogin();
  }

  Future<AuthUser> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    final updated = await repository.updateProfile(
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
    );
    user = updated;
    notifyListeners();
    return updated;
  }

  /// เปลี่ยนรหัสผ่านแล้วออกจากระบบ เพราะ Token เดิมถูกยกเลิกไปด้วย
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  Future<void> logout() async {
    await repository.logout();
    user = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
