import 'package:flutter/foundation.dart';

import '../services/system_settings_repository.dart';

/// ตัวควบคุมค่าตั้งระดับระบบ
///
/// แยกจาก `AppSettingsController` เพราะคนละที่เก็บและคนละสิทธิ์
/// ตัวนั้นอยู่ในเครื่องผู้ใช้และใครก็แก้ได้ ตัวนี้อยู่บนเซิร์ฟเวอร์และ
/// แก้ได้เฉพาะแอดมิน
class SystemSettingsController extends ChangeNotifier {
  SystemSettingsController({required this.repository});

  final SystemSettingsRepository repository;

  SystemSettings settings = SystemSettings.unknown;
  bool isLoading = false;
  bool hasLoaded = false;
  bool isSaving = false;
  String? errorMessage;

  bool get autoOffEnabled => settings.autoOffEnabled;
  bool get autoOffTestMode => settings.autoOffTestMode;

  Future<void> initialize() async {
    if (hasLoaded || isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    try {
      settings = await repository.fetchSettings();
      errorMessage = null;
      hasLoaded = true;
    } catch (error) {
      errorMessage = _readable(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// เปิดปิดระบบปิดแอร์อัตโนมัติทั้งอาคาร
  ///
  /// แสดงผลใหม่ทันทีตั้งแต่ยังไม่ได้คำตอบ แล้วถอยกลับถ้าเซิร์ฟเวอร์ปฏิเสธ
  /// สวิตช์ที่ค้างรอสองวินาทีทุกครั้งที่กดใช้งานไม่ไหว
  Future<bool> setAutoOffEnabled(bool enabled) async {
    if (isSaving) return false;

    final previous = settings;
    settings = settings.copyWith(autoOffEnabled: enabled);
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      settings = await repository.setAutoOffEnabled(enabled);
      return true;
    } catch (error) {
      settings = previous;
      errorMessage = _readable(error);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// เปิดปิดโหมดทดสอบการปิดแอร์อัตโนมัติ (นอกคาบเรียน 30 วินาที · ในคาบเรียน 1 นาที)
  Future<bool> setAutoOffTestMode(bool testMode) async {
    if (isSaving) return false;

    final previous = settings;
    settings = settings.copyWith(autoOffTestMode: testMode);
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      settings = await repository.setAutoOffTestMode(testMode);
      return true;
    } catch (error) {
      settings = previous;
      errorMessage = _readable(error);
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  String _readable(Object error) {
    return error.toString().replaceFirst('ApiException: ', '');
  }
}
