import 'package:cpe_air_remote/controllers/system_settings_controller.dart';
import 'package:cpe_air_remote/services/system_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemSettings', () {
    test('ค่าที่หายไปจากเซิร์ฟเวอร์ถือว่าเปิดอยู่', () {
      // ตรงกับค่าเริ่มต้นฝั่ง Backend ถ้าตีความกลับกัน ระบบจะดูเหมือนพัง
      expect(SystemSettings.fromJson(const {}).autoOffEnabled, isTrue);
      expect(
        SystemSettings.fromJson(const {'autoOffEnabled': false}).autoOffEnabled,
        isFalse,
      );
    });
  });

  group('SystemSettingsController', () {
    test('โหลดค่าจากเซิร์ฟเวอร์ตอนเริ่ม', () async {
      final repository = _MemoryRepository(autoOffEnabled: false);
      final controller = SystemSettingsController(repository: repository);

      await controller.initialize();

      expect(controller.autoOffEnabled, isFalse);
      expect(controller.hasLoaded, isTrue);
      expect(controller.errorMessage, isNull);
    });

    test('กดสวิตช์แล้วเห็นผลทันที ไม่ต้องรอเซิร์ฟเวอร์ตอบ', () async {
      final repository = _MemoryRepository(delay: true);
      final controller = SystemSettingsController(repository: repository);
      await controller.initialize();

      final pending = controller.setAutoOffEnabled(false);
      // ยังไม่ได้คำตอบ แต่สวิตช์ต้องขยับแล้ว
      expect(controller.autoOffEnabled, isFalse);
      expect(controller.isSaving, isTrue);

      expect(await pending, isTrue);
      expect(controller.isSaving, isFalse);
      expect(repository.saved, [false]);
    });

    test('เซิร์ฟเวอร์ปฏิเสธแล้วสวิตช์ต้องเด้งกลับ ไม่ใช่ค้างผิด', () async {
      final repository = _MemoryRepository(failOnWrite: true);
      final controller = SystemSettingsController(repository: repository);
      await controller.initialize();
      expect(controller.autoOffEnabled, isTrue);

      expect(await controller.setAutoOffEnabled(false), isFalse);

      expect(controller.autoOffEnabled, isTrue);
      expect(controller.errorMessage, isNotNull);
    });

    test('อ่านค่าไม่ได้ก็ยังใช้แอปต่อได้ ไม่ค้างที่หน้าโหลด', () async {
      final repository = _MemoryRepository(failOnRead: true);
      final controller = SystemSettingsController(repository: repository);

      await controller.initialize();

      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNotNull);
      // ถอยไปใช้ค่าเริ่มต้น ไม่ใช่แสดงว่าระบบถูกปิดอยู่
      expect(controller.autoOffEnabled, isTrue);
    });

    test('กดรัว ๆ ไม่ยิงคำขอซ้อนกัน', () async {
      final repository = _MemoryRepository(delay: true);
      final controller = SystemSettingsController(repository: repository);
      await controller.initialize();

      final first = controller.setAutoOffEnabled(false);
      final second = controller.setAutoOffEnabled(true);

      expect(await second, isFalse, reason: 'คำขอที่สองต้องถูกปัดทิ้ง');
      expect(await first, isTrue);
      expect(repository.saved, [false]);
    });
  });
}

class _MemoryRepository implements SystemSettingsRepository {
  _MemoryRepository({
    bool autoOffEnabled = true,
    this.failOnRead = false,
    this.failOnWrite = false,
    this.delay = false,
  }) : _settings = SystemSettings(autoOffEnabled: autoOffEnabled);

  final bool failOnRead;
  final bool failOnWrite;
  final bool delay;
  final saved = <bool>[];

  SystemSettings _settings;

  @override
  Future<SystemSettings> fetchSettings() async {
    if (failOnRead) throw Exception('ApiException: อ่านค่าไม่ได้');
    return _settings;
  }

  @override
  Future<SystemSettings> setAutoOffEnabled(bool enabled) async {
    if (delay) await Future<void>.delayed(const Duration(milliseconds: 10));
    if (failOnWrite) throw Exception('ApiException: บันทึกไม่ได้');
    saved.add(enabled);
    _settings = SystemSettings(autoOffEnabled: enabled);
    return _settings;
  }
}
