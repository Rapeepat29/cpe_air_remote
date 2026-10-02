import '../models/system_alert.dart';

abstract interface class AlertRepository {
  /// การแจ้งเตือนล่าสุด ใบที่ยังเปิดอยู่จะมาก่อนเสมอ
  Future<List<SystemAlert>> fetchAlerts({int limit});

  /// รับทราบใบที่ยังเปิดอยู่ คืนใบที่อัปเดตแล้ว
  Future<SystemAlert> acknowledge(String id);
}
