import 'package:cpe_air_remote/models/schedule_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads new room suggestions and confirms room creation on commit', () {
    final preview = ScheduleImportPreview.fromJson({
      'fileName': 'ตาราง.xlsx',
      'semester': '1/2569',
      'roomNumbers': ['16202', 'CL503'],
      'existingRoomNumbers': ['16202'],
      'newRooms': [
        {
          'roomNumber': 'CL503',
          'floorNumber': 0,
          'roomIndex': 503,
          'roomType': 'Special',
        },
      ],
      'schedules': [
        {
          'semester': '1/2569',
          'roomNumber': 'CL503',
          'dayOfWeek': 1,
          'subjectName': 'Operating System',
          'startTime': '09:00',
          'endTime': '12:00',
          'section': '(T) 68346CPE',
          'instructor': 'Teacher A',
        },
      ],
      'warnings': <String>[],
      'skippedSheets': <String>[],
      'csv': '',
    });

    expect(preview.newRoomCount, 1);
    expect(preview.newRooms.single.roomNumber, 'CL503');
    expect(preview.newRooms.single.floorNumber, 0);
    expect(preview.toCommitJson()['createMissingRooms'], isTrue);
  });

  test('reads created rooms from a successful import result', () {
    final result = ScheduleImportResult.fromJson({
      'importedCount': 151,
      'replacedRooms': ['16202', 'CL503'],
      'createdRooms': [
        {
          'roomNumber': 'CL503',
          'floorNumber': 0,
          'roomIndex': 503,
          'roomType': 'Special',
        },
      ],
    });

    expect(result.importedCount, 151);
    expect(result.createdRooms.single.roomNumber, 'CL503');
  });
}
