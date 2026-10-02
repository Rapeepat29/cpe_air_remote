import '../localization/app_localizations.dart';
import '../models/system_alert.dart';

/// ตัวยิงแจ้งเตือนของเครื่อง
///
/// แยกเป็นสัญญาไว้เพื่อสองเรื่อง หนึ่งคือเทสต์ใส่ตัวปลอมได้โดยไม่ต้องมี
/// ปลั๊กอินจริง สองคือตอนนี้ใช้การแจ้งเตือนในเครื่อง (ทำงานเมื่อแอปยังไม่ถูก
/// ปิดสนิท) แต่ถ้าวันหลังย้ายไป FCM ก็เปลี่ยนแค่ตัวที่มาสวมสัญญานี้
abstract interface class AlertNotifier {
  /// ขอสิทธิ์และเตรียมช่องแจ้งเตือน คืน false เมื่อผู้ใช้ไม่อนุญาต
  Future<bool> initialize();

  /// เด้งหนึ่งใบ
  Future<void> show({
    required SystemAlert alert,
    required String title,
    required String body,
  });
}

/// ตัวเปล่า ใช้บนแพลตฟอร์มที่ยังไม่รองรับ และในเทสต์วิดเจ็ต
class NoopAlertNotifier implements AlertNotifier {
  const NoopAlertNotifier();

  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> show({
    required SystemAlert alert,
    required String title,
    required String body,
  }) async {}
}

/// ข้อความบนแจ้งเตือนหนึ่งใบ
class AlertNotificationText {
  const AlertNotificationText({required this.title, required this.body});

  final String title;
  final String body;
}

/// แปลงใบแจ้งเตือนเป็นข้อความตามภาษาที่ผู้ใช้เลือก
///
/// ไม่รับ BuildContext เพราะตัวเรียกอยู่ในตัวควบคุม ไม่ได้อยู่ในต้นไม้วิดเจ็ต
/// และเวลาที่แจ้งเตือนเด้ง หน้าจอนั้นอาจถูกถอดไปแล้ว
AlertNotificationText describeAlert(
  SystemAlert alert,
  AppLocalizations localizations,
) {
  final title = localizations.translate(switch (alert.kind) {
    SystemAlertKind.outsideScheduleOccupied => 'Running outside class hours',
    SystemAlertKind.autoOffSucceeded => 'Air conditioner switched off',
    SystemAlertKind.autoOffFailed => 'Automatic shutdown failed',
    SystemAlertKind.unknown => 'System event',
  });

  // ตัวแปลมีกฎ `Room <เลขห้อง>` อยู่แล้ว ส่งทั้งประโยคเข้าไปได้เลย
  final room = alert.roomNumber.isEmpty
      ? ''
      : localizations.translate('Room ${alert.roomNumber}');
  final device = alert.deviceName.isEmpty ? '' : alert.deviceName;
  final where = [room, device].where((part) => part.isNotEmpty).join(' · ');
  final message = localizations.translate(alert.kind.message);

  return AlertNotificationText(
    title: title,
    body: where.isEmpty ? message : '$where — $message',
  );
}
