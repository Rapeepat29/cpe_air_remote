import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart';

import '../models/system_alert.dart';
import '../utils/alert_preferences.dart';

abstract interface class AppSettingsStore {
  Future<bool> loadDarkMode();

  Future<void> saveDarkMode(bool enabled);

  Future<String?> loadLanguageCode();

  Future<void> saveLanguageCode(String languageCode);

  Future<double?> loadElectricityRate();

  Future<void> saveElectricityRate(double rate);

  Future<String?> loadTextScaleCode();

  Future<void> saveTextScaleCode(String code);

  Future<String?> loadAlertPreferences();

  Future<void> saveAlertPreferences(String encoded);
}

class SecureAppSettingsStore implements AppSettingsStore {
  SecureAppSettingsStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const _darkModeKey = 'app_dark_mode';
  static const _languageCodeKey = 'app_language_code';
  static const _electricityRateKey = 'app_electricity_rate';
  static const _textScaleKey = 'app_text_scale';
  static const _alertPreferencesKey = 'app_alert_preferences';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> loadDarkMode() async {
    return await _storage.read(key: _darkModeKey) == 'true';
  }

  @override
  Future<void> saveDarkMode(bool enabled) {
    return _storage.write(
      key: _darkModeKey,
      value: enabled.toString(),
    );
  }

  @override
  Future<String?> loadLanguageCode() {
    return _storage.read(key: _languageCodeKey);
  }

  @override
  Future<void> saveLanguageCode(String languageCode) {
    return _storage.write(
      key: _languageCodeKey,
      value: languageCode,
    );
  }

  @override
  Future<double?> loadElectricityRate() async {
    final savedValue = await _storage.read(key: _electricityRateKey);
    return savedValue == null ? null : double.tryParse(savedValue);
  }

  @override
  Future<void> saveElectricityRate(double rate) {
    return _storage.write(
      key: _electricityRateKey,
      value: rate.toStringAsFixed(2),
    );
  }

  @override
  Future<String?> loadTextScaleCode() {
    return _storage.read(key: _textScaleKey);
  }

  @override
  Future<void> saveTextScaleCode(String code) {
    return _storage.write(key: _textScaleKey, value: code);
  }

  @override
  Future<String?> loadAlertPreferences() {
    return _storage.read(key: _alertPreferencesKey);
  }

  @override
  Future<void> saveAlertPreferences(String encoded) {
    return _storage.write(key: _alertPreferencesKey, value: encoded);
  }
}

enum AppLanguage {
  thai('th'),
  english('en');

  const AppLanguage(this.code);

  final String code;

  static AppLanguage fromCode(String? code) {
    return switch (code) {
      'en' => AppLanguage.english,
      _ => AppLanguage.thai,
    };
  }
}

/// ขนาดตัวอักษรที่ผู้ใช้เลือกได้ในหน้าตั้งค่า
///
/// เป็นตัวคูณ ไม่ใช่ขนาดตายตัว จึงเอาไปคูณกับค่าที่ผู้ใช้ตั้งไว้ในระบบ Android
/// อีกที คนที่ตั้งตัวอักษรใหญ่ไว้ทั้งเครื่องจะได้ไม่โดนแอปบังคับให้เล็กลง
enum AppTextScale {
  small('small', 0.90),
  normal('normal', 1.00),
  large('large', 1.15),
  extraLarge('extra_large', 1.30);

  const AppTextScale(this.code, this.factor);

  final String code;
  final double factor;

  /// ป้ายภาษาอังกฤษ ให้ตัวแปลของแอปแปลต่ออีกที
  String get label => switch (this) {
    AppTextScale.small => 'Small',
    AppTextScale.normal => 'Normal',
    AppTextScale.large => 'Large',
    AppTextScale.extraLarge => 'Extra large',
  };

  static AppTextScale fromCode(String? code) {
    for (final scale in AppTextScale.values) {
      if (scale.code == code) return scale;
    }
    return AppTextScale.normal;
  }
}

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    AppSettingsStore? store,
  }) : _store = store ?? SecureAppSettingsStore();

  final AppSettingsStore _store;

  static const defaultElectricityRate = 4.50;
  static const minimumElectricityRate = 0.01;
  static const maximumElectricityRate = 100.00;

  bool _isDarkMode = false;
  AppLanguage _language = AppLanguage.thai;
  double _electricityRate = defaultElectricityRate;
  AppTextScale _textScale = AppTextScale.normal;
  AlertPreferences _alertPreferences = AlertPreferences.defaults();

  bool get isDarkMode => _isDarkMode;

  AppLanguage get language => _language;

  double get electricityRate => _electricityRate;

  AppTextScale get textScale => _textScale;

  AlertPreferences get alertPreferences => _alertPreferences;

  Locale get locale => Locale(_language.code);

  /// ตัวคูณสุดท้ายที่ควรใช้จริง เอาค่าของระบบมาคูณกับที่ผู้ใช้เลือกในแอป
  ///
  /// จำกัดเพดานไว้ไม่ให้ตัวอักษรใหญ่จนหน้าจอพัง คนที่ตั้งเครื่องไว้ใหญ่สุด
  /// แล้วมาเลือก `ใหญ่มาก` ในแอปอีก จะได้ไม่เจอปุ่มที่กดไม่ได้
  double resolvedTextScale(double systemScale) {
    final combined = systemScale * _textScale.factor;
    if (!combined.isFinite || combined <= 0) return _textScale.factor;
    return combined.clamp(0.8, 2.0);
  }

  double calculateElectricityCost(double energyKwh) {
    return energyKwh * _electricityRate;
  }

  static bool isValidElectricityRate(double? rate) {
    return rate != null &&
        rate.isFinite &&
        rate >= minimumElectricityRate &&
        rate <= maximumElectricityRate;
  }

  Future<void> initialize() async {
    try {
      _isDarkMode = await _store.loadDarkMode();
    } catch (_) {
      // Keep the light theme when its saved value is unavailable.
    }

    try {
      _language = AppLanguage.fromCode(await _store.loadLanguageCode());
    } catch (_) {
      // Keep Thai when the saved language is unavailable.
    }

    try {
      final savedRate = await _store.loadElectricityRate();
      if (isValidElectricityRate(savedRate)) {
        _electricityRate = savedRate!;
      }
    } catch (_) {
      // Keep the default rate when its saved value is unavailable.
    }

    try {
      _textScale = AppTextScale.fromCode(await _store.loadTextScaleCode());
    } catch (_) {
      // Keep the normal size when its saved value is unavailable.
    }

    try {
      _alertPreferences = AlertPreferences.decode(
        await _store.loadAlertPreferences(),
      );
    } catch (_) {
      // Keep every alert switched on when the saved value is unavailable.
    }

    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_isDarkMode == enabled) {
      return;
    }

    _isDarkMode = enabled;
    notifyListeners();

    try {
      await _store.saveDarkMode(enabled);
    } catch (_) {
      // The selected theme still applies for the current session.
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) {
      return;
    }

    _language = language;
    notifyListeners();

    try {
      await _store.saveLanguageCode(language.code);
    } catch (_) {
      // The selected language still applies for the current session.
    }
  }

  Future<void> setTextScale(AppTextScale scale) async {
    if (_textScale == scale) {
      return;
    }

    _textScale = scale;
    notifyListeners();

    try {
      await _store.saveTextScaleCode(scale.code);
    } catch (_) {
      // The selected size still applies for the current session.
    }
  }

  Future<void> setAlertChannels(
    SystemAlertKind kind,
    AlertChannels channels,
  ) async {
    final next = _alertPreferences.withChannels(kind, channels);
    if (next == _alertPreferences) {
      return;
    }

    _alertPreferences = next;
    notifyListeners();

    try {
      await _store.saveAlertPreferences(next.encode());
    } catch (_) {
      // The selected switches still apply for the current session.
    }
  }

  Future<void> setElectricityRate(double rate) async {
    if (!isValidElectricityRate(rate)) {
      throw ArgumentError.value(rate, 'rate', 'Invalid electricity rate');
    }
    if (_electricityRate == rate) {
      return;
    }

    _electricityRate = rate;
    notifyListeners();

    try {
      await _store.saveElectricityRate(rate);
    } catch (_) {
      // The selected rate still applies for the current session.
    }
  }
}
