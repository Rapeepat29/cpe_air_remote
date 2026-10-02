import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/energy_data.dart';
import '../models/system_alert.dart';
import '../services/alert_repository.dart';
import '../services/energy_repository.dart';
import '../utils/alert_preferences.dart';

/// ตัวเลขจริงของหน้าหลักและหน้าสถิติ พร้อมรายการแจ้งเตือนของระบบ
///
/// ทั้งสองหน้าใช้ตัวควบคุมเดียวกัน เปลี่ยนช่วงเวลาที่หน้าไหนก็เห็นตรงกันทันที
class DashboardController extends ChangeNotifier {
  DashboardController({
    required this.energyRepository,
    required this.alertRepository,
  });

  final EnergyRepository energyRepository;
  final AlertRepository alertRepository;

  static const _refreshInterval = Duration(seconds: 30);

  EnergySummary summary = EnergySummary.empty;

  List<SystemAlert> _allAlerts = const [];
  AlertPreferences _alertPreferences = AlertPreferences.defaults();

  /// รหัสใบที่เคยเห็นแล้ว ใช้แยกว่าใบไหนเพิ่งเข้ามาใหม่
  final Set<String> _seenAlertIds = <String>{};
  bool _hasSeededAlerts = false;

  /// เรียกเมื่อมีใบใหม่เข้ามาหลังรอบโหลดแรก
  ///
  /// ส่งใบดิบ ๆ ไปทั้งหมด ให้ผู้เรียกเป็นคนกรองตามค่าตั้งของผู้ใช้เอง
  /// ตัวควบคุมนี้ไม่ควรรู้เรื่องการเด้งแจ้งเตือน
  void Function(List<SystemAlert> fresh)? onNewAlerts;

  /// รายการที่ควรขึ้นบนหน้าจอ กรองตามค่าตั้งของผู้ใช้แล้ว
  List<SystemAlert> get alerts => _alertPreferences.visible(_allAlerts);

  /// ทุกใบที่ได้มาจริง ไม่สนค่าตั้ง ใช้ตอนอยากนับของทั้งหมด
  List<SystemAlert> get allAlerts => _allAlerts;

  AlertPreferences get alertPreferences => _alertPreferences;

  set alertPreferences(AlertPreferences value) {
    if (_alertPreferences == value) return;
    _alertPreferences = value;
    notifyListeners();
  }

  EnergyPeriodKind period = EnergyPeriodKind.week;
  DateTime? customFrom;
  DateTime? customTo;
  int? floor;

  bool isLoading = false;
  bool hasLoaded = false;
  String? errorMessage;
  String? alertsErrorMessage;

  Timer? _timer;
  Future<void>? _inFlight;

  int get openAlertCount =>
      alerts.where((alert) => alert.isOpen).length;

  /// ช่วงกำหนดเองยังเลือกไม่ครบ จึงยังยิงคำขอไม่ได้
  bool get needsCustomRange =>
      period == EnergyPeriodKind.custom &&
      (customFrom == null || customTo == null);

  Future<void> initialize() async {
    if (hasLoaded || isLoading) return;
    await refresh();
    _timer ??= Timer.periodic(
      _refreshInterval,
      (_) => refresh(silent: true),
    );
  }

  Future<void> setPeriod(EnergyPeriodKind next) async {
    if (period == next) return;
    period = next;
    notifyListeners();
    if (needsCustomRange) return;
    await refresh();
  }

  Future<void> setCustomRange(DateTime from, DateTime to) async {
    period = EnergyPeriodKind.custom;
    customFrom = from.isAfter(to) ? to : from;
    customTo = to.isBefore(from) ? from : to;
    notifyListeners();
    await refresh();
  }

  Future<void> setFloor(int? next) async {
    if (floor == next) return;
    floor = next;
    notifyListeners();
    await refresh();
  }

  /// การกดรีเฟรชเองจะได้ข้อมูลชุดใหม่เสมอ ส่วนรอบอัตโนมัติที่ชนกันจะข้ามไป
  Future<void> refresh({bool silent = false}) async {
    if (needsCustomRange) return;
    final inFlight = _inFlight;
    if (inFlight != null) {
      if (silent) return;
      await inFlight;
    }
    final task = _run(silent);
    _inFlight = task;
    try {
      await task;
    } finally {
      if (identical(_inFlight, task)) _inFlight = null;
    }
  }

  Future<void> _run(bool silent) async {
    if (!silent) isLoading = true;
    if (!silent) notifyListeners();

    // ดึงสองอย่างพร้อมกัน แต่ให้ล้มแยกกัน ถ้าอันหนึ่งพังอีกอันยังแสดงได้
    await Future.wait([_loadSummary(), _loadAlerts()]);

    hasLoaded = true;
    if (!silent) isLoading = false;
    notifyListeners();
  }

  Future<void> _loadSummary() async {
    try {
      summary = await energyRepository.fetchSummary(
        kind: period,
        from: period == EnergyPeriodKind.custom ? customFrom : null,
        to: period == EnergyPeriodKind.custom ? customTo : null,
        floor: floor,
      );
      errorMessage = null;
    } catch (error) {
      errorMessage = _readable(error);
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final loaded = await alertRepository.fetchAlerts(limit: 30);
      final fresh = freshAlerts(alerts: loaded, seenIds: _seenAlertIds);
      _seenAlertIds.addAll(loaded.map((alert) => alert.id));
      _allAlerts = loaded;
      alertsErrorMessage = null;

      // รอบแรกคือของที่ค้างอยู่ก่อนเปิดแอป ไม่ใช่เหตุการณ์ที่เพิ่งเกิด
      // ถ้าเด้งด้วยจะได้แจ้งเตือนย้อนหลังรวดเดียวสามสิบใบตอนเปิดแอป
      if (_hasSeededAlerts && fresh.isNotEmpty) {
        onNewAlerts?.call(fresh);
      }
      _hasSeededAlerts = true;
    } catch (error) {
      alertsErrorMessage = _readable(error);
    }
  }

  Future<void> acknowledge(String id) async {
    final updated = await alertRepository.acknowledge(id);
    _allAlerts = [
      for (final alert in _allAlerts)
        if (alert.id == updated.id) updated else alert,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _readable(Object error) {
    return error.toString().replaceFirst('ApiException: ', '');
  }
}
