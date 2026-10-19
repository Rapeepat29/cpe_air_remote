enum AirMode { auto, cool, dry, fan, heat }

enum FanSpeed { auto, low, medium, high, turbo }

enum SwingMode { auto, top, upper, middle, lower, bottom, off }

extension AirModeLabel on AirMode {
  String get label => switch (this) {
    AirMode.auto => 'Auto',
    AirMode.cool => 'Cool',
    AirMode.dry => 'Dry',
    AirMode.fan => 'Fan',
    AirMode.heat => 'Heat',
  };
}

extension FanSpeedLabel on FanSpeed {
  String get label => switch (this) {
    FanSpeed.auto => 'Auto',
    FanSpeed.low => 'Low',
    FanSpeed.medium => 'Medium',
    FanSpeed.high => 'High',
    FanSpeed.turbo => 'Turbo',
  };
}

extension SwingModeLabel on SwingMode {
  String get label => switch (this) {
    SwingMode.auto => 'Auto',
    SwingMode.top => 'Up',
    SwingMode.upper => 'Upper',
    SwingMode.middle => 'Middle',
    SwingMode.lower => 'Lower',
    SwingMode.bottom => 'Down',
    SwingMode.off => 'Off',
  };
}

/// บอร์ดรุ่นสายแอร์ (rmutt_esp32_air_wired) ต่อสายแอร์แทนรีโมตติดผนัง Daikin
const daikinWiredProtocol = 'DAIKIN_WIRED';

/// ชื่อยี่ห้อที่คนอ่านเข้าใจ จากชื่อโปรโตคอลที่เก็บในฐานข้อมูล
String airBrandOf(String protocol) {
  final value = protocol.trim().toUpperCase();
  if (value == daikinWiredProtocol || value.startsWith('DAIKIN')) {
    return 'Daikin';
  }
  if (value == 'SAIJO_DENKI') return 'Saijo Denki';
  if (value.startsWith('MITSUBISHI')) return 'Mitsubishi Electric';
  if (value.startsWith('HAIER')) return 'Haier';
  const names = {
    'PANASONIC_AC': 'Panasonic',
    'PANASONIC_AC32': 'Panasonic',
    'GREE': 'Gree',
    'MIDEA': 'Midea',
    'COOLIX': 'Midea',
    'LG': 'LG',
    'LG2': 'LG',
    'SAMSUNG_AC': 'Samsung',
    'TOSHIBA_AC': 'Toshiba',
    'HITACHI_AC': 'Hitachi',
    'FUJITSU_AC': 'Fujitsu',
    'KELVINATOR': 'Kelvinator',
    'SHARP_AC': 'Sharp',
    'ELECTRA_AC': 'Electra',
  };
  return names[value] ?? protocol;
}

/// `wired` สำหรับบอร์ดสายแอร์ นอกนั้น `ir`
String airControlTypeOf(String protocol) =>
    protocol.trim().toUpperCase() == daikinWiredProtocol ? 'wired' : 'ir';

class AirConditioner {
  AirConditioner({
    required this.id,
    required this.name,
    this.deviceId,
    this.roomNumber,
    this.bleName,
    this.protocol = 'HAIER_AC160',
    this.provisionStatus = 'active',
    this.isOnline = false,
    this.mqttTopic,
    this.dailyOn,
    this.dailyOff,
    this.lastSeenAt,
    this.isOn = false,
    this.temperature = 25,
    this.mode = AirMode.cool,
    this.fanSpeed = FanSpeed.auto,
    this.verticalSwing = SwingMode.auto,
    this.horizontalSwing = false,
    this.eco = false,
    this.turbo = false,
    this.sleep = false,
    this.quiet = false,
    this.displayLight = true,
    this.clean = false,
    this.timerOnMinutes,
    this.timerOffMinutes,
    this.voltage = 0,
    this.current = 0,
    this.power = 0,
    this.energyKwh = 0,
    this.frequencyHz = 0,
    this.powerFactor = 0,
    this.pzemAvailable = false,
    this.isRunning = false,
    this.outsideSchedule = false,
    this.autoOffEnabled = true,
    this.autoOffDeadlineAt,
    this.autoOffAttempts = 0,
    this.autoOffInClass = false,
    this.commandedAt,
  }) {
    normalizeForProtocol();
  }

  factory AirConditioner.fromJson(Map<String, dynamic> json) {
    final state = json['state'] is Map<String, dynamic>
        ? json['state'] as Map<String, dynamic>
        : <String, dynamic>{};
    return AirConditioner(
      id: _int(json['airNumber'], 1),
      name: _string(json['name'], 'Air Conditioner'),
      deviceId: json['deviceId'] as String?,
      roomNumber: json['roomNumber'] as String?,
      bleName: json['bleName'] as String?,
      protocol: _string(json['protocol'], 'HAIER_AC160'),
      provisionStatus: _string(json['provisionStatus'], 'reserved'),
      isOnline: json['isOnline'] == true,
      mqttTopic: json['mqttTopic'] as String?,
      dailyOn: json['dailyOn'] as String?,
      dailyOff: json['dailyOff'] as String?,
      lastSeenAt: DateTime.tryParse(_string(json['lastSeenAt'], '')),
      isOn: state['power'] == true,
      temperature: _int(state['temperature'], 25).clamp(16, 30).toInt(),
      mode: _enumByName(AirMode.values, state['mode'], AirMode.cool),
      fanSpeed: _enumByName(
        FanSpeed.values,
        state['fanSpeed'],
        FanSpeed.auto,
      ),
      verticalSwing: _enumByName(
        SwingMode.values,
        state['verticalSwing'],
        SwingMode.auto,
      ),
      horizontalSwing: state['horizontalSwing'] == true,
      eco: state['eco'] == true,
      turbo: state['turbo'] == true,
      sleep: state['sleep'] == true,
      quiet: state['quiet'] == true,
      displayLight: state['displayLight'] != false,
      clean: state['clean'] == true,
      timerOnMinutes: _nullableInt(state['timerOnMinutes']),
      timerOffMinutes: _nullableInt(state['timerOffMinutes']),
      voltage: _double(json['voltage']),
      current: _double(json['current']),
      power: _double(json['powerWatts']),
      energyKwh: _double(json['energyKwh']),
      frequencyHz: _double(json['frequencyHz']),
      powerFactor: _double(json['powerFactor']),
      pzemAvailable: json['pzemAvailable'] == true,
      isRunning: json['acRunning'] == true,
      outsideSchedule: json['outsideSchedule'] == true,
      autoOffEnabled: json['autoOffEnabled'] != false,
      autoOffDeadlineAt: DateTime.tryParse(
        _string(json['autoOffDeadlineAt'], ''),
      ),
      autoOffAttempts: _int(json['autoOffAttempts'], 0),
      autoOffInClass: json['autoOffInClass'] == true,
    );
  }

  final int id;
  final String? deviceId;
  final String? roomNumber;
  final String? bleName;
  final String protocol;
  final String? mqttTopic;
  final String? dailyOn;
  final String? dailyOff;
  String provisionStatus;
  bool isOnline;
  DateTime? lastSeenAt;
  String name;
  bool isOn;
  int temperature;
  AirMode mode;
  FanSpeed fanSpeed;
  SwingMode verticalSwing;
  bool horizontalSwing;
  bool eco;
  bool turbo;
  bool sleep;
  bool quiet;
  bool displayLight;
  bool clean;
  int? timerOnMinutes;
  int? timerOffMinutes;
  double voltage;
  double current;
  double power;
  double energyKwh;
  double frequencyHz;
  double powerFactor;
  bool pzemAvailable;
  bool isRunning;
  bool outsideSchedule;

  /// ปิดอัตโนมัติเมื่อห้องว่างเปิดอยู่หรือไม่ ตั้งได้รายเครื่อง
  bool autoOffEnabled;

  /// เวลาที่ระบบจะสั่งปิด ถ้าห้องยังว่างอยู่ null = ไม่มีนาฬิกาเดินอยู่
  DateTime? autoOffDeadlineAt;

  /// ยิงคำสั่งปิดไปแล้วกี่ครั้ง 0 = ยังอยู่ในช่วงนับถอยหลัง
  int autoOffAttempts;

  /// นาฬิการอบนี้เริ่มตอนมีคาบเรียนอยู่หรือไม่ (ใช้เวลานับต่างกัน)
  bool autoOffInClass;

  /// ช่วงเวลารอให้แอร์เริ่มทำงานและให้ PZEM อ่านค่าครบ 3 รอบหลังสั่งงานผ่านแอป
  static const Duration commandGracePeriod = Duration(seconds: 20);

  /// เวลาที่ผู้ใช้กดส่งคำสั่งเปิด/ปิดจากแอปครั้งล่าสุด
  DateTime? commandedAt;

  bool get isAutoOffPending => autoOffDeadlineAt != null;

  /// ยังอยู่ในช่วงหน่วง 20 วินาทีหลังสั่งงานจากแอปหรือไม่
  bool inCommandGracePeriod([DateTime? now]) {
    final sentAt = commandedAt;
    if (sentAt == null) return false;
    final elapsed = (now ?? DateTime.now()).difference(sentAt);
    return !elapsed.isNegative && elapsed < commandGracePeriod;
  }

  /// เครื่องเปิดอยู่จริงหรือไม่ ใช้แสดงผลและเป็นค่าตั้งต้นของคำสั่งถัดไป
  ///
  /// - ถ้ามี PZEM (`pzemAvailable == true`) จะเชื่อค่าจริงจาก PZEM (`isRunning`)
  ///   ยกเว้นในช่วง 20 วินาทีแรกหลังกดสั่งจากแอป (`inCommandGracePeriod`)
  ///   ที่จะยึดตามคำสั่ง (`isOn`) ไปก่อน เพื่อไม่ให้ปุ่มเด้งกลับเป็นปิดระหว่างรอแอร์สตาร์ท
  /// - ถ้าพ้น 20 วินาทีแล้วยังกินไฟไม่ถึงเกณฑ์ (`isRunning == false` เช่น ขึ้นแค่ 2 W)
  ///   สถานะจะเปลี่ยนกลับเป็นปิด (`false`) อัตโนมัติ
  /// - ถ้าไม่มี PZEM (`pzemAvailable == false`) จะยึดตามคำสั่ง `isOn`
  bool get isPoweredOn {
    if (!pzemAvailable) return isOn;
    if (inCommandGracePeriod()) return isOn;
    return isRunning;
  }

  bool get isProvisioned => provisionStatus == 'active';
  bool get canControl => isProvisioned && isOnline && deviceId != null;
  bool get isSaijoDenki => protocol == 'SAIJO_DENKI';

  /// ควบคุมผ่านสายแอร์ (แทนรีโมตติดผนัง) ไม่ใช่ยิง IR
  bool get isWired => airControlTypeOf(protocol) == 'wired';

  /// ยี่ห้อแอร์ เช่น Daikin, Haier
  String get brand => airBrandOf(protocol);

  /// ข้อความสั้นบอกยี่ห้อ + วิธีควบคุม (ส่งผ่าน context.tr ก่อนแสดง)
  String get controlTypeLabel => isWired ? 'Wired' : 'IR remote';

  int get minimumTemperature => isSaijoDenki ? 18 : 16;
  int get maximumTemperature => isSaijoDenki ? 29 : 30;
  List<AirMode> get supportedModes =>
      isSaijoDenki || isWired
          ? const [AirMode.cool, AirMode.dry, AirMode.fan]
          : AirMode.values;
  List<FanSpeed> get supportedFanSpeeds => isWired
      ? const [FanSpeed.auto, FanSpeed.low, FanSpeed.medium, FanSpeed.high]
      : isSaijoDenki
      ? const [
          FanSpeed.auto,
          FanSpeed.low,
          FanSpeed.medium,
          FanSpeed.high,
          FanSpeed.turbo,
        ]
      : FanSpeed.values;
  List<SwingMode> get supportedSwingModes => isWired
      ? const [SwingMode.auto, SwingMode.off]
      : isSaijoDenki
      ? const [
          SwingMode.auto,
          SwingMode.top,
          SwingMode.upper,
          SwingMode.middle,
          SwingMode.lower,
          SwingMode.bottom,
        ]
      : const [
          SwingMode.auto,
          SwingMode.top,
          SwingMode.middle,
          SwingMode.bottom,
          SwingMode.off,
        ];
  bool get supportsAdditionalFunctions => !isSaijoDenki;

  // ฟังก์ชันเสริมทีละตัว รุ่นสายแอร์มีแค่ Sleep (ใช้ไม่ได้ในโหมด Dry)
  bool get supportsHorizontalSwing => supportsAdditionalFunctions && !isWired;
  bool get supportsEco => supportsAdditionalFunctions && !isWired;
  bool get supportsTurbo => supportsAdditionalFunctions && !isWired;
  bool get supportsSleep =>
      supportsAdditionalFunctions && !(isWired && mode == AirMode.dry);
  bool get supportsQuiet => supportsAdditionalFunctions && !isWired;
  bool get supportsDisplayLight => supportsAdditionalFunctions && !isWired;
  bool get supportsClean => supportsAdditionalFunctions && !isWired;

  String fanSpeedLabel(FanSpeed speed) {
    if (!isSaijoDenki) return speed.label;
    return switch (speed) {
      FanSpeed.auto => 'Auto',
      FanSpeed.low => 'Level 1',
      FanSpeed.medium => 'Level 2',
      FanSpeed.high => 'Level 3',
      FanSpeed.turbo => 'Turbo',
    };
  }

  void normalizeForProtocol() {
    temperature = temperature
        .clamp(minimumTemperature, maximumTemperature)
        .toInt();
    if (isWired) {
      if (!supportedModes.contains(mode)) mode = AirMode.cool;
      if (fanSpeed == FanSpeed.turbo) fanSpeed = FanSpeed.high;
      if (!supportedSwingModes.contains(verticalSwing)) {
        verticalSwing = SwingMode.auto;
      }
      horizontalSwing = false;
      eco = false;
      turbo = false;
      quiet = false;
      clean = false;
      if (mode == AirMode.dry) sleep = false;
      return;
    }
    if (!isSaijoDenki) return;
    if (!supportedModes.contains(mode)) mode = AirMode.cool;
    if (verticalSwing == SwingMode.off) verticalSwing = SwingMode.auto;
    horizontalSwing = false;
    eco = false;
    turbo = false;
    sleep = false;
    quiet = false;
    clean = false;
  }

  Map<String, dynamic> toCommandJson() => {
    'power': isOn,
    'temperature': temperature,
    'mode': mode.name,
    'fanSpeed': fanSpeed.name,
    'verticalSwing': verticalSwing.name,
    'horizontalSwing': horizontalSwing,
    'eco': eco,
    'turbo': turbo,
    'sleep': sleep,
    'quiet': quiet,
    'displayLight': displayLight,
    'clean': clean,
    'timerOnMinutes': timerOnMinutes,
    'timerOffMinutes': timerOffMinutes,
  };

  AirConditioner editableCopy() => AirConditioner(
    id: id,
    name: name,
    deviceId: deviceId,
    roomNumber: roomNumber,
    bleName: bleName,
    protocol: protocol,
    provisionStatus: provisionStatus,
    isOnline: isOnline,
    mqttTopic: mqttTopic,
    dailyOn: dailyOn,
    dailyOff: dailyOff,
    lastSeenAt: lastSeenAt,
    // เริ่มจากสถานะจริง กดปุ่มอื่นตอนแอร์เปิดด้วยรีโมตจะได้ไม่เผลอสั่งปิด
    isOn: isPoweredOn,
    temperature: temperature,
    mode: mode,
    fanSpeed: fanSpeed,
    verticalSwing: verticalSwing,
    horizontalSwing: horizontalSwing,
    eco: eco,
    turbo: turbo,
    sleep: sleep,
    quiet: quiet,
    displayLight: displayLight,
    clean: clean,
    timerOnMinutes: timerOnMinutes,
    timerOffMinutes: timerOffMinutes,
    voltage: voltage,
    current: current,
    power: power,
    energyKwh: energyKwh,
    frequencyHz: frequencyHz,
    powerFactor: powerFactor,
    pzemAvailable: pzemAvailable,
    isRunning: isRunning,
    outsideSchedule: outsideSchedule,
    commandedAt: commandedAt,
  );

  void copyStateFrom(AirConditioner other, {DateTime? commandedAt}) {
    isOn = other.isOn;
    this.commandedAt = commandedAt ?? other.commandedAt ?? DateTime.now();
    // สั่งปิดแล้ว ให้หน้าจอขึ้นว่าปิดทันที ไม่ต้องรอ PZEM ยืนยัน (~6 วินาที)
    // ถ้าแอร์ไม่ดับจริง รอบรีเฟรชถัดไปจะได้ acRunning = true กลับมาเอง
    if (!other.isOn) isRunning = false;
    temperature = other.temperature;
    mode = other.mode;
    fanSpeed = other.fanSpeed;
    verticalSwing = other.verticalSwing;
    horizontalSwing = other.horizontalSwing;
    eco = other.eco;
    turbo = other.turbo;
    sleep = other.sleep;
    quiet = other.quiet;
    displayLight = other.displayLight;
    clean = other.clean;
    timerOnMinutes = other.timerOnMinutes;
    timerOffMinutes = other.timerOffMinutes;
    normalizeForProtocol();
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  final name = value is String ? value : '';
  for (final item in values) {
    if (item.name == name) return item;
  }
  return fallback;
}

String _string(Object? value, String fallback) {
  return value is String && value.isNotEmpty ? value : fallback;
}

int _int(Object? value, int fallback) {
  final result = value is num ? value.toInt() : int.tryParse('$value');
  return result ?? fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  return value is num ? value.toInt() : int.tryParse('$value');
}

double _double(Object? value) {
  final result = value is num ? value.toDouble() : double.tryParse('$value');
  return result ?? 0;
}
