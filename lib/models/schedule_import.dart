class ScheduleImportEntry {
  const ScheduleImportEntry({
    required this.semester,
    required this.roomNumber,
    required this.dayOfWeek,
    required this.subjectName,
    required this.startTime,
    required this.endTime,
    required this.section,
    required this.instructor,
  });

  final String semester;
  final String roomNumber;
  final int dayOfWeek;
  final String subjectName;
  final String startTime;
  final String endTime;
  final String section;
  final String instructor;

  factory ScheduleImportEntry.fromJson(Map<String, dynamic> json) {
    return ScheduleImportEntry(
      semester: json['semester'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      subjectName: json['subjectName'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      section: json['section'] as String? ?? '',
      instructor: json['instructor'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'semester': semester,
      'roomNumber': roomNumber,
      'dayOfWeek': dayOfWeek,
      'subjectName': subjectName,
      'startTime': startTime,
      'endTime': endTime,
      'section': section,
      'instructor': instructor,
    };
  }
}

class ScheduleImportRoom {
  const ScheduleImportRoom({
    required this.roomNumber,
    required this.floorNumber,
    required this.roomIndex,
    required this.roomType,
  });

  final String roomNumber;
  final int floorNumber;
  final int roomIndex;
  final String roomType;

  factory ScheduleImportRoom.fromJson(Map<String, dynamic> json) {
    return ScheduleImportRoom(
      roomNumber: json['roomNumber'] as String? ?? '',
      floorNumber: (json['floorNumber'] as num?)?.toInt() ?? 0,
      roomIndex: (json['roomIndex'] as num?)?.toInt() ?? 0,
      roomType: json['roomType'] as String? ?? 'Special',
    );
  }
}

class ScheduleImportPreview {
  const ScheduleImportPreview({
    required this.fileName,
    required this.semester,
    required this.schedules,
    required this.roomNumbers,
    required this.existingRoomNumbers,
    required this.newRooms,
    required this.warnings,
    required this.skippedSheets,
    required this.csv,
    this.termSemester,
    this.termStartDate,
    this.termEndDate,
    this.replaceAll = false,
  });

  final String fileName;
  final String semester;
  final List<ScheduleImportEntry> schedules;
  final List<String> roomNumbers;
  final List<String> existingRoomNumbers;
  final List<ScheduleImportRoom> newRooms;
  final List<String> warnings;
  final List<String> skippedSheets;
  final String csv;

  /// ภาคเรียนที่ผู้ใช้ยืนยันก่อนนำเข้า เช่น 1/2569 (null = ใช้ค่าที่อ่านจากไฟล์)
  final String? termSemester;

  /// ช่วงวันที่ใช้ตารางนี้ รูปแบบ yyyy-MM-dd ทั้งคู่ หรือ null ทั้งคู่
  final String? termStartDate;
  final String? termEndDate;

  /// เปลี่ยนภาคเรียน: ล้างตารางเดิมของทุกห้องก่อนนำเข้า ไม่ใช่แค่ห้องในไฟล์
  ///
  /// ไฟล์ของเทอมใหม่มักไม่มีชีตของห้องที่เทอมนี้ไม่มีเรียน ถ้าไม่ล้าง ห้องพวกนั้น
  /// จะค้างตารางเทอมเก่า และระบบปิดแอร์จะคิดว่ายังมีคาบ (รอ 15 นาทีแทน 5)
  final bool replaceAll;

  bool get hasTerm => termStartDate != null && termEndDate != null;

  /// สำเนาที่ติดภาคเรียนและวันเปิด-ปิดภาคไว้ ส่งไปพร้อมตอนยืนยันนำเข้า
  ScheduleImportPreview withTerm({
    required String semester,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return ScheduleImportPreview(
      fileName: fileName,
      semester: semester,
      schedules: schedules,
      roomNumbers: roomNumbers,
      existingRoomNumbers: existingRoomNumbers,
      newRooms: newRooms,
      warnings: warnings,
      skippedSheets: skippedSheets,
      csv: csv,
      termSemester: semester,
      termStartDate: isoDate(startDate),
      termEndDate: isoDate(endDate),
      replaceAll: replaceAll,
    );
  }

  /// สำเนาที่ตั้งว่าจะล้างตารางเดิมทุกห้อง (เปลี่ยนภาคเรียน) หรือไม่
  ScheduleImportPreview withReplaceAll(bool value) {
    return ScheduleImportPreview(
      fileName: fileName,
      semester: semester,
      schedules: schedules,
      roomNumbers: roomNumbers,
      existingRoomNumbers: existingRoomNumbers,
      newRooms: newRooms,
      warnings: warnings,
      skippedSheets: skippedSheets,
      csv: csv,
      termSemester: termSemester,
      termStartDate: termStartDate,
      termEndDate: termEndDate,
      replaceAll: value,
    );
  }

  static String isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  int get scheduleCount => schedules.length;

  int get roomCount => roomNumbers.length;

  int get newRoomCount => newRooms.length;

  factory ScheduleImportPreview.fromJson(Map<String, dynamic> json) {
    final schedules = json['schedules'];
    final newRooms = json['newRooms'];
    return ScheduleImportPreview(
      fileName: json['fileName'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      schedules: schedules is List
          ? schedules
                .whereType<Map<String, dynamic>>()
                .map(ScheduleImportEntry.fromJson)
                .toList()
          : const [],
      roomNumbers: _strings(json['roomNumbers']),
      existingRoomNumbers: _strings(json['existingRoomNumbers']),
      newRooms: newRooms is List
          ? newRooms
                .whereType<Map<String, dynamic>>()
                .map(ScheduleImportRoom.fromJson)
                .toList()
          : const [],
      warnings: _strings(json['warnings']),
      skippedSheets: _strings(json['skippedSheets']),
      csv: json['csv'] as String? ?? '',
    );
  }

  Map<String, dynamic> toCommitJson() {
    return {
      'createMissingRooms': newRooms.isNotEmpty,
      if (replaceAll) 'replaceAll': true,
      'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
      if (termSemester != null) 'semester': termSemester,
      if (hasTerm) 'startDate': termStartDate,
      if (hasTerm) 'endDate': termEndDate,
    };
  }

  static List<String> _strings(Object? value) {
    return value is List ? value.whereType<String>().toList() : const [];
  }
}

class ScheduleImportResult {
  const ScheduleImportResult({
    required this.importedCount,
    required this.replacedRooms,
    required this.createdRooms,
  });

  final int importedCount;
  final List<String> replacedRooms;
  final List<ScheduleImportRoom> createdRooms;

  factory ScheduleImportResult.fromJson(Map<String, dynamic> json) {
    final createdRooms = json['createdRooms'];
    return ScheduleImportResult(
      importedCount: (json['importedCount'] as num?)?.toInt() ?? 0,
      replacedRooms: json['replacedRooms'] is List
          ? (json['replacedRooms'] as List).whereType<String>().toList()
          : const [],
      createdRooms: createdRooms is List
          ? createdRooms
                .whereType<Map<String, dynamic>>()
                .map(ScheduleImportRoom.fromJson)
                .toList()
          : const [],
    );
  }
}
