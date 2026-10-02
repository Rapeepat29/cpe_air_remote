/// ค่าตั้งระดับระบบที่เก็บอยู่บนเซิร์ฟเวอร์
///
/// ต่างจาก `AppSettingsController` ตรงที่ค่าพวกนี้เป็นของทั้งอาคาร
/// ไม่ใช่ความชอบของเครื่องใครเครื่องหนึ่ง
class SystemSettings {
  const SystemSettings({required this.autoOffEnabled});

  /// สวิตช์รวมของระบบปิดแอร์อัตโนมัติ
  final bool autoOffEnabled;

  /// ค่าที่ใช้ก่อนโหลดสำเร็จ ตรงกับค่าเริ่มต้นฝั่งเซิร์ฟเวอร์
  static const unknown = SystemSettings(autoOffEnabled: true);

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    return SystemSettings(autoOffEnabled: json['autoOffEnabled'] != false);
  }

  @override
  bool operator ==(Object other) =>
      other is SystemSettings && other.autoOffEnabled == autoOffEnabled;

  @override
  int get hashCode => autoOffEnabled.hashCode;
}

abstract interface class SystemSettingsRepository {
  /// อ่านค่าตั้งปัจจุบัน ทุกคนที่ล็อกอินแล้วอ่านได้
  Future<SystemSettings> fetchSettings();

  /// เปิดปิดระบบปิดแอร์อัตโนมัติทั้งอาคาร เฉพาะแอดมิน
  Future<SystemSettings> setAutoOffEnabled(bool enabled);
}
