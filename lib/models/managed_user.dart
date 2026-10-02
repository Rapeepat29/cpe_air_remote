class ManagedUser {
  const ManagedUser({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.lastLoginAt,
    this.createdAt,
  });

  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: (json['role'] as String? ?? 'staff').toLowerCase(),
      isActive: json['isActive'] as bool? ?? true,
      lastLoginAt: _parseDate(json['lastLoginAt']),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  bool get isAdmin => role == 'admin';

  String get displayName {
    final name = [firstName, lastName]
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    return name.isEmpty ? username : name;
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }

  ManagedUser copyWith({String? role, bool? isActive}) {
    return ManagedUser(
      username: username,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLoginAt: lastLoginAt,
      createdAt: createdAt,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
