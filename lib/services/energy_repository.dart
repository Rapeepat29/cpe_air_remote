import '../models/energy_data.dart';

abstract interface class EnergyRepository {
  /// รายชื่อค่าไฟที่เลือกใส่รายงานได้ Backend เป็นคนกำหนด
  Future<List<EnergyMetric>> fetchMetrics();

  /// ค่าล่าสุดของแอร์ทุกเครื่อง เรียกซ้ำได้ตามรอบที่ผู้ใช้เลือก
  Future<EnergyLiveSnapshot> fetchLive();

  /// ห้องและเครื่องแอร์ที่เลือกได้ในโหมดรายละเอียดสูง
  Future<EnergySourceCatalog> fetchSources();

  /// ตัวเลขสรุปของหน้าหลักและหน้าสถิติ ตามช่วงเวลาที่เลือก
  Future<EnergySummary> fetchSummary({
    required EnergyPeriodKind kind,
    DateTime? from,
    DateTime? to,
    int? floor,
  });

  /// ตัวอย่างข้อมูลก่อนดาวน์โหลด ใช้แสดงตารางบนหน้าจอ
  Future<EnergyHistoryResult> fetchHistory(EnergyQuery query);

  /// ไฟล์ Excel ที่ Backend สร้างให้ตามเงื่อนไขเดียวกับ [fetchHistory]
  Future<EnergyExportFile> downloadExport(
    EnergyQuery query, {
    bool english = false,
  });
}
