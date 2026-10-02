/// ชนิดของการแจ้งเตือนที่ Backend สร้างขึ้นเอง
///
/// Backend เก็บเป็นรหัส ไม่ใช่ข้อความสำเร็จรูป แอปจึงเลือกถ้อยคำและภาษาเองได้
enum SystemAlertKind {
  /// ไม่มีคาบเรียนตอนนี้ แต่แอร์ทำงานอยู่และมีคนอยู่ในห้อง
  outsideScheduleOccupied,

  /// ระบบสั่งปิดแอร์อัตโนมัติแล้วแอร์หยุดจริง
  autoOffSucceeded,

  /// สั่งปิดครบจำนวนครั้งแล้วแอร์ยังทำงานอยู่
  autoOffFailed,

  /// ชนิดที่แอปรุ่นนี้ยังไม่รู้จัก
  unknown,
}

extension SystemAlertKindLabel on SystemAlertKind {
  static SystemAlertKind fromApi(String? value) => switch (value) {
    'outside_schedule_occupied' => SystemAlertKind.outsideScheduleOccupied,
    'auto_off_succeeded' => SystemAlertKind.autoOffSucceeded,
    'auto_off_failed' => SystemAlertKind.autoOffFailed,
    _ => SystemAlertKind.unknown,
  };

  /// ข้อความอธิบายเหตุการณ์ ผ่านตัวแปลของแอปอีกที
  String get message => switch (this) {
    SystemAlertKind.outsideScheduleOccupied =>
      'Air conditioner running outside class hours with people in the room',
    SystemAlertKind.autoOffSucceeded =>
      'Empty room: the air conditioner was switched off automatically',
    SystemAlertKind.autoOffFailed =>
      'Could not switch the air conditioner off. Please check it by hand.',
    SystemAlertKind.unknown => 'System event',
  };

  bool get isWarning => this != SystemAlertKind.autoOffSucceeded;
}

class SystemAlert {
  const SystemAlert({
    required this.id,
    required this.kind,
    required this.roomNumber,
    required this.status,
    required this.createdAt,
    this.deviceId,
    this.deviceName = '',
    this.detail = '',
    this.acknowledgedBy,
  });

  final String id;
  final SystemAlertKind kind;
  final String roomNumber;

  /// `open` = ยังต้องมีคนไปจัดการ, `acknowledged` = รับทราบแล้ว,
  /// `resolved` = เงื่อนไขหมดไปเองหรือระบบจัดการจบแล้ว
  final String status;
  final DateTime? createdAt;
  final String? deviceId;
  final String deviceName;
  final String detail;
  final String? acknowledgedBy;

  bool get isOpen => status == 'open';
  bool get isWarning => kind.isWarning;

  factory SystemAlert.fromJson(Map<String, dynamic> json) {
    return SystemAlert(
      id: json['id'] as String? ?? '',
      kind: SystemAlertKindLabel.fromApi(json['kind'] as String?),
      roomNumber: json['roomNumber'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      acknowledgedBy: json['acknowledgedBy'] as String?,
    );
  }

  SystemAlert copyWith({String? status, String? acknowledgedBy}) {
    return SystemAlert(
      id: id,
      kind: kind,
      roomNumber: roomNumber,
      status: status ?? this.status,
      createdAt: createdAt,
      deviceId: deviceId,
      deviceName: deviceName,
      detail: detail,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
    );
  }
}
