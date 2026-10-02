class AuthUser {
  const AuthUser({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.phone = '',
  });

  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'staff',
    );
  }

  String get displayName {
    final name = [firstName, lastName]
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    return name.isEmpty ? username : name;
  }

  String get roleLabel {
    return switch (role.toLowerCase()) {
      'admin' => 'Administrator',
      'staff' => 'Staff',
      _ => 'Staff',
    };
  }
}
