abstract final class ApiConfig {
  /// ที่อยู่ Backend ที่แอปใช้ทุกครั้ง แอปไม่ต่อ MariaDB โดยตรง
  ///
  /// ค่าเริ่มต้นคือเซิร์ฟเวอร์จริงผ่าน Tailscale Funnel (เข้าได้จากทุกที่ที่มีอินเทอร์เน็ต)
  /// ส่วน rmutt-energy.duckdns.org ชี้ไป IP ภายในมหาวิทยาลัย ใช้ได้เฉพาะในตึก
  /// สั่ง `flutter run` เฉย ๆ ก็ใช้ของจริงได้เลย
  /// ถ้าจะทดสอบกับ Backend ในเครื่องให้ override ตอน build:
  ///   flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
  ///   flutter run             --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://rmutt-energy.tailb292b4.ts.net/api',
  );

  /// true เมื่อชี้ไปเซิร์ฟเวอร์จริง ใช้แสดงผลหรือ debug ได้
  static bool get isProduction => baseUrl.startsWith('https://');
}
