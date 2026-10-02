import 'package:cpe_air_remote/controllers/user_controller.dart';
import 'package:cpe_air_remote/models/managed_user.dart';
import 'package:cpe_air_remote/services/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('managed user reads the backend payload', () {
    final user = ManagedUser.fromJson(const {
      'username': 'somchai',
      'firstName': 'Somchai',
      'lastName': 'Jaidee',
      'email': 'somchai@example.com',
      'phone': '0800000000',
      'role': 'ADMIN',
      'isActive': false,
      'lastLoginAt': '2026-08-19T03:00:00.000Z',
    });

    expect(user.role, 'admin');
    expect(user.isAdmin, isTrue);
    expect(user.isActive, isFalse);
    expect(user.displayName, 'Somchai Jaidee');
    expect(user.initials, 'SJ');
    expect(user.lastLoginAt, isNotNull);
  });

  test('managed user falls back to the username when no name is set', () {
    final user = ManagedUser.fromJson(const {
      'username': 'staff01',
      'email': 'staff01@example.com',
      'role': 'staff',
      'isActive': true,
    });

    expect(user.displayName, 'staff01');
    expect(user.initials, 'S');
    expect(user.lastLoginAt, isNull);
  });

  test('controller sorts admins first and keeps the signed-in user', () async {
    final repository = _MemoryUserRepository([
      _user('zulu', role: 'staff'),
      _user('admin01', role: 'admin'),
      _user('bravo', role: 'staff', isActive: false),
    ]);
    final controller = UserController(
      repository: repository,
      currentUsername: 'admin01',
    );

    await controller.initialize();

    expect(
      controller.users.map((user) => user.username).toList(),
      ['admin01', 'zulu', 'bravo'],
    );
    expect(controller.isSelf(controller.users.first), isTrue);
    expect(controller.adminCount, 1);
  });

  test('changing a role updates the cached list', () async {
    final repository = _MemoryUserRepository([
      _user('admin01', role: 'admin'),
      _user('staff01', role: 'staff'),
    ]);
    final controller = UserController(
      repository: repository,
      currentUsername: 'admin01',
    );
    await controller.initialize();

    final target = controller.users.firstWhere(
      (user) => user.username == 'staff01',
    );
    await controller.changeRole(target, 'admin');

    expect(
      controller.users
          .firstWhere((user) => user.username == 'staff01')
          .isAdmin,
      isTrue,
    );
    expect(controller.adminCount, 2);
  });

  test('suspending and deleting a user updates the cached list', () async {
    final repository = _MemoryUserRepository([
      _user('admin01', role: 'admin'),
      _user('staff01', role: 'staff'),
    ]);
    final controller = UserController(
      repository: repository,
      currentUsername: 'admin01',
    );
    await controller.initialize();

    final target = controller.users.firstWhere(
      (user) => user.username == 'staff01',
    );
    await controller.setActive(target, false);
    expect(
      controller.users
          .firstWhere((user) => user.username == 'staff01')
          .isActive,
      isFalse,
    );

    await controller.deleteUser(target);
    expect(controller.users.length, 1);
    expect(controller.users.single.username, 'admin01');
  });

  test('a failing request surfaces the message instead of throwing', () async {
    final controller = UserController(
      repository: _FailingUserRepository(),
      currentUsername: 'admin01',
    );

    await controller.initialize();

    expect(controller.users, isEmpty);
    expect(controller.errorMessage, contains('ไม่พบผู้ใช้นี้ในระบบ'));
  });
}

ManagedUser _user(
  String username, {
  required String role,
  bool isActive = true,
}) {
  return ManagedUser(
    username: username,
    firstName: username,
    lastName: 'Test',
    email: '$username@example.com',
    phone: '',
    role: role,
    isActive: isActive,
  );
}

class _MemoryUserRepository implements UserRepository {
  _MemoryUserRepository(this.users);

  final List<ManagedUser> users;

  @override
  Future<List<ManagedUser>> fetchUsers() async => List.of(users);

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
    final created = ManagedUser(
      username: username,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      role: role,
      isActive: true,
    );
    users.add(created);
    return created;
  }

  @override
  Future<ManagedUser> updateUser(
    String username, {
    String? role,
    bool? isActive,
  }) async {
    final index = users.indexWhere((user) => user.username == username);
    final updated = users[index].copyWith(role: role, isActive: isActive);
    users[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteUser(String username) async {
    users.removeWhere((user) => user.username == username);
  }
}

class _FailingUserRepository implements UserRepository {
  @override
  Future<List<ManagedUser>> fetchUsers() async {
    throw Exception('ไม่พบผู้ใช้นี้ในระบบ');
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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ManagedUser> updateUser(
    String username, {
    String? role,
    bool? isActive,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteUser(String username) {
    throw UnimplementedError();
  }
}
