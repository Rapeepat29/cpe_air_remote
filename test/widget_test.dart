import 'dart:typed_data';

import 'package:cpe_air_remote/controllers/app_settings_controller.dart';
import 'package:cpe_air_remote/data/mock_data.dart';
import 'package:cpe_air_remote/main.dart';
import 'package:cpe_air_remote/models/admin_contact.dart';
import 'package:cpe_air_remote/models/air_conditioner.dart';
import 'package:cpe_air_remote/models/auth_user.dart';
import 'package:cpe_air_remote/models/class_schedule.dart';
import 'package:cpe_air_remote/models/energy_data.dart';
import 'package:cpe_air_remote/models/system_alert.dart';
import 'package:cpe_air_remote/models/remembered_login.dart';
import 'package:cpe_air_remote/models/provisioning.dart';
import 'package:cpe_air_remote/models/room.dart';
import 'package:cpe_air_remote/models/schedule_import.dart';
import 'package:cpe_air_remote/screens/application_settings_screen.dart';
import 'package:cpe_air_remote/services/alert_repository.dart';
import 'package:cpe_air_remote/services/auth_repository.dart';
import 'package:cpe_air_remote/services/energy_repository.dart';
import 'package:cpe_air_remote/services/air_conditioner_repository.dart';
import 'package:cpe_air_remote/services/schedule_repository.dart';
import 'package:cpe_air_remote/services/system_settings_repository.dart';
import 'package:cpe_air_remote/services/room_repository.dart';
import 'package:cpe_air_remote/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// ตั้งจอทดสอบให้สูงพอสำหรับหน้าล็อกอินทั้งใบ
///
/// ค่าเริ่มต้นของ flutter_test คือ 800x600 ซึ่งเตี้ยกว่าการ์ดล็อกอิน (~726)
/// ปุ่ม `เข้าสู่ระบบ` เลยไปอยู่ใต้ขอบจอ แล้ว tap() ก็ยิงไม่โดน
/// บนเครื่องจริงไม่มีปัญหานี้เพราะ AuthBackground เลื่อนหน้าจอได้อยู่แล้ว
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('requires login before showing the energy dashboard', (
    tester,
  ) async {
    _useTallScreen(tester);
    await tester.pumpWidget(
      CpeAirRemoteApp(
        authRepository: _FakeAuthRepository(),
        appSettingsController: AppSettingsController(
          store: _MemoryAppSettingsStore(),
        ),
        scheduleRepository: _MemoryScheduleRepository(),
        airConditionerRepository: _MemoryAirConditionerRepository(),
        roomRepository: _MemoryRoomRepository(),
        energyRepository: _MemoryEnergyRepository(),
        alertRepository: _MemoryAlertRepository(),
        systemSettingsRepository: _MemorySystemSettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RMUTT Save Energy'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsNWidgets(2));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin');
    await tester.enterText(fields.at(1), 'test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    expect(find.text('RMUTT Energy'), findsOneWidget);
    // ตัวเลขนี้มาจาก /api/energy/summary แล้ว ไม่ใช่ค่าตัวอย่างที่ฝังไว้
    expect(find.text('42.5'), findsOneWidget);
    expect(find.text('7 วันล่าสุด'), findsOneWidget);

    await tester.tap(find.text('ควบคุม'));
    await tester.pumpAndSettle();

    expect(find.text('เลือกห้องที่ต้องการควบคุม'), findsOneWidget);
    expect(find.text('ห้อง 16301'), findsOneWidget);
    expect(find.byIcon(Icons.ac_unit_rounded), findsWidgets);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

    final titleBounds = tester.getRect(
      find.text('เลือกห้องที่ต้องการควบคุม'),
    );
    final settingsBounds = tester.getRect(
      find.byKey(const Key('manage-rooms-button')),
    );
    final headerBounds = tester.getRect(
      find.byKey(const Key('rooms-header')),
    );
    final header = tester.widget<Container>(
      find.byKey(const Key('rooms-header')),
    );
    // แถบหัวใช้สีของธีมที่เลือกอยู่ (ค่าเริ่มต้นคือธีมขาว)
    expect(
      header.color,
      AppPalette.of(tester.element(find.byKey(const Key('rooms-header')))).bar,
    );
    // ชื่อเรื่องอยู่ใน Expanded ขอบขวาจึงชนขอบซ้ายของปุ่มพอดีเสมอ
    // สิ่งที่ต้องกันคือชื่อเรื่องล้นไปทับปุ่ม ไม่ใช่ต้องมีช่องว่างคั่น
    expect(titleBounds.right, lessThanOrEqualTo(settingsBounds.left));
    expect(
      settingsBounds.center.dx,
      greaterThan(headerBounds.center.dx),
    );
    expect(
      headerBounds.right - settingsBounds.right,
      lessThanOrEqualTo(16),
    );
  });

  testWidgets('loads and clears remembered login details', (tester) async {
    final repository = _FakeAuthRepository(
      rememberedLogin: const RememberedLogin(
        username: 'remembered-user',
        password: 'remembered-password',
      ),
    );

    _useTallScreen(tester);
    await tester.pumpWidget(
      CpeAirRemoteApp(
        authRepository: repository,
        appSettingsController: AppSettingsController(
          store: _MemoryAppSettingsStore(),
        ),
        scheduleRepository: _MemoryScheduleRepository(),
        airConditionerRepository: _MemoryAirConditionerRepository(),
        roomRepository: _MemoryRoomRepository(),
        energyRepository: _MemoryEnergyRepository(),
        alertRepository: _MemoryAlertRepository(),
        systemSettingsRepository: _MemorySystemSettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller?.text,
      'remembered-user',
    );
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller?.text,
      'remembered-password',
    );

    final rememberCheckbox = find.byType(Checkbox);
    expect(tester.widget<Checkbox>(rememberCheckbox).value, isTrue);

    await tester.tap(find.text('จดจำชื่อผู้ใช้'));
    await tester.pumpAndSettle();

    expect(repository.rememberedLogin, isNull);
    expect(tester.widget<Checkbox>(rememberCheckbox).value, isFalse);
  });

  testWidgets('switches language and persists dark mode independently', (
    tester,
  ) async {
    final settingsStore = _MemoryAppSettingsStore();
    final settingsController = AppSettingsController(store: settingsStore);

    _useTallScreen(tester);
    await tester.pumpWidget(
      CpeAirRemoteApp(
        authRepository: _FakeAuthRepository(),
        appSettingsController: settingsController,
        scheduleRepository: _MemoryScheduleRepository(),
        airConditionerRepository: _MemoryAirConditionerRepository(),
        roomRepository: _MemoryRoomRepository(),
        energyRepository: _MemoryEnergyRepository(),
        alertRepository: _MemoryAlertRepository(),
        systemSettingsRepository: _MemorySystemSettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin');
    await tester.enterText(fields.at(1), 'test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('โปรไฟล์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตั้งค่าแอปพลิเคชัน'));
    await tester.pumpAndSettle();

    expect(find.byType(ApplicationSettingsScreen), findsOneWidget);
    expect(find.text('ภาษาไทย'), findsOneWidget);
    expect(find.text('ธีมสี'), findsOneWidget);
    expect(find.text('ตามเครื่อง'), findsOneWidget);
    // ตั้งแต่ v3.10.0 หน้านี้มีหมวดขนาดตัวอักษรและหมวดแจ้งเตือนเพิ่มมา
    // ทั้งสองหมวดต้องเป็นภาษาไทยตามภาษาที่เลือกอยู่
    expect(find.text('ขนาดตัวอักษร'), findsWidgets);
    expect(find.text('การแจ้งเตือน'), findsOneWidget);
    expect(find.textContaining('Notification'), findsNothing);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Application Settings'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Theme colors'), findsOneWidget);
    // สลับเป็นอังกฤษแล้วหมวดใหม่ต้องสลับตามด้วย ไม่ใช่ค้างเป็นไทย
    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.textContaining('การแจ้งเตือน'), findsNothing);
    expect(settingsStore.languageCode, 'en');

    await tester.tap(find.byKey(const Key('theme-option-gray')));
    await tester.pumpAndSettle();

    final settingsContext = tester.element(
      find.byType(ApplicationSettingsScreen),
    );
    expect(Theme.of(settingsContext).brightness, Brightness.dark);
    expect(settingsStore.themeCode, 'gray');
    // ค่าแบบเดิมยังถูกเก็บด้วย เผื่อย้อนไปลงแอปรุ่นก่อน
    expect(settingsStore.darkMode, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_remote_rounded));
    await tester.pumpAndSettle();

    // A theme rebuild must keep the room objects populated by the backend.
    expect(find.text('1 units'), findsOneWidget);
  });

  testWidgets('loads the previously selected English language', (tester) async {
    final settingsStore = _MemoryAppSettingsStore()..languageCode = 'en';

    _useTallScreen(tester);
    await tester.pumpWidget(
      CpeAirRemoteApp(
        authRepository: _FakeAuthRepository(),
        appSettingsController: AppSettingsController(store: settingsStore),
        scheduleRepository: _MemoryScheduleRepository(),
        airConditionerRepository: _MemoryAirConditionerRepository(),
        roomRepository: _MemoryRoomRepository(),
        energyRepository: _MemoryEnergyRepository(),
        alertRepository: _MemoryAlertRepository(),
        systemSettingsRepository: _MemorySystemSettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsNWidgets(2));
    expect(find.text('Remember username'), findsOneWidget);
  });

  testWidgets('saves the electricity rate and updates cost estimates', (
    tester,
  ) async {
    final settingsStore = _MemoryAppSettingsStore();

    _useTallScreen(tester);
    await tester.pumpWidget(
      CpeAirRemoteApp(
        authRepository: _FakeAuthRepository(),
        appSettingsController: AppSettingsController(store: settingsStore),
        scheduleRepository: _MemoryScheduleRepository(),
        airConditionerRepository: _MemoryAirConditionerRepository(),
        roomRepository: _MemoryRoomRepository(),
        energyRepository: _MemoryEnergyRepository(),
        alertRepository: _MemoryAlertRepository(),
        systemSettingsRepository: _MemorySystemSettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin');
    await tester.enterText(fields.at(1), 'test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('โปรไฟล์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('อัตราค่าไฟฟ้า'));
    await tester.pumpAndSettle();

    expect(find.text('4.50 บาท / kWh'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('electricity-rate-field')),
      '5.25',
    );
    await tester.pump();
    expect(find.text('1,420.13 บาท'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-electricity-rate-button')));
    await tester.pumpAndSettle();

    expect(settingsStore.electricityRate, 5.25);
    expect(find.text('อัตราปัจจุบัน'), findsNothing);

    // 1,420.13 ข้างบนเป็นตัวอย่างของหน้าอัตราค่าไฟ ซึ่งคิดจาก 270.5 kWh ตายตัว
    // แต่หน้าหลักกับหน้าสถิติใช้ยอดจริงจาก /api/energy/summary ตั้งแต่ v3.8.0
    // ซึ่งในเทสต์นี้คือ 42.5 kWh  ->  42.5 x 5.25 = 223.125 ปัดเป็น 223.13
    await tester.tap(find.text('หน้าหลัก'));
    await tester.pumpAndSettle();
    expect(find.text('ค่าไฟโดยประมาณ: 223.13 บาท'), findsOneWidget);

    await tester.tap(find.text('สถิติ'));
    await tester.pumpAndSettle();
    expect(find.text('≈ 223.13 บาท'), findsOneWidget);
  });

  testWidgets('admin adds and edits a room class schedule', (tester) async {
    final scheduleRepository = _MemoryScheduleRepository();

    _useTallScreen(tester);
    await tester.pumpWidget(
      CpeAirRemoteApp(
        authRepository: _FakeAuthRepository(),
        appSettingsController: AppSettingsController(
          store: _MemoryAppSettingsStore(),
        ),
        scheduleRepository: scheduleRepository,
        airConditionerRepository: _MemoryAirConditionerRepository(),
        roomRepository: _MemoryRoomRepository(),
        energyRepository: _MemoryEnergyRepository(),
        alertRepository: _MemoryAlertRepository(),
        systemSettingsRepository: _MemorySystemSettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin');
    await tester.enterText(fields.at(1), 'test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ตารางเวลา'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manage-schedule-button')), findsOneWidget);
    final todayIndex = DateTime.now().weekday % 7;
    expect(
      find.byKey(
        Key('schedule-overview-day-selected-$todayIndex'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('schedule-selected-date-label')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('schedule-overview-day-1')));
    await tester.pumpAndSettle();
    expect(find.text('ห้อง 16302'), findsOneWidget);
    expect(find.text('ดร.พชร ศรีมุกข์'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manage-schedule-button')));
    await tester.pumpAndSettle();

    expect(find.text('จัดการตารางเรียน'), findsOneWidget);
    final weekdaySelector = find.byKey(
      const Key('schedule-weekday-selector'),
    );
    final saturday = find.byKey(const Key('schedule-day-6'));
    expect(weekdaySelector, findsOneWidget);
    expect(saturday, findsOneWidget);
    expect(
      tester.getRect(saturday).right,
      lessThanOrEqualTo(tester.getRect(weekdaySelector).right),
    );
    await tester.tap(saturday);
    await tester.pumpAndSettle();
    expect(find.text('เสาร์'), findsOneWidget);
    await tester.tap(find.byKey(const Key('schedule-day-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-schedule-seed-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('schedule-subject-field')),
      'Advanced Network',
    );
    await tester.tap(find.byKey(const Key('save-schedule-button')));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Network'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-schedule-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('schedule-subject-field')),
      'IoT Workshop',
    );
    await tester.tap(find.byKey(const Key('save-schedule-button')));
    await tester.pumpAndSettle();

    expect(find.text('IoT Workshop'), findsOneWidget);
    expect(
      scheduleRepository.schedules
          .where((schedule) => schedule.roomNumber == '16302')
          .length,
      3,
    );

    expect(
      find.byKey(const Key('clear-all-schedules-button')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('clear-all-schedules-button')));
    await tester.pumpAndSettle();
    expect(find.text('ล้างตารางเรียนทั้งหมดหรือไม่?'), findsOneWidget);
    expect(
      find.textContaining('5 รายการจากทุกห้อง'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();
    expect(scheduleRepository.schedules.length, 5);

    await tester.tap(find.byKey(const Key('clear-all-schedules-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-clear-all-schedules')),
    );
    await tester.pumpAndSettle();

    expect(scheduleRepository.schedules, isEmpty);
    expect(find.text('ยังไม่ได้เพิ่มวิชา'), findsOneWidget);
  });

  testWidgets('admin adds and deletes the special room CL503', (tester) async {
    final roomRepository = _MemoryRoomRepository();
    _useTallScreen(tester);
    await tester.pumpWidget(
      CpeAirRemoteApp(
        authRepository: _FakeAuthRepository(),
        appSettingsController: AppSettingsController(
          store: _MemoryAppSettingsStore(),
        ),
        scheduleRepository: _MemoryScheduleRepository(),
        airConditionerRepository: _MemoryAirConditionerRepository(),
        roomRepository: roomRepository,
        energyRepository: _MemoryEnergyRepository(),
        alertRepository: _MemoryAlertRepository(),
        systemSettingsRepository: _MemorySystemSettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin');
    await tester.enterText(fields.at(1), 'test-password');
    await tester.tap(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ควบคุม'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manage-rooms-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-room-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('room-number-field')),
      'CL503',
    );
    await tester.enterText(
      find.byKey(const Key('room-floor-field')),
      '0',
    );
    await tester.enterText(
      find.byKey(const Key('room-index-field')),
      '503',
    );
    await tester.enterText(
      find.byKey(const Key('room-type-field')),
      'Special Computer Laboratory',
    );
    await tester.tap(find.byKey(const Key('save-room-button')));
    await tester.pumpAndSettle();

    expect(roomRepository.rooms.any((room) => room.number == 'CL503'), isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const Key('delete-room-CL503')),
      300,
    );
    await tester.tap(find.byKey(const Key('delete-room-CL503')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-room-CL503')));
    await tester.pumpAndSettle();
    expect(roomRepository.rooms.any((room) => room.number == 'CL503'), isFalse);
  });
}

class _MemorySystemSettingsRepository implements SystemSettingsRepository {
  SystemSettings _settings = const SystemSettings(autoOffEnabled: true);

  @override
  Future<SystemSettings> fetchSettings() async => _settings;

  @override
  Future<SystemSettings> setAutoOffEnabled(bool enabled) async {
    _settings = SystemSettings(autoOffEnabled: enabled);
    return _settings;
  }
}

class _MemoryAppSettingsStore implements AppSettingsStore {
  bool darkMode = false;
  String? themeCode;

  @override
  Future<String?> loadThemeCode() async => themeCode;

  @override
  Future<void> saveThemeCode(String code) async {
    themeCode = code;
  }
  String? languageCode;
  double? electricityRate;

  @override
  Future<bool> loadDarkMode() async => darkMode;

  @override
  Future<String?> loadLanguageCode() async => languageCode;

  @override
  Future<double?> loadElectricityRate() async => electricityRate;

  @override
  Future<void> saveDarkMode(bool enabled) async {
    darkMode = enabled;
  }

  @override
  Future<void> saveLanguageCode(String languageCode) async {
    this.languageCode = languageCode;
  }

  @override
  Future<void> saveElectricityRate(double rate) async {
    electricityRate = rate;
  }

  String? textScaleCode;
  String? alertPreferences;

  @override
  Future<String?> loadTextScaleCode() async => textScaleCode;

  @override
  Future<void> saveTextScaleCode(String code) async {
    textScaleCode = code;
  }

  @override
  Future<String?> loadAlertPreferences() async => alertPreferences;

  @override
  Future<void> saveAlertPreferences(String encoded) async {
    alertPreferences = encoded;
  }
}

class _MemoryAirConditionerRepository
    implements AirConditionerRepository {
  final devices = <AirConditioner>[
    AirConditioner(
      id: 1,
      name: 'Air 1',
      deviceId: 'ESP32-AABBCCDDEEFF',
      roomNumber: '16301',
      bleName: 'RMUTT-AC-AABBCCDDEEFF',
      isOnline: true,
      isOn: true,
      temperature: 24,
      power: 900,
    ),
  ];

  @override
  Future<List<AirConditioner>> fetchAll() async {
    return devices.map((device) => device.editableCopy()).toList();
  }

  @override
  Future<void> remove(String deviceId) async {
    devices.removeWhere((device) => device.deviceId == deviceId);
  }

  @override
  Future<void> rename(String deviceId, String name) async {
    devices.firstWhere((device) => device.deviceId == deviceId).name = name;
  }

  @override
  Future<AirProvisioningReservation> reserve(
    AirProvisioningRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendCommand(AirConditioner air) async {}

  @override
  Future<void> enterSetupMode(String deviceId) async {}
}

class _MemoryRoomRepository implements RoomRepository {
  final List<Room> rooms = MockData.createRooms();

  @override
  Future<Room> createRoom(Room room) async {
    if (rooms.any((existing) => existing.number == room.number)) {
      throw StateError('Room already exists.');
    }
    rooms.add(room);
    return room;
  }

  @override
  Future<void> deleteRoom(String roomNumber) async {
    rooms.removeWhere((room) => room.number == roomNumber);
  }

  @override
  Future<List<Room>> fetchRooms() async {
    return rooms.map((room) => room.copyWith(airConditioners: [])).toList();
  }

  @override
  Future<Room> updateRoom(Room room) async {
    final index = rooms.indexWhere(
      (existing) => existing.number == room.number,
    );
    rooms[index] = room;
    return room;
  }
}

class _MemoryScheduleRepository implements ScheduleRepository {
  final List<ClassSchedule> schedules = [
    const ClassSchedule(
      id: 'seed-1',
      roomNumber: '16302',
      dayOfWeek: 1,
      subjectName: 'Computer Network',
      section: '(T) 68346CPE',
      instructor: 'ดร.พชร ศรีมุกข์',
      startTime: '09:00',
      endTime: '12:00',
    ),
    const ClassSchedule(
      id: 'seed-2',
      roomNumber: '16302',
      dayOfWeek: 1,
      subjectName: 'Embedded Systems',
      startTime: '13:00',
      endTime: '16:00',
    ),
    const ClassSchedule(
      id: 'seed-3',
      roomNumber: '16304',
      dayOfWeek: 1,
      subjectName: 'Computer Network',
      startTime: '09:00',
      endTime: '12:00',
    ),
    const ClassSchedule(
      id: 'seed-4',
      roomNumber: '16304',
      dayOfWeek: 1,
      subjectName: 'Embedded Systems',
      startTime: '13:00',
      endTime: '16:00',
    ),
  ];

  int _nextId = 1;

  @override
  Future<ClassSchedule> createSchedule(ClassSchedule schedule) async {
    final created = schedule.copyWith(id: 'created-${_nextId++}');
    schedules.add(created);
    return created;
  }

  @override
  Future<void> deleteSchedule(String id) async {
    schedules.removeWhere((schedule) => schedule.id == id);
  }

  @override
  Future<int> deleteAllSchedules() async {
    final deletedCount = schedules.length;
    schedules.clear();
    return deletedCount;
  }

  @override
  Future<List<ClassSchedule>> fetchSchedules() async {
    return List.of(schedules);
  }

  @override
  Future<ScheduleImportResult> importSchedulePreview(
    ScheduleImportPreview preview,
  ) async {
    schedules
      ..clear()
      ..addAll(
        preview.schedules.map(
          (entry) => ClassSchedule(
            id: 'imported-${_nextId++}',
            roomNumber: entry.roomNumber,
            dayOfWeek: entry.dayOfWeek,
            subjectName: entry.subjectName,
            section: entry.section,
            instructor: entry.instructor,
            startTime: entry.startTime,
            endTime: entry.endTime,
          ),
        ),
      );
    return ScheduleImportResult(
      importedCount: preview.scheduleCount,
      replacedRooms: preview.roomNumbers,
      createdRooms: preview.newRooms,
    );
  }

  @override
  Future<ScheduleImportPreview> previewScheduleFile({
    required String fileName,
    required Uint8List bytes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ClassSchedule> updateSchedule(ClassSchedule schedule) async {
    final index = schedules.indexWhere((item) => item.id == schedule.id);
    schedules[index] = schedule;
    return schedule;
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.rememberedLogin});

  RememberedLogin? rememberedLogin;

  @override
  Future<void> clearRememberedLogin() async {
    rememberedLogin = null;
  }

  @override
  Future<AdminContact> getAdminContact() async {
    return const AdminContact(name: 'Admin', phone: '0812345678');
  }

  @override
  Future<RememberedLogin?> loadRememberedLogin() async => rememberedLogin;

  @override
  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    return const AuthUser(
      username: 'admin',
      firstName: 'RMUTT',
      lastName: 'Admin',
      email: 'admin@example.com',
      role: 'admin',
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    return AuthUser(
      username: 'admin',
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      role: 'admin',
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> saveRememberedLogin({
    required String username,
    required String password,
  }) async {
    rememberedLogin = RememberedLogin(username: username, password: password);
  }

  @override
  Future<String> requestPasswordReset(String identifier) async {
    return 'request-id';
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {}

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<String> verifyPasswordResetOtp({
    required String requestId,
    required String otp,
  }) async {
    return 'reset-token';
  }
}

class _MemoryEnergyRepository implements EnergyRepository {
  @override
  Future<EnergySummary> fetchSummary({
    required EnergyPeriodKind kind,
    DateTime? from,
    DateTime? to,
    int? floor,
  }) async {
    return const EnergySummary(
      kind: EnergyPeriodKind.week,
      from: '2026-08-15',
      to: '2026-08-21',
      days: 7,
      granularity: 'day',
      totalKwh: 42.5,
      previousKwh: 50,
      changePercent: -15,
      runtimeMinutes: 120,
      peakPowerWatts: 900,
      deviceCount: 1,
      series: [
        EnergySeriesPoint(label: '08-20', date: '2026-08-20', kwh: 20),
        EnergySeriesPoint(label: '08-21', date: '2026-08-21', kwh: 22.5),
      ],
      rooms: [
        EnergyRoomUsage(
          roomNumber: '16301',
          floorNumber: 3,
          roomType: 'Meeting Room',
          kwh: 42.5,
          runtimeMinutes: 120,
          deviceCount: 1,
        ),
      ],
      devices: [],
    );
  }

  @override
  Future<List<EnergyMetric>> fetchMetrics() async => const [];

  @override
  Future<EnergyLiveSnapshot> fetchLive() async => EnergyLiveSnapshot.empty;

  @override
  Future<EnergySourceCatalog> fetchSources() async =>
      EnergySourceCatalog.empty;

  @override
  Future<EnergyHistoryResult> fetchHistory(EnergyQuery query) async =>
      EnergyHistoryResult.empty;

  @override
  Future<EnergyExportFile> downloadExport(
    EnergyQuery query, {
    bool english = false,
  }) async {
    return EnergyExportFile(
      fileName: 'export.xlsx',
      bytes: Uint8List(0),
      rowCount: 0,
    );
  }
}

class _MemoryAlertRepository implements AlertRepository {
  @override
  Future<List<SystemAlert>> fetchAlerts({int limit = 30}) async => const [];

  @override
  Future<SystemAlert> acknowledge(String id) async {
    return SystemAlert(
      id: id,
      kind: SystemAlertKind.autoOffSucceeded,
      roomNumber: '16301',
      status: 'acknowledged',
      createdAt: DateTime(2026, 8, 21),
    );
  }
}
