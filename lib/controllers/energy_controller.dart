import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/energy_data.dart';
import '../services/energy_repository.dart';

/// รอบเวลาที่หน้าจอดึงค่าไฟใหม่
///
/// ESP32 อ่าน PZEM ทุก 2 วินาทีและส่งขึ้น MQTT เป็นระยะ ค่าเริ่มต้น 5 วินาที
/// จึงเห็นการเปลี่ยนแปลงเกือบทันทีโดยไม่ยิงคำขอถี่เกินจำเป็น
const kEnergyRefreshChoices = <int>[2, 5, 10, 30, 60];

class EnergyController extends ChangeNotifier {
  EnergyController({required this.repository});

  final EnergyRepository repository;

  // --- ค่าไฟสด ---
  EnergyLiveSnapshot live = EnergyLiveSnapshot.empty;
  bool isLiveLoading = false;
  String? liveError;
  int refreshSeconds = 5;
  bool _isStreaming = false;
  Timer? _liveTimer;
  Future<void>? _liveInFlight;

  // --- ตัวเลือกของรายงาน ---
  List<EnergyMetric> metrics = const [];
  EnergySourceCatalog sources = EnergySourceCatalog.empty;
  bool isCatalogLoading = false;
  String? catalogError;

  // --- ผลลัพธ์ตัวอย่างก่อนดาวน์โหลด ---
  EnergyHistoryResult preview = EnergyHistoryResult.empty;
  bool isPreviewLoading = false;
  String? previewError;
  bool hasPreview = false;

  bool isExporting = false;

  bool get isStreaming => _isStreaming;

  /// ค่าที่เลือกได้ในโหมดนั้น ๆ โหมดสรุปจะซ่อนค่าที่ละเอียดเกินไป
  List<EnergyMetric> metricsFor(EnergyScope scope) {
    if (scope.isHighDetail) return metrics;
    return metrics.where((metric) => !metric.detailOnly).toList();
  }

  Future<void> initialize() async {
    await loadCatalog();
    await refreshLive();
  }

  Future<void> loadCatalog() async {
    isCatalogLoading = true;
    catalogError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        repository.fetchMetrics(),
        repository.fetchSources(),
      ]);
      metrics = results[0] as List<EnergyMetric>;
      sources = results[1] as EnergySourceCatalog;
    } catch (error) {
      catalogError = _readableError(error);
    } finally {
      isCatalogLoading = false;
      notifyListeners();
    }
  }

  /// เริ่มดึงค่าไฟใหม่เป็นรอบ ๆ เรียกซ้ำได้ ไม่สร้างตัวจับเวลาซ้อน
  void startLiveUpdates() {
    _isStreaming = true;
    _restartTimer();
    notifyListeners();
  }

  void stopLiveUpdates() {
    _isStreaming = false;
    _liveTimer?.cancel();
    _liveTimer = null;
    notifyListeners();
  }

  void setRefreshSeconds(int seconds) {
    if (!kEnergyRefreshChoices.contains(seconds)) return;
    refreshSeconds = seconds;
    if (_isStreaming) _restartTimer();
    notifyListeners();
  }

  void _restartTimer() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(
      Duration(seconds: refreshSeconds),
      (_) => refreshLive(silent: true),
    );
  }

  /// รอบอัตโนมัติที่ชนกันเองจะข้ามไป ส่วนการกดรีเฟรชเองจะรอรอบเดิมให้จบก่อน
  Future<void> refreshLive({bool silent = false}) async {
    final inFlight = _liveInFlight;
    if (inFlight != null) {
      if (silent) return;
      await inFlight;
    }
    final task = _runLiveRefresh(silent);
    _liveInFlight = task;
    try {
      await task;
    } finally {
      if (identical(_liveInFlight, task)) _liveInFlight = null;
    }
  }

  Future<void> _runLiveRefresh(bool silent) async {
    if (!silent) isLiveLoading = true;
    if (!silent) notifyListeners();
    try {
      live = await repository.fetchLive();
      liveError = null;
    } catch (error) {
      liveError = _readableError(error);
    } finally {
      if (!silent) isLiveLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPreview(EnergyQuery query) async {
    isPreviewLoading = true;
    previewError = null;
    notifyListeners();
    try {
      preview = await repository.fetchHistory(query);
      hasPreview = true;
    } catch (error) {
      preview = EnergyHistoryResult.empty;
      hasPreview = false;
      previewError = _readableError(error);
    } finally {
      isPreviewLoading = false;
      notifyListeners();
    }
  }

  void clearPreview() {
    preview = EnergyHistoryResult.empty;
    hasPreview = false;
    previewError = null;
    notifyListeners();
  }

  Future<EnergyExportFile> exportExcel(
    EnergyQuery query, {
    bool english = false,
  }) async {
    isExporting = true;
    notifyListeners();
    try {
      return await repository.downloadExport(query, english: english);
    } finally {
      isExporting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst('ApiException: ', '');
  }
}
