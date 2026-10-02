class AdminContact {
  const AdminContact({
    required this.name,
    required this.phone,
  });

  final String name;
  final String phone;

  factory AdminContact.fromJson(Map<String, dynamic> json) {
    return AdminContact(
      name: json['name'] as String? ?? 'Administrator',
      phone: json['phone'] as String? ?? '',
    );
  }
}
