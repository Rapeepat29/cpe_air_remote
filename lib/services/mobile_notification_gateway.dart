import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/system_alert.dart';
import 'alert_notifier.dart';

/// แจ้งเตือนในเครื่องผ่าน flutter_local_notifications (Android / iOS)
///
/// เด้งได้ตราบที่แอปยังรันอยู่ (รวมอยู่เบื้องหลัง) ถ้าแอปถูกปิดสนิทต้องใช้ FCM
class LocalAlertNotifier implements AlertNotifier {
  LocalAlertNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'system_alerts';
  static const _channelName = 'System alerts';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _setup;
  bool _permissionGranted = false;

  /// รองรับเฉพาะมือถือ แพลตฟอร์มอื่นให้ใช้ [NoopAlertNotifier]
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> initialize() async {
    if (!await (_setup ??= _doSetup())) {
      _setup = null;
      return false;
    }
    if (_permissionGranted) return true;
    _permissionGranted = await _requestPermission();
    return _permissionGranted;
  }

  /// เตรียมปลั๊กอินและช่องแจ้งเตือนครั้งเดียว แยกจากการขอสิทธิ์เพื่อให้ขอใหม่ได้
  /// หากผู้ใช้กดไม่อนุญาตในครั้งแรกแล้วไปเปิดใน Settings ของเครื่องทีหลัง
  Future<bool> _doSetup() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
          ),
        );
      }
      return true;
    } catch (error) {
      debugPrint('LocalAlertNotifier setup failed: $error');
      return false;
    }
  }

  Future<bool> _requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        if (enabled == true) return true;
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } catch (error) {
      debugPrint('LocalAlertNotifier permission check failed: $error');
      return false;
    }
  }

  @override
  Future<void> show({
    required SystemAlert alert,
    required String title,
    required String body,
  }) async {
    if (!await initialize()) return;
    await _plugin.show(
      alert.id.hashCode & 0x7fffffff,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      ),
    );
  }
}
