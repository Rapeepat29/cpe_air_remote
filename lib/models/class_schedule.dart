class ClassSchedule {
  const ClassSchedule({
    required this.id,
    required this.roomNumber,
    required this.dayOfWeek,
    required this.subjectName,
    this.section = '',
    this.instructor = '',
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String roomNumber;
  final int dayOfWeek;
  final String subjectName;
  final String section;
  final String instructor;
  final String startTime;
  final String endTime;

  factory ClassSchedule.fromJson(Map<String, dynamic> json) {
    return ClassSchedule(
      id: json['id'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      subjectName: json['subjectName'] as String? ?? '',
      section: json['section'] as String? ?? '',
      instructor: json['instructor'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'roomNumber': roomNumber,
      'dayOfWeek': dayOfWeek,
      'subjectName': subjectName,
      'section': section,
      'instructor': instructor,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  ClassSchedule copyWith({
    String? id,
    String? roomNumber,
    int? dayOfWeek,
    String? subjectName,
    String? section,
    String? instructor,
    String? startTime,
    String? endTime,
  }) {
    return ClassSchedule(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      subjectName: subjectName ?? this.subjectName,
      section: section ?? this.section,
      instructor: instructor ?? this.instructor,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  static bool timesOverlap(
    String firstStart,
    String firstEnd,
    String secondStart,
    String secondEnd,
  ) {
    return firstStart.compareTo(secondEnd) < 0 &&
        firstEnd.compareTo(secondStart) > 0;
  }
}
