import 'package:cpe_air_remote/controllers/app_settings_controller.dart';
import 'package:cpe_air_remote/models/system_alert.dart';
import 'package:cpe_air_remote/utils/alert_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

SystemAlert _alert(String id, SystemAlertKind kind) {
  return SystemAlert(
    id: id,
    kind: kind,
    roomNumber: '16103',
    status: 'open',
    createdAt: DateTime(2026, 9, 11, 10),
  );
}

void main() {
  group('AppThemeChoice', () {
    test('รหัสที่บันทึกไว้อ่านกลับมาได้ครบทุกธีม', () {
      for (final choice in AppThemeChoice.values) {
        expect(AppThemeChoice.fromCode(choice.code), choice);
      }
      expect(AppThemeChoice.fromCode('purple'), isNull);
    });

    test('ยังไม่เคยเลือกอะไรได้ธีมขาว', () async {
      final controller = AppSettingsController(store: _MemoryStore());
      await controller.initialize();

      expect(controller.themeChoice, AppThemeChoice.white);
      expect(controller.isDarkMode, isFalse);
    });

    test('ผู้ใช้รุ่นก่อนที่เปิดโหมดมืดไว้ ได้ธีมเทา', () async {
      final store = _MemoryStore();
      await store.saveDarkMode(true);
      final controller = AppSettingsController(store: store);
      await controller.initialize();

      expect(controller.themeChoice, AppThemeChoice.gray);
      expect(controller.isDarkMode, isTrue);
    });

    test('ธีมที่เลือกถูกบันทึกและอ่านกลับมาได้', () async {
      final store = _MemoryStore();
      await AppSettingsController(store: store).setTheme(AppThemeChoice.green);

      final reloaded = AppSettingsController(store: store);
      await reloaded.initialize();
      expect(reloaded.themeChoice, AppThemeChoice.green);
      expect(reloaded.isDarkMode, isFalse);
    });
  });

  group('AppTextScale', () {
    test('รหัสที่ไม่รู้จักหรือว่างเปล่าถอยไปขนาดปกติ', () {
      expect(AppTextScale.fromCode(null), AppTextScale.normal);
      expect(AppTextScale.fromCode(''), AppTextScale.normal);
      expect(AppTextScale.fromCode('huge'), AppTextScale.normal);
    });

    test('รหัสที่บันทึกไว้อ่านกลับมาได้ครบทุกระดับ', () {
      for (final scale in AppTextScale.values) {
        expect(AppTextScale.fromCode(scale.code), scale);
      }
    });
  });

  group('resolvedTextScale', () {
    test('คูณกับค่าที่ผู้ใช้ตั้งไว้ในระบบ ไม่ใช่ทับค่าเดิม', () async {
      final controller = AppSettingsController(store: _MemoryStore());
      await controller.setTextScale(AppTextScale.large);

      // ตั้งเครื่องไว้ใหญ่ 1.2 อยู่แล้ว เลือกใหญ่ในแอปต้องใหญ่ขึ้นอีก
      expect(controller.resolvedTextScale(1.2), closeTo(1.38, 0.001));
      expect(controller.resolvedTextScale(1.0), closeTo(1.15, 0.001));
    });

    test('มีเพดานกันตัวอักษรใหญ่จนหน้าจอพัง', () async {
      final controller = AppSettingsController(store: _MemoryStore());
      await controller.setTextScale(AppTextScale.extraLarge);

      expect(controller.resolvedTextScale(3.0), 2.0);
    });

    test('ค่าประหลาดจากระบบไม่ทำให้ตัวอักษรหายไป', () async {
      final controller = AppSettingsController(store: _MemoryStore());

      expect(controller.resolvedTextScale(0), 1.0);
      expect(controller.resolvedTextScale(double.nan), 1.0);
    });
  });

  group('AlertPreferences', () {
    test('ค่าเริ่มต้นเปิดครบทุกชนิดทั้งสองช่อง', () {
      final prefs = AlertPreferences.defaults();

      for (final kind in AlertPreferences.configurableKinds) {
        expect(prefs.showsInApp(kind), isTrue, reason: kind.name);
        expect(prefs.pushesToPhone(kind), isTrue, reason: kind.name);
      }
    });

    test('ปิดช่องเด้งแล้วยังขึ้นในแอปอยู่', () {
      final prefs = AlertPreferences.defaults().withChannels(
        SystemAlertKind.autoOffSucceeded,
        const AlertChannels(inApp: true, push: false),
      );

      expect(prefs.showsInApp(SystemAlertKind.autoOffSucceeded), isTrue);
      expect(prefs.pushesToPhone(SystemAlertKind.autoOffSucceeded), isFalse);
      // ชนิดอื่นต้องไม่ถูกกระทบ
      expect(prefs.pushesToPhone(SystemAlertKind.autoOffFailed), isTrue);
    });

    test('ในแอปแสดงครบทุกใบเสมอ ส่วนที่เด้งตามที่ผู้ใช้เลือก', () {
      final prefs = AlertPreferences.defaults()
          .withChannels(
            SystemAlertKind.autoOffSucceeded,
            const AlertChannels(inApp: true, push: false),
          )
          .withChannels(
            SystemAlertKind.outsideScheduleOccupied,
            // ค่า inApp ที่เป็น false ต้องไม่มีผล เพราะผู้ใช้ปิดรายการในแอปไม่ได้
            const AlertChannels(inApp: false, push: false),
          );

      final alerts = [
        _alert('a', SystemAlertKind.outsideScheduleOccupied),
        _alert('b', SystemAlertKind.autoOffSucceeded),
        _alert('c', SystemAlertKind.autoOffFailed),
      ];

      expect(prefs.visible(alerts).map((a) => a.id), ['a', 'b', 'c']);
      expect(prefs.pushable(alerts).map((a) => a.id), ['c']);
    });

    test('ชนิดที่แอปยังไม่รู้จักขึ้นในแอปเสมอ แต่ไม่เด้ง', () {
      final prefs = AlertPreferences.defaults();

      expect(prefs.showsInApp(SystemAlertKind.unknown), isTrue);
      expect(prefs.pushesToPhone(SystemAlertKind.unknown), isFalse);
      // ปิดไม่ได้ด้วย ไม่งั้นชนิดใหม่จาก Backend จะหายเงียบ
      final changed = prefs.withChannels(
        SystemAlertKind.unknown,
        const AlertChannels(inApp: false, push: false),
      );
      expect(changed.showsInApp(SystemAlertKind.unknown), isTrue);
    });

    test('บันทึกแล้วอ่านกลับได้เหมือนเดิม', () {
      final prefs = AlertPreferences.defaults().withChannels(
        SystemAlertKind.autoOffFailed,
        const AlertChannels(inApp: true, push: false),
      );

      expect(AlertPreferences.decode(prefs.encode()), prefs);
    });

    test('ข้อมูลเสียหรือว่างเปล่าถอยไปค่าเริ่มต้น ไม่ทำแอปพัง', () {
      expect(AlertPreferences.decode(null), AlertPreferences.defaults());
      expect(AlertPreferences.decode(''), AlertPreferences.defaults());
      expect(AlertPreferences.decode('ไม่ใช่ json'), AlertPreferences.defaults());
      expect(AlertPreferences.decode('[1,2,3]'), AlertPreferences.defaults());
    });

    test('ชนิดที่ยังไม่มีในข้อมูลเก่าได้ค่าเริ่มต้นของมันเอง', () {
      // ผู้ใช้เดิมที่บันทึกไว้ก่อนมีชนิดนี้ ต้องไม่ถูกปิดการแจ้งเตือนไปเงียบ ๆ
      final prefs = AlertPreferences.decode(
        '{"autoOffFailed":{"inApp":false,"push":false}}',
      );

      // ค่า inApp เก่าที่เคยปิดไว้ถูกทิ้ง ในแอปแสดงเสมอ แต่ค่าเด้งยังจำไว้
      expect(prefs.showsInApp(SystemAlertKind.autoOffFailed), isTrue);
      expect(prefs.pushesToPhone(SystemAlertKind.autoOffFailed), isFalse);
      expect(prefs.showsInApp(SystemAlertKind.autoOffSucceeded), isTrue);
      expect(prefs.pushesToPhone(SystemAlertKind.autoOffSucceeded), isTrue);
    });

    test('ปิดสวิตช์หลักแล้วไม่แจ้งเตือนเลย แต่ยังจำค่ารายประเภทไว้', () {
      final prefs = AlertPreferences.defaults().withEnabled(false);
      final alerts = [
        _alert('a', SystemAlertKind.outsideScheduleOccupied),
        _alert('b', SystemAlertKind.autoOffFailed),
      ];

      expect(prefs.pushable(alerts), isEmpty);
      expect(prefs.visible(alerts).map((a) => a.id), ['a', 'b']);
      expect(prefs.typeSelected(SystemAlertKind.autoOffFailed), isTrue);
      expect(
        prefs.withEnabled(true).pushable(alerts).map((a) => a.id),
        ['a', 'b'],
      );
    });

    test('สวิตช์หลักบันทึกแล้วอ่านกลับได้ ข้อมูลรุ่นก่อนถือว่าเปิด', () {
      final off = AlertPreferences.defaults().withEnabled(false);

      expect(AlertPreferences.decode(off.encode()), off);
      expect(
        AlertPreferences.decode(
          '{"autoOffFailed":{"inApp":true,"push":true}}',
        ).enabled,
        isTrue,
      );
    });
  });

  group('freshAlerts', () {
    test('คืนเฉพาะใบที่ยังไม่เคยเห็น', () {
      final seen = {'a', 'b'};
      final fresh = freshAlerts(
        alerts: [
          _alert('a', SystemAlertKind.autoOffFailed),
          _alert('c', SystemAlertKind.autoOffFailed),
        ],
        seenIds: seen,
      );

      expect(fresh.map((a) => a.id), ['c']);
    });

    test('ใบที่ไม่มีรหัสไม่ถือว่าใหม่ กันการเด้งซ้ำไม่รู้จบ', () {
      final fresh = freshAlerts(
        alerts: [_alert('', SystemAlertKind.autoOffFailed)],
        seenIds: const {},
      );

      expect(fresh, isEmpty);
    });
  });

  group('AppSettingsController จำค่าที่ตั้งไว้', () {
    test('ขนาดตัวอักษรและสวิตช์แจ้งเตือนกลับมาหลังเปิดแอปใหม่', () async {
      final store = _MemoryStore();
      final first = AppSettingsController(store: store);
      await first.initialize();
      await first.setTextScale(AppTextScale.extraLarge);
      await first.setAlertChannels(
        SystemAlertKind.autoOffSucceeded,
        const AlertChannels(inApp: true, push: false),
      );

      final second = AppSettingsController(store: store);
      await second.initialize();

      expect(second.textScale, AppTextScale.extraLarge);
      expect(
        second.alertPreferences.pushesToPhone(SystemAlertKind.autoOffSucceeded),
        isFalse,
      );
      expect(
        second.alertPreferences.showsInApp(SystemAlertKind.autoOffSucceeded),
        isTrue,
      );
    });

    test('สวิตช์หลักของการแจ้งเตือนกลับมาหลังเปิดแอปใหม่', () async {
      final store = _MemoryStore();
      final first = AppSettingsController(store: store);
      await first.initialize();
      await first.setNotificationsEnabled(false);

      final second = AppSettingsController(store: store);
      await second.initialize();

      expect(second.alertPreferences.enabled, isFalse);
      expect(
        second.alertPreferences.pushesToPhone(SystemAlertKind.autoOffFailed),
        isFalse,
      );
    });

    test('ตั้งค่าเดิมซ้ำไม่แจ้งผู้ฟัง จะได้ไม่วาดใหม่เปล่า ๆ', () async {
      final controller = AppSettingsController(store: _MemoryStore());
      await controller.initialize();

      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setTextScale(AppTextScale.normal);
      expect(notifications, 0);

      await controller.setTextScale(AppTextScale.large);
      expect(notifications, 1);
    });
  });
}

class _MemoryStore implements AppSettingsStore {
  bool _darkMode = false;
  String? _languageCode;
  double? _rate;
  String? _textScaleCode;
  String? _alertPreferences;

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
