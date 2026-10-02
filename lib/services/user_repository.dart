import '../models/managed_user.dart';

abstract interface class UserRepository {
  Future<List<ManagedUser>> fetchUsers();

  Future<ManagedUser> createUser({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String role,
  });

  Future<ManagedUser> updateUser(
    String username, {
    String? role,
    bool? isActive,
  });

  Future<void> deleteUser(String username);
}
