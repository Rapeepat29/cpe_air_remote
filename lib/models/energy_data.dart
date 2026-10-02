import 'dart:typed_data';

/// ระดับการรวมข้อมูลของรายงาน
///
/// [building] คือสรุปทั้งอาคาร หนึ่งแถวต่อหนึ่งชั่วโมง ตรงกับไฟล์ตัวอย่าง
/// [room] และ [device] คือโหมดรายละเอียดสูง เลือกเจาะจงห้องหรือเครื่องได้
enum EnergyScope { building, room, device }

extension EnergyScopeApi on EnergyScope {
  String get apiValue => switch (this) {
    EnergyScope.building => 'building',
    EnergyScope.room => 'room',
    EnergyScope.device => 'device',
  };

  String get label => switch (this) {
    EnergyScope.building => 'Whole building',
    EnergyScope.room => 'By room',
    EnergyScope.device => 'By air conditioner',
  };

  String get description => switch (this) {
    EnergyScope.building =>
      'One row per hour, totalling every air conditioner in Building 16',
    EnergyScope.room => 'One row per hour for each room you pick',
    EnergyScope.device =>
      'One row per hour for each air conditioner you pick',
  };

  /// ตั้งแต่ระดับห้องขึ้นไปถือเป็นโหมดรายละเอียดสูงเสมอ
  bool get isHighDetail => this != EnergyScope.building;
}

/// ค่าไฟหนึ่งชนิดที่เลือกใส่ในรายงานได้ รายการนี้มาจาก Backend
class EnergyMetric {
  const EnergyMetric({
    required this.key,
    required this.labelTh,
    required this.labelEn,
    required this.unit,
    required this.decimals,
    required this.detailOnly,
    required this.isDefault,
  });

  final String key;
  final String labelTh;
  final String labelEn;
  final String unit;
  final int decimals;

  /// true = เลือกได้เฉพาะโหมดรายละเอียดสูง
  final bool detailOnly;
  final bool isDefault;

  factory EnergyMetric.fromJson(Map<String, dynamic> json) {
    return EnergyMetric(
      key: json['key'] as String? ?? '',
      labelTh: json['labelTh'] as String? ?? '',
      labelEn: json['labelEn'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      decimals: (json['decimals'] as num?)?.toInt() ?? 2,
      detailOnly: json['detailOnly'] == true,
      isDefault: json['isDefault'] == true,
    );
  }

  String label({required bool isThai}) => isThai ? labelTh : labelEn;

  String labelWithUnit({required bool isThai}) {
    final text = label(isThai: isThai);
    return unit.isEmpty ? text : '$text ($unit)';
  }
}

/// ค่าล่าสุดของแอร์หนึ่งเครื่อง ใช้กับหน้าจอที่อัปเดตต่อเนื่อง
class EnergyLiveReading {
  const EnergyLiveReading({
    required this.deviceId,
    required this.roomNumber,
    required this.floorNumber,
    required this.name,
    required this.airNumber,
    required this.isOnline,
    required this.pzemAvailable,
    required this.acRunning,
    this.voltage,
    this.current,
    this.powerWatts,
    this.energyKwh,
    this.frequencyHz,
    this.powerFactor,
    this.lastSeenAt,
  });

  final String deviceId;
  final String roomNumber;
  final int floorNumber;
  final String name;
  final int airNumber;
  final bool isOnline;
  final bool pzemAvailable;
  final bool acRunning;
  final double? voltage;
  final double? current;
  final double? powerWatts;
  final double? energyKwh;
  final double? frequencyHz;
  final double? powerFactor;
  final DateTime? lastSeenAt;

  factory EnergyLiveReading.fromJson(Map<String, dynamic> json) {
    return EnergyLiveReading(
      deviceId: json['deviceId'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      floorNumber: (json['floorNumber'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      airNumber: (json['airNumber'] as num?)?.toInt() ?? 0,
      isOnline: json['isOnline'] == true,
      pzemAvailable: json['pzemAvailable'] == true,
      acRunning: json['acRunning'] == true,
      voltage: _toDouble(json['voltage']),
      current: _toDouble(json['current']),
      powerWatts: _toDouble(json['powerWatts']),
      energyKwh: _toDouble(json['energyKwh']),
      frequencyHz: _toDouble(json['frequencyHz']),
      powerFactor: _toDouble(json['powerFactor']),
      lastSeenAt: DateTime.tryParse(json['lastSeenAt'] as String? ?? ''),
    );
  }
}

class EnergyLiveSnapshot {
  const EnergyLiveSnapshot({
    required this.readings,
    required this.deviceCount,
    required this.onlineCount,
    required this.runningCount,
    required this.totalPowerWatts,
    required this.receivedAt,
  });

  final List<EnergyLiveReading> readings;
  final int deviceCount;
  final int onlineCount;
  final int runningCount;
  final double totalPowerWatts;
  final DateTime? receivedAt;

  factory EnergyLiveSnapshot.fromJson(Map<String, dynamic> json) {
    final values = json['readings'];
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    final readings = values is List
        ? values
              .whereType<Map<String, dynamic>>()
              .map(EnergyLiveReading.fromJson)
              .toList()
        : <EnergyLiveReading>[];

    return EnergyLiveSnapshot(
      readings: readings,
      deviceCount: (totals['devices'] as num?)?.toInt() ?? readings.length,
      onlineCount: (totals['online'] as num?)?.toInt() ?? 0,
      runningCount: (totals['running'] as num?)?.toInt() ?? 0,
      totalPowerWatts: _toDouble(totals['powerWatts']) ?? 0,
      receivedAt: DateTime.now(),
    );
  }

  static const empty = EnergyLiveSnapshot(
    readings: [],
    deviceCount: 0,
    onlineCount: 0,
    runningCount: 0,
    totalPowerWatts: 0,
    receivedAt: null,
  );
}

/// ห้องหนึ่งห้องที่เลือกใส่รายงานได้
class EnergyRoomSource {
  const EnergyRoomSource({
    required this.roomNumber,
    required this.floorNumber,
    required this.deviceCount,
    required this.bucketCount,
  });

  final String roomNumber;
  final int floorNumber;
  final int deviceCount;

  /// จำนวนชั่วโมงที่มีข้อมูลเก็บไว้แล้ว
  final int bucketCount;

  factory EnergyRoomSource.fromJson(Map<String, dynamic> json) {
    return EnergyRoomSource(
      roomNumber: json['roomNumber'] as String? ?? '',
      floorNumber: (json['floorNumber'] as num?)?.toInt() ?? 0,
      deviceCount: (json['deviceCount'] as num?)?.toInt() ?? 0,
      bucketCount: (json['bucketCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// แอร์หนึ่งเครื่องที่เลือกใส่รายงานได้
class EnergyDeviceSource {
  const EnergyDeviceSource({
    required this.deviceId,
    required this.roomNumber,
    required this.floorNumber,
    required this.name,
    required this.airNumber,
    required this.bucketCount,
    required this.archived,
  });

  final String deviceId;
  final String roomNumber;
  final int floorNumber;
  final String name;
  final int airNumber;
  final int bucketCount;

  /// true = ถูกนำออกจากระบบแล้ว แต่ยังมีประวัติค้างอยู่
  final bool archived;

  factory EnergyDeviceSource.fromJson(Map<String, dynamic> json) {
    return EnergyDeviceSource(
      deviceId: json['deviceId'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      floorNumber: (json['floorNumber'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      airNumber: (json['airNumber'] as num?)?.toInt() ?? 0,
      bucketCount: (json['bucketCount'] as num?)?.toInt() ?? 0,
      archived: json['archived'] == true,
    );
  }
}

class EnergySourceCatalog {
  const EnergySourceCatalog({
    required this.rooms,
    required this.devices,
    this.oldestDate,
    this.newestDate,
  });

  final List<EnergyRoomSource> rooms;
  final List<EnergyDeviceSource> devices;
  final DateTime? oldestDate;
  final DateTime? newestDate;

  static const empty = EnergySourceCatalog(rooms: [], devices: []);

  factory EnergySourceCatalog.fromJson(Map<String, dynamic> json) {
    final rooms = json['rooms'];
    final devices = json['devices'];
    final coverage = json['coverage'] as Map<String, dynamic>? ?? const {};

    return EnergySourceCatalog(
      rooms: rooms is List
          ? rooms
                .whereType<Map<String, dynamic>>()
                .map(EnergyRoomSource.fromJson)
                .toList()
          : const [],
      devices: devices is List
          ? devices
                .whereType<Map<String, dynamic>>()
                .map(EnergyDeviceSource.fromJson)
                .toList()
          : const [],
      oldestDate: DateTime.tryParse(coverage['oldest'] as String? ?? ''),
      newestDate: DateTime.tryParse(coverage['newest'] as String? ?? ''),
    );
  }

  List<EnergyDeviceSource> devicesInRooms(Set<String> roomNumbers) {
    if (roomNumbers.isEmpty) return devices;
    return devices
        .where((device) => roomNumbers.contains(device.roomNumber))
        .toList();
  }
}

/// หนึ่งแถวของรายงาน หนึ่งช่วงชั่วโมง
class EnergyHistoryRow {
  const EnergyHistoryRow({
    required this.date,
    required this.time,
    required this.hour,
    required this.values,
    this.roomNumber,
    this.deviceId,
    this.deviceName,
  });

  /// วันที่แบบ YYYY-MM-DD ตรงกับคอลัมน์ data ในไฟล์ตัวอย่าง
  final String date;

  /// ช่วงเวลาแบบ 15:00-16:00 ตรงกับคอลัมน์ time ในไฟล์ตัวอย่าง
  final String time;
  final int hour;
  final Map<String, double?> values;
  final String? roomNumber;
  final String? deviceId;
  final String? deviceName;

  factory EnergyHistoryRow.fromJson(Map<String, dynamic> json) {
    final raw = json['values'] as Map<String, dynamic>? ?? const {};
    return EnergyHistoryRow(
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      values: raw.map((key, value) => MapEntry(key, _toDouble(value))),
      roomNumber: json['roomNumber'] as String?,
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
    );
  }
}

class EnergyHistoryResult {
  const EnergyHistoryResult({
    required this.rows,
    required this.metricKeys,
    required this.totals,
  });

  final List<EnergyHistoryRow> rows;
  final List<String> metricKeys;
  final Map<String, double?> totals;

  static const empty = EnergyHistoryResult(
    rows: [],
    metricKeys: [],
    totals: {},
  );

  factory EnergyHistoryResult.fromJson(Map<String, dynamic> json) {
    final rows = json['rows'];
    final query = json['query'] as Map<String, dynamic>? ?? const {};
    final metrics = query['metrics'];
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};

    return EnergyHistoryResult(
      rows: rows is List
          ? rows
                .whereType<Map<String, dynamic>>()
                .map(EnergyHistoryRow.fromJson)
                .toList()
          : const [],
      metricKeys: metrics is List
          ? metrics.map((item) => item.toString()).toList()
          : const [],
      totals: totals.map((key, value) => MapEntry(key, _toDouble(value))),
    );
  }
}

/// เงื่อนไขที่ผู้ใช้เลือกจากหน้าจอ แปลงเป็น query string ให้ Backend
class EnergyQuery {
  const EnergyQuery({
    required this.from,
    required this.to,
    required this.scope,
    required this.rooms,
    required this.devices,
    required this.metrics,
    this.rate = 0,
  });

  final DateTime from;
  final DateTime to;
  final EnergyScope scope;
  final List<String> rooms;
  final List<String> devices;
  final List<String> metrics;

  /// ค่าไฟต่อหน่วยจากหน้า `อัตราค่าไฟฟ้า` ใช้คำนวณคอลัมน์ค่าไฟโดยประมาณ
  final double rate;

  bool get isSingleDay => formatDate(from) == formatDate(to);

  Map<String, String> toQueryParameters() {
    return {
      'from': formatDate(from),
      'to': formatDate(to),
      'scope': scope.apiValue,
      'detail': scope.isHighDetail ? 'high' : 'summary',
      if (rooms.isNotEmpty) 'rooms': rooms.join(','),
      if (devices.isNotEmpty) 'devices': devices.join(','),
      if (metrics.isNotEmpty) 'metrics': metrics.join(','),
      if (rate > 0) 'rate': rate.toString(),
    };
  }

  static String formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

/// ไฟล์ Excel ที่ Backend สร้างเสร็จแล้ว พร้อมให้บันทึกหรือแชร์ต่อ
class EnergyExportFile {
  const EnergyExportFile({
    required this.fileName,
    required this.bytes,
    required this.rowCount,
  });

  final String fileName;
  final Uint8List bytes;
  final int rowCount;
}

double? _toDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// ช่วงเวลาที่หน้าหลักและหน้าสถิติเลือกดูได้
enum EnergyPeriodKind { day, week, month, custom }

extension EnergyPeriodKindApi on EnergyPeriodKind {
  String get apiValue => switch (this) {
    EnergyPeriodKind.day => 'day',
    EnergyPeriodKind.week => 'week',
    EnergyPeriodKind.month => 'month',
    EnergyPeriodKind.custom => 'custom',
  };

  String get label => switch (this) {
    EnergyPeriodKind.day => 'Today',
    EnergyPeriodKind.week => 'Last 7 days',
    EnergyPeriodKind.month => 'Last 30 days',
    EnergyPeriodKind.custom => 'Custom range',
  };

  static EnergyPeriodKind fromApi(String? value) => switch (value) {
    'day' => EnergyPeriodKind.day,
    'month' => EnergyPeriodKind.month,
    'custom' => EnergyPeriodKind.custom,
    _ => EnergyPeriodKind.week,
  };
}

/// หนึ่งจุดบนกราฟ เป็นรายชั่วโมงเมื่อดูวันเดียว และรายวันเมื่อดูช่วงยาว
class EnergySeriesPoint {
  const EnergySeriesPoint({
    required this.label,
    required this.date,
    required this.kwh,
    this.hour,
  });

  final String label;
  final String date;
  final int? hour;
  final double kwh;

  factory EnergySeriesPoint.fromJson(Map<String, dynamic> json) {
    return EnergySeriesPoint(
      label: json['label'] as String? ?? '',
      date: json['date'] as String? ?? '',
      hour: (json['hour'] as num?)?.toInt(),
      kwh: _toDouble(json['kwh']) ?? 0,
    );
  }
}

class EnergyRoomUsage {
  const EnergyRoomUsage({
    required this.roomNumber,
    required this.floorNumber,
    required this.roomType,
    required this.kwh,
    required this.runtimeMinutes,
    required this.deviceCount,
  });

  final String roomNumber;
  final int floorNumber;
  final String roomType;
  final double kwh;
  final double runtimeMinutes;
  final int deviceCount;

  factory EnergyRoomUsage.fromJson(Map<String, dynamic> json) {
    return EnergyRoomUsage(
      roomNumber: json['roomNumber'] as String? ?? '',
      floorNumber: (json['floorNumber'] as num?)?.toInt() ?? 0,
      roomType: json['roomType'] as String? ?? '',
      kwh: _toDouble(json['kwh']) ?? 0,
      runtimeMinutes: _toDouble(json['runtimeMinutes']) ?? 0,
      deviceCount: (json['deviceCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class EnergyDeviceUsage {
  const EnergyDeviceUsage({
    required this.deviceId,
    required this.roomNumber,
    required this.floorNumber,
    required this.name,
    required this.kwh,
    required this.runtimeMinutes,
  });

  final String deviceId;
  final String roomNumber;
  final int floorNumber;
  final String name;
  final double kwh;
  final double runtimeMinutes;

  factory EnergyDeviceUsage.fromJson(Map<String, dynamic> json) {
    return EnergyDeviceUsage(
      deviceId: json['deviceId'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      floorNumber: (json['floorNumber'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      kwh: _toDouble(json['kwh']) ?? 0,
      runtimeMinutes: _toDouble(json['runtimeMinutes']) ?? 0,
    );
  }
}

/// ตัวเลขจริงที่หน้าหลักและหน้าสถิติใช้แทนข้อมูลตัวอย่างเดิม
class EnergySummary {
  const EnergySummary({
    required this.kind,
    required this.from,
    required this.to,
    required this.days,
    required this.granularity,
    required this.totalKwh,
    required this.previousKwh,
    required this.runtimeMinutes,
    required this.peakPowerWatts,
    required this.deviceCount,
    required this.series,
    required this.rooms,
    required this.devices,
    this.changePercent,
    this.floor,
  });

  final EnergyPeriodKind kind;
  final String from;
  final String to;
  final int days;

  /// `hour` เมื่อดูวันเดียว หรือ `day` เมื่อดูช่วงยาว
  final String granularity;
  final double totalKwh;
  final double previousKwh;

  /// null เมื่อช่วงก่อนหน้าไม่มีข้อมูล จึงเทียบไม่ได้
  final double? changePercent;
  final double runtimeMinutes;
  final double peakPowerWatts;
  final int deviceCount;
  final List<EnergySeriesPoint> series;
  final List<EnergyRoomUsage> rooms;
  final List<EnergyDeviceUsage> devices;
  final int? floor;

  bool get hasData => totalKwh > 0 || deviceCount > 0;

  static const empty = EnergySummary(
    kind: EnergyPeriodKind.week,
    from: '',
    to: '',
    days: 7,
    granularity: 'day',
    totalKwh: 0,
    previousKwh: 0,
    runtimeMinutes: 0,
    peakPowerWatts: 0,
    deviceCount: 0,
    series: [],
    rooms: [],
    devices: [],
  );

  factory EnergySummary.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>? ?? const {};
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    final series = json['series'];
    final rooms = json['rooms'];
    final devices = json['devices'];

    return EnergySummary(
      kind: EnergyPeriodKindApi.fromApi(period['period'] as String?),
      from: period['from'] as String? ?? '',
      to: period['to'] as String? ?? '',
      days: (period['days'] as num?)?.toInt() ?? 7,
      granularity: period['granularity'] as String? ?? 'day',
      floor: (period['floor'] as num?)?.toInt(),
      totalKwh: _toDouble(totals['kwh']) ?? 0,
      previousKwh: _toDouble(totals['previousKwh']) ?? 0,
      changePercent: _toDouble(totals['changePercent']),
      runtimeMinutes: _toDouble(totals['runtimeMinutes']) ?? 0,
      peakPowerWatts: _toDouble(totals['peakPowerWatts']) ?? 0,
      deviceCount: (totals['deviceCount'] as num?)?.toInt() ?? 0,
      series: series is List
          ? series
                .whereType<Map<String, dynamic>>()
                .map(EnergySeriesPoint.fromJson)
                .toList()
          : const [],
      rooms: rooms is List
          ? rooms
                .whereType<Map<String, dynamic>>()
                .map(EnergyRoomUsage.fromJson)
                .toList()
          : const [],
      devices: devices is List
          ? devices
                .whereType<Map<String, dynamic>>()
                .map(EnergyDeviceUsage.fromJson)
                .toList()
          : const [],
    );
  }
}
