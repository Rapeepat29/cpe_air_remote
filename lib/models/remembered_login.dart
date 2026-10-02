class RememberedLogin {
  const RememberedLogin({
    required this.username,
    required this.password,
  });

  final String username;

  /// ว่างเสมอสำหรับข้อมูลจากเครื่องจริง แอปไม่เก็บรหัสผ่านแล้ว
  /// (คงช่องนี้ไว้ให้ตัวทดสอบและโค้ดเดิมใช้ได้โดยไม่ต้องแก้)
  final String password;
}
