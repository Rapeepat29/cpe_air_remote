import 'dart:convert';

import '../models/system_alert.dart';

/// ช่องทางแจ้งเตือนของชนิดหนึ่ง
///
/// แยกสองช่องเพราะคนละความรำคาญกัน รายการในแอปเปิดไว้ก็ไม่กวนใคร
/// แต่การเด้งบนมือถือดังตอนกลางดึกได้ จึงต้องปิดแยกจากกัน
class AlertChannels {
  const AlertChannels({required this.inApp, required this.push});

  /// แสดงในรายการแจ้งเตือนของแอป
  final bool inApp;

  /// เด้งเป็นการแจ้งเตือนของเครื่อง
  final bool push;

  AlertChannels copyWith({bool? inApp, bool? push}) {
    return AlertChannels(
      inApp: inApp ?? this.inApp,
      push: push ?? this.push,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AlertChannels &&
        other.inApp == inApp &&
        other.push == push;
  }

  @override
  int get hashCode => Object.hash(inApp, push);

  @override
  String toString() => 'AlertChannels(inApp: $inApp, push: $push)';
}

/// ค่าตั้งการแจ้งเตือนแยกตามชนิด
///
/// เก็บเป็น JSON ก้อนเดียวใน secure storage โดยใช้ชื่อสมาชิกของ enum เป็นคีย์
/// ไม่ใช้รหัสฝั่ง Backend เพราะค่าตั้งนี้เป็นของเครื่องผู้ใช้ ไม่ได้ส่งขึ้นเซิร์ฟเวอร์
class AlertPreferences {
  const AlertPreferences(this._byKind, {this.enabled = true});

  final Map<SystemAlertKind, AlertChannels> _byKind;

  /// สวิตช์หลักของการแจ้งเตือนบนอุปกรณ์นี้
  ///
  /// ปิดแล้วไม่มีการแจ้งเตือนเลยสักชนิด แต่ค่าที่เลือกไว้รายชนิดยังจำไว้
  /// เปิดกลับมาเมื่อไรก็ได้แบบเดิม ไม่ต้องไปไล่เปิดใหม่ทีละชนิด
  final bool enabled;

  /// ชนิดที่ให้ผู้ใช้ตั้งค่าเองได้ เรียงตามลำดับที่แสดงในหน้าตั้งค่า
  ///
  /// `unknown` ไม่อยู่ในนี้ เพราะเป็นชนิดที่แอปรุ่นนี้ยังไม่รู้จัก
  /// ถ้าให้ปิดได้ วันหนึ่ง Backend เพิ่มชนิดใหม่แล้วจะหายไปเงียบ ๆ
  static const configurableKinds = <SystemAlertKind>[
    SystemAlertKind.outsideScheduleOccupied,
    SystemAlertKind.autoOffSucceeded,
    SystemAlertKind.autoOffFailed,
  ];

  /// ชนิดที่แอปยังไม่รู้จัก ให้ขึ้นในรายการเสมอแต่ไม่เด้ง
  static const _unknownChannels = AlertChannels(inApp: true, push: false);

  /// เปิดทุกช่องไว้ก่อน ผู้ใช้ค่อยปิดเองทีหลัง
  factory AlertPreferences.defaults() {
    return AlertPreferences({
      for (final kind in configurableKinds)
        kind: const AlertChannels(inApp: true, push: true),
    });
  }

  AlertChannels channelsFor(SystemAlertKind kind) {
    if (kind == SystemAlertKind.unknown) return _unknownChannels;
    return _byKind[kind] ?? const AlertChannels(inApp: true, push: true);
  }

  /// ในแอปแสดงทุกชนิดเสมอ ผู้ใช้ปิดไม่ได้ (ไม่สนค่า inApp ที่เคยเก็บไว้)
  bool showsInApp(SystemAlertKind kind) => true;

  /// ชนิดนี้จะแจ้งเตือนบนอุปกรณ์จริงหรือไม่ (ต้องเปิดทั้งสวิตช์หลักและรายชนิด)
  bool pushesToPhone(SystemAlertKind kind) =>
      enabled && channelsFor(kind).push;

  /// ค่าที่ผู้ใช้เลือกไว้สำหรับชนิดนี้ ไม่สนสวิตช์หลัก ใช้แสดงในหน้าตั้งค่า
  bool typeSelected(SystemAlertKind kind) => channelsFor(kind).push;

  AlertPreferences withChannels(SystemAlertKind kind, AlertChannels channels) {
    if (kind == SystemAlertKind.unknown) return this;
    return AlertPreferences({..._byKind, kind: channels}, enabled: enabled);
  }

  AlertPreferences withEnabled(bool value) {
    return AlertPreferences(_byKind, enabled: value);
  }

  /// ใบที่ควรขึ้นในรายการของแอป
  List<SystemAlert> visible(Iterable<SystemAlert> alerts) {
    return alerts.where((alert) => showsInApp(alert.kind)).toList();
  }

  /// ใบที่ควรแจ้งเตือนบนอุปกรณ์
  List<SystemAlert> pushable(Iterable<SystemAlert> alerts) {
    return alerts.where((alert) => pushesToPhone(alert.kind)).toList();
  }

  String encode() {
    return jsonEncode({
      'enabled': enabled,
      for (final entry in _byKind.entries)
        entry.key.name: {
          'inApp': entry.value.inApp,
          'push': entry.value.push,
        },
    });
  }

  /// อ่านค่าที่เก็บไว้ ถ้าอ่านไม่ได้หรือรูปแบบเพี้ยนให้ถอยไปใช้ค่าเริ่มต้น
  ///
  /// ชนิดที่ไม่มีในข้อมูลเก่าจะได้ค่าเริ่มต้นของมันเอง เวลาเพิ่มชนิดใหม่
  /// ผู้ใช้เดิมจึงไม่ต้องไปตั้งค่าใหม่ทั้งหมด
  factory AlertPreferences.decode(String? raw) {
    if (raw == null || raw.isEmpty) return AlertPreferences.defaults();

    final Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } catch (_) {
      return AlertPreferences.defaults();
    }
    if (parsed is! Map) return AlertPreferences.defaults();

    final result = <SystemAlertKind, AlertChannels>{};
    for (final kind in configurableKinds) {
      const fallback = AlertChannels(inApp: true, push: true);
      final saved = parsed[kind.name];
      if (saved is! Map) {
        result[kind] = fallback;
        continue;
      }
      result[kind] = AlertChannels(
        // ทิ้งค่า inApp เก่าที่ผู้ใช้เคยปิดไว้ เพราะตอนนี้แสดงในแอปเสมอ
        inApp: true,
        push: saved['push'] is bool ? saved['push'] as bool : true,
      );
    }
    // ข้อมูลรุ่นก่อนไม่มีสวิตช์หลัก ถือว่าเปิดอยู่
    final savedEnabled = parsed['enabled'];
    return AlertPreferences(
      result,
      enabled: savedEnabled is bool ? savedEnabled : true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! AlertPreferences) return false;
    if (other.enabled != enabled) return false;
    for (final kind in configurableKinds) {
      if (channelsFor(kind) != other.channelsFor(kind)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    enabled,
    for (final kind in configurableKinds) channelsFor(kind),
  ]);
}

/// ใบที่เพิ่งโผล่มาใหม่ เทียบกับรหัสที่เคยเห็นแล้ว
///
/// ใช้ตัดสินว่าจะเด้งแจ้งเตือนใบไหน รอบโหลดแรกของแอปต้องไม่เด้ง
/// ไม่งั้นเปิดแอปทีเดียวจะได้แจ้งเตือนย้อนหลังรวดเดียวสามสิบใบ
List<SystemAlert> freshAlerts({
  required Iterable<SystemAlert> alerts,
  required Set<String> seenIds,
}) {
  return alerts
      .where((alert) => alert.id.isNotEmpty && !seenIds.contains(alert.id))
      .toList();
}
