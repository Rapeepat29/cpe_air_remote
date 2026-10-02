import 'package:flutter/foundation.dart';

import '../models/managed_user.dart';
import '../services/user_repository.dart';

class UserController extends ChangeNotifier {
  UserController({
    required this.repository,
    required this.currentUsername,
  });

  final UserRepository repository;
  final String currentUsername;

  final List<ManagedUser> users = [];
  bool isLoading = false;
  bool hasLoaded = false;
  bool _reloadInProgress = false;
  String? errorMessage;

  int get adminCount => users.where((u) => u.isAdmin && u.isActive).length;

  Future<void> initialize() async {
    if (isLoading || hasLoaded) return;
    await reload();
  }

  Future<void> reload({bool silent = false}) async {
    if (_reloadInProgress) return;
    _reloadInProgress = true;
    if (!silent) isLoading = true;
    errorMessage = null;
    if (!silent) notifyListeners();
    try {
      final loaded = await repository.fetchUsers();
      users
        ..clear()
        ..addAll(loaded);
      _sort();
      hasLoaded = true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('ApiException: ', '');
    } finally {
      _reloadInProgress = false;
      if (!silent) isLoading = false;
      notifyListeners();
    }
  }

  bool isSelf(ManagedUser user) => user.username == currentUsername;

  Future<void> changeRole(ManagedUser user, String role) async {
    if (user.role == role) return;
    final updated = await repository.updateUser(user.username, role: role);
    _replace(updated);
  }

  Future<void> setActive(ManagedUser user, bool isActive) async {
    if (user.isActive == isActive) return;
    final updated = await repository.updateUser(
      user.username,
      isActive: isActive,
    );
    _replace(updated);
  }

  Future<ManagedUser> createUser({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String role,
  }) async {
    final created = await repository.createUser(
      username: username,
      password: password,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      role: role,
    );
    users.add(created);
    _sort();
    errorMessage = null;
    notifyListeners();
    return created;
  }

  Future<void> deleteUser(ManagedUser user) async {
    await repository.deleteUser(user.username);
    users.removeWhere((item) => item.username == user.username);
    errorMessage = null;
    notifyListeners();
  }

  void _replace(ManagedUser updated) {
    final index = users.indexWhere(
      (item) => item.username == updated.username,
    );
    if (index >= 0) {
      users[index] = updated;
    } else {
      users.add(updated);
    }
    _sort();
    errorMessage = null;
    notifyListeners();
  }

  void _sort() {
    users.sort((first, second) {
      if (first.isAdmin != second.isAdmin) return first.isAdmin ? -1 : 1;
      if (first.isActive != second.isActive) return first.isActive ? -1 : 1;
      return first.username.toLowerCase().compareTo(
        second.username.toLowerCase(),
      );
    });
  }
}
