import 'package:cpe_air_remote/localization/app_localizations.dart';
import 'package:cpe_air_remote/models/room.dart';
import 'package:cpe_air_remote/widgets/auto_off_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('th'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  test('แปลงวินาทีเป็นนาที:วินาที', () {
    expect(formatCountdown(300), '05:00');
    expect(formatCountdown(125), '02:05');
    expect(formatCountdown(9), '00:09');
    expect(formatCountdown(0), '00:00');
    expect(formatCountdown(-5), '00:00', reason: 'เลยกำหนดแล้วต้องไม่ติดลบ');
  });

  testWidgets('ไม่มีนาฬิกาเดินอยู่ ต้องไม่แสดงอะไรเลย', (tester) async {
    await _pump(tester, const AutoOffCountdown(deadline: null));
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('ระหว่างนับถอยหลังบอกเวลาที่เหลือเป็นภาษาไทย', (tester) async {
    await _pump(
      tester,
      AutoOffCountdown(
        deadline: DateTime.now().add(const Duration(seconds: 125)),
      ),
    );

    expect(find.textContaining('ห้องว่าง จะปิดแอร์ใน'), findsOneWidget);
    expect(find.textContaining('02:0'), findsOneWidget);
    expect(
      find.textContaining('ถ้ามีคนเข้าห้องเมื่อไหร่'),
      findsOneWidget,
    );
  });

  testWidgets('ระหว่างคาบเรียนต้องอธิบายว่าทำไมถึงรอนานกว่า', (tester) async {
    await _pump(
      tester,
      AutoOffCountdown(
        deadline: DateTime.now().add(const Duration(minutes: 12)),
        inClass: true,
      ),
    );

    expect(find.textContaining('ตอนนี้มีคาบเรียนอยู่'), findsOneWidget);
  });

  testWidgets('ยิงคำสั่งไปแล้วต้องบอกจำนวนครั้ง', (tester) async {
    await _pump(
      tester,
      AutoOffCountdown(
        deadline: DateTime.now().subtract(const Duration(seconds: 5)),
        attempts: 2,
      ),
    );

    expect(find.textContaining('กำลังส่งคำสั่งปิด'), findsOneWidget);
    expect(find.textContaining('(2/5)'), findsOneWidget);
    expect(find.textContaining('ยิงซ้ำทุก 20 วินาที'), findsOneWidget);
  });

  testWidgets('แบบย่อใช้บรรทัดเดียว ไม่มีคำอธิบายต่อท้าย', (tester) async {
    await _pump(
      tester,
      AutoOffCountdown(
        deadline: DateTime.now().add(const Duration(seconds: 60)),
        compact: true,
      ),
    );

    expect(find.textContaining('ห้องว่าง จะปิดแอร์ใน'), findsOneWidget);
    expect(
      find.textContaining('ถ้ามีคนเข้าห้องเมื่อไหร่'),
      findsNothing,
    );
  });

  test('ห้องรู้ว่ามีนาฬิกาปิดอัตโนมัติเดินอยู่หรือไม่', () {
    final room = Room(
      number: '16301',
      floor: 3,
      roomIndex: 1,
      type: 'Meeting Room',
      airConditioners: [],
    );
    expect(room.isAutoOffPending, isFalse);

    final counting = room.copyWith(
      autoOffDeadlineAt: DateTime(2026, 8, 21, 15, 5),
    );
    expect(counting.isAutoOffPending, isTrue);
  });

  test('อ่านค่านับถอยหลังจาก JSON ของ /api/rooms', () {
    final room = Room.fromJson(const {
      'roomNumber': '16302',
      'floorNumber': 3,
      'roomIndex': 2,
      'roomType': 'Classroom',
      'autoOffDeadlineAt': '2026-08-21T08:05:00.000Z',
      'autoOffAttempts': 2,
      'autoOffInClass': true,
    });

    expect(room.isAutoOffPending, isTrue);
    expect(room.autoOffAttempts, 2);
    expect(room.autoOffInClass, isTrue);
    expect(
      room.autoOffDeadlineAt!.toUtc().toIso8601String(),
      '2026-08-21T08:05:00.000Z',
    );
  });
}
