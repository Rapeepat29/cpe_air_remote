import 'air_conditioner.dart';

class Room {
  Room({
    required this.number,
    required this.floor,
    required this.roomIndex,
    required this.type,
    required this.airConditioners,
    this.isOccupied = false,
    this.isOnline = true,
    this.registeredAirCount = 0,
    this.scheduleCount = 0,
    this.occupancySensorDeviceId,
    this.occupancySensorBleName,
    this.occupancySensorProvisionStatus,
    this.occupancySensorOnline = false,
    this.occupancySensorAvailable = false,
    this.occupancyStaticThreshold = 25,
    this.occupancyUpdatedAt,
    this.autoOffDeadlineAt,
    this.autoOffAttempts = 0,
    this.autoOffInClass = false,
  });

  final String number;
  final int floor;
  final int roomIndex;
  final String type;
  final List<AirConditioner> airConditioners;
  bool isOccupied;
  bool isOnline;
  final int registeredAirCount;
  final int scheduleCount;
  String? occupancySensorDeviceId;
  String? occupancySensorBleName;
  String? occupancySensorProvisionStatus;
  bool occupancySensorOnline;
  bool occupancySensorAvailable;
  int occupancyStaticThreshold;
  DateTime? occupancyUpdatedAt;

  /// นาฬิกาปิดแอร์อัตโนมัติของห้อง ใช้เครื่องที่ใกล้ครบกำหนดที่สุด
  DateTime? autoOffDeadlineAt;
  int autoOffAttempts;
  bool autoOffInClass;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      number: json['roomNumber'] as String? ?? '',
      floor: (json['floorNumber'] as num?)?.toInt() ?? 0,
      roomIndex: (json['roomIndex'] as num?)?.toInt() ?? 0,
      type: json['roomType'] as String? ?? 'Classroom',
      airConditioners: <AirConditioner>[],
      registeredAirCount:
          (json['airConditionerCount'] as num?)?.toInt() ?? 0,
      scheduleCount: (json['scheduleCount'] as num?)?.toInt() ?? 0,
      occupancySensorDeviceId:
          json['occupancySensorDeviceId'] as String?,
      occupancySensorBleName:
          json['occupancySensorBleName'] as String?,
      occupancySensorProvisionStatus:
          json['occupancySensorProvisionStatus'] as String?,
      occupancySensorOnline: json['occupancySensorOnline'] == true,
      occupancySensorAvailable: json['occupancySensorAvailable'] == true,
      isOccupied: json['isOccupied'] == true,
      occupancyStaticThreshold:
          (json['occupancyStaticThreshold'] as num?)?.toInt() ?? 25,
      occupancyUpdatedAt: DateTime.tryParse(
        json['occupancyUpdatedAt'] as String? ?? '',
      ),
      autoOffDeadlineAt: DateTime.tryParse(
        json['autoOffDeadlineAt'] as String? ?? '',
      ),
      autoOffAttempts: (json['autoOffAttempts'] as num?)?.toInt() ?? 0,
      autoOffInClass: json['autoOffInClass'] == true,
    );
  }

  Map<String, dynamic> toRequestJson({bool includeNumber = true}) {
    return {
      if (includeNumber) 'roomNumber': number,
      'floorNumber': floor,
      'roomIndex': roomIndex,
      'roomType': type,
    };
  }

  Room copyWith({
    String? number,
    int? floor,
    int? roomIndex,
    String? type,
    List<AirConditioner>? airConditioners,
    bool? isOccupied,
    bool? isOnline,
    int? registeredAirCount,
    int? scheduleCount,
    String? occupancySensorDeviceId,
    String? occupancySensorBleName,
    String? occupancySensorProvisionStatus,
    bool? occupancySensorOnline,
    bool? occupancySensorAvailable,
    int? occupancyStaticThreshold,
    DateTime? occupancyUpdatedAt,
    DateTime? autoOffDeadlineAt,
    int? autoOffAttempts,
    bool? autoOffInClass,
  }) {
    return Room(
      number: number ?? this.number,
      floor: floor ?? this.floor,
      roomIndex: roomIndex ?? this.roomIndex,
      type: type ?? this.type,
      airConditioners: airConditioners ?? this.airConditioners,
      isOccupied: isOccupied ?? this.isOccupied,
      isOnline: isOnline ?? this.isOnline,
      registeredAirCount: registeredAirCount ?? this.registeredAirCount,
      scheduleCount: scheduleCount ?? this.scheduleCount,
      occupancySensorDeviceId:
          occupancySensorDeviceId ?? this.occupancySensorDeviceId,
      occupancySensorBleName:
          occupancySensorBleName ?? this.occupancySensorBleName,
      occupancySensorProvisionStatus:
          occupancySensorProvisionStatus ??
          this.occupancySensorProvisionStatus,
      occupancySensorOnline:
          occupancySensorOnline ?? this.occupancySensorOnline,
      occupancySensorAvailable:
          occupancySensorAvailable ?? this.occupancySensorAvailable,
      occupancyStaticThreshold:
          occupancyStaticThreshold ?? this.occupancyStaticThreshold,
      occupancyUpdatedAt: occupancyUpdatedAt ?? this.occupancyUpdatedAt,
      autoOffDeadlineAt: autoOffDeadlineAt ?? this.autoOffDeadlineAt,
      autoOffAttempts: autoOffAttempts ?? this.autoOffAttempts,
      autoOffInClass: autoOffInClass ?? this.autoOffInClass,
    );
  }

  int get runningAirCount =>
      airConditioners.where((air) => air.isRunning).length;

  double get totalPower => airConditioners
      .where((air) => air.isRunning)
      .fold<double>(0, (sum, air) => sum + air.power);

  int get displayedAirCount =>
      airConditioners.isNotEmpty ? airConditioners.length : registeredAirCount;

  bool get hasOccupancySensor => occupancySensorDeviceId != null;

  /// ระบบกำลังนับถอยหลังเพื่อปิดแอร์ในห้องนี้อยู่หรือไม่
  bool get isAutoOffPending => autoOffDeadlineAt != null;
}
