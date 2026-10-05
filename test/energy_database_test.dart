import 'dart:typed_data';

import 'package:cpe_air_remote/controllers/app_settings_controller.dart';
import 'package:cpe_air_remote/controllers/energy_controller.dart';
import 'package:cpe_air_remote/localization/app_localizations.dart';
import 'package:cpe_air_remote/models/energy_data.dart';
import 'package:cpe_air_remote/screens/energy_database_screen.dart';
import 'package:cpe_air_remote/services/energy_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('แสดงค่าไฟสดของแอร์แต่ละเครื่องเป็นภาษาไทย', (tester) async {
    final repository = _MemoryEnergyRepository();
    await _pumpScreen(tester, repository);

    expect(find.text('ค่าไฟสด'), findsOneWidget);
    expect(find.text('ส่งออกเป็น Excel'), findsOneWidget);
    expect(find.text('แอร์ห้องประชุม'), findsOneWidget);
    expect(find.text('แรงดัน'), findsOneWidget);
    expect(find.text('ตัวประกอบกำลัง'), findsOneWidget);
    // 812 W ของเครื่องที่ทำงานอยู่ ต้องแปลงเป็นกิโลวัตต์ให้ถูก
    expect(find.text('0.812 kW'), findsOneWidget);
  });

  testWidgets('เปลี่ยนรอบอัปเดตแล้วตัวควบคุมจำค่าใหม่', (tester) async {
    final repository = _MemoryEnergyRepository();
    final controller = await _pumpScreen(tester, repository);

    expect(controller.refreshSeconds, 5);
    await tester.tap(find.text('30 วินาที'));
    await tester.pump();

    expect(controller.refreshSeconds, 30);
  });

  testWidgets('โหมดสรุปซ่อนการเลือกห้องและค่าที่ละเอียดเกินไป', (tester) async {
    final repository = _MemoryEnergyRepository();
    await _pumpScreen(tester, repository);
    await tester.tap(find.text('ส่งออกเป็น Excel'));
    await tester.pumpAndSettle();

    expect(find.text('ทั้งอาคาร'), findsOneWidget);
    expect(find.text('แยกตามเครื่องแอร์'), findsOneWidget);
    // ยังอยู่โหมดสรุป จึงไม่มีการ์ดเลือกห้อง และไม่มีค่าที่ต้องรายละเอียดสูง
    expect(find.text('เลือกทั้งหมด'), findsNothing);
    expect(find.text('แรงดันต่ำสุด (V)'), findsNothing);
  });

  testWidgets('เลือกรายเครื่องแล้วเลือกห้องกับเครื่องแอร์ได้', (tester) async {
    final repository = _MemoryEnergyRepository();
    await _pumpScreen(tester, repository);
    await tester.tap(find.text('ส่งออกเป็น Excel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('แยกตามเครื่องแอร์'));
    await tester.pumpAndSettle();

    expect(find.text('รายละเอียดสูง'), findsNWidgets(2));
    expect(find.text('16302 · 1 เครื่อง'), findsOneWidget);
    expect(find.text('แอร์ห้องประชุม'), findsWidgets);
    // ค่าที่เปิดเฉพาะโหมดรายละเอียดสูงต้องโผล่มาแล้ว
    expect(find.text('แรงดันต่ำสุด (V)'), findsOneWidget);
  });

  testWidgets('กดดูตัวอย่างแล้วขอข้อมูลตามเงื่อนไขที่เลือกจริง', (tester) async {
    final repository = _MemoryEnergyRepository();
    final controller = await _pumpScreen(tester, repository);
    await tester.tap(find.text('ส่งออกเป็น Excel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('แยกตามห้อง'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ดูตัวอย่าง'));
    await tester.pumpAndSettle();

    final query = repository.lastQuery!;
    expect(query.scope, EnergyScope.room);
    expect(query.isSingleDay, isTrue, reason: 'ค่าเริ่มต้นคือวันนี้วันเดียว');
    expect(query.metrics, contains('consumption'));
    expect(controller.hasPreview, isTrue);
    expect(find.text('15:00-16:00'), findsOneWidget);
  });
}

Future<EnergyController> _pumpScreen(
  WidgetTester tester,
  EnergyRepository repository,
) async {
  // จอทดสอบมาตรฐาน 800x600 เตี้ยกว่าหน้านี้ ของที่อยู่ใต้ขอบจอจะไม่ถูกสร้าง
  // ขึ้นมาเลย finder เลยหาไม่เจอทั้งที่โค้ดถูก
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = EnergyController(repository: repository);
  final settings = AppSettingsController(store: _MemorySettingsStore());
  await settings.initialize();

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('th'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: EnergyDatabaseScreen(
        controller: controller,
        appSettingsController: settings,
      ),
    ),
  );
  // ปล่อยให้ initialize() ทำงานจบก่อน แล้วปิดรอบอัตโนมัติ
  // ถ้าปล่อยให้ Timer.periodic เดินต่อ pumpAndSettle จะวนไม่จบ
  await tester.pump();
  controller.stopLiveUpdates();
  await tester.pumpAndSettle();
  return controller;
}

class _MemoryEnergyRepository implements EnergyRepository {
  EnergyQuery? lastQuery;

  @override
  Future<List<EnergyMetric>> fetchMetrics() async => const [
    EnergyMetric(
      key: 'consumption',
      labelTh: 'พลังงานที่ใช้',
      labelEn: 'Consumption',
      unit: 'kWh',
      decimals: 3,
      detailOnly: false,
      isDefault: true,
    ),
    EnergyMetric(
      key: 'voltageMin',
      labelTh: 'แรงดันต่ำสุด',
      labelEn: 'Lowest voltage',
      unit: 'V',
      decimals: 1,
      detailOnly: true,
      isDefault: false,
    ),
  ];

  @override
  Future<EnergyLiveSnapshot> fetchLive() async => EnergyLiveSnapshot(
    readings: const [
      EnergyLiveReading(
        deviceId: 'ESP32-AABBCCDDEEFF',
        roomNumber: '16302',
        floorNumber: 3,
        name: 'แอร์ห้องประชุม',
        airNumber: 1,
        isOnline: true,
        pzemAvailable: true,
        acRunning: true,
        voltage: 224.6,
        current: 3.712,
        powerWatts: 812.0,
        energyKwh: 145.221,
        frequencyHz: 50.02,
        powerFactor: 0.974,
      ),
    ],
    deviceCount: 1,
    onlineCount: 1,
    runningCount: 1,
    totalPowerWatts: 812.0,
    receivedAt: DateTime(2026, 8, 21, 15, 30),
  );

  @override
  Future<EnergySourceCatalog> fetchSources() async => EnergySourceCatalog(
    rooms: const [
      EnergyRoomSource(
        roomNumber: '16302',
        floorNumber: 3,
        deviceCount: 1,
        bucketCount: 12,
      ),
    ],
    devices: const [
      EnergyDeviceSource(
        deviceId: 'ESP32-AABBCCDDEEFF',
        roomNumber: '16302',
        floorNumber: 3,
        name: 'แอร์ห้องประชุม',
        airNumber: 1,
        bucketCount: 12,
        archived: false,
      ),
    ],
    oldestDate: DateTime(2026, 8, 20),
    newestDate: DateTime(2026, 8, 21),
  );

  @override
  Future<EnergySummary> fetchSummary({
    required EnergyPeriodKind kind,
    DateTime? from,
    DateTime? to,
    int? floor,
  }) async => EnergySummary.empty;

  @override
  Future<EnergyHistoryResult> fetchHistory(EnergyQuery query) async {
    lastQuery = query;
    return const EnergyHistoryResult(
      rows: [
        EnergyHistoryRow(
          date: '2026-08-21',
          time: '15:00-16:00',
          hour: 15,
          values: {'consumption': 1.234},
          roomNumber: '16302',
        ),
      ],
      metricKeys: ['consumption'],
      totals: {'consumption': 1.234},
    );
  }

  @override
  Future<EnergyExportFile> downloadExport(
    EnergyQuery query, {
    bool english = false,
  }) async {
    lastQuery = query;
    return EnergyExportFile(
      fileName: 'ข้อมูลไฟฟ้า.xlsx',
      bytes: Uint8List(0),
      rowCount: 1,
    );
  }
}

class _MemorySettingsStore implements AppSettingsStore {
  bool _darkMode = false;
  String? _languageCode = 'th';
  double _rate = 4.5;

  @override
  Future<bool> loadDarkMode() async => _darkMode;

  @override
  Future<void> saveDarkMode(bool enabled) async => _darkMode = enabled;

  String? _themeCode;

  @override
  Future<String?> loadThemeCode() async => _themeCode;

  @override
  Future<void> saveThemeCode(String code) async => _themeCode = code;

  @override
  Future<String?> loadLanguageCode() async => _languageCode;

  @override
  Future<void> saveLanguageCode(String languageCode) async =>
      _languageCode = languageCode;

  @override
  Future<double?> loadElectricityRate() async => _rate;

  @override
  Future<void> saveElectricityRate(double rate) async => _rate = rate;

  String? _textScaleCode;
  String? _alertPreferences;

  @override
  Future<String?> loadTextScaleCode() async => _textScaleCode;

  @override
  Future<void> saveTextScaleCode(String code) async => _textScaleCode = code;

  @override
  Future<String?> loadAlertPreferences() async => _alertPreferences;

  @override
  Future<void> saveAlertPreferences(String encoded) async =>
      _alertPreferences = encoded;
}
