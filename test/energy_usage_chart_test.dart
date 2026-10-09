import 'package:cpe_air_remote/localization/app_localizations.dart';
import 'package:cpe_air_remote/models/energy_data.dart';
import 'package:cpe_air_remote/utils/thai_date.dart';
import 'package:cpe_air_remote/widgets/energy_usage_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const double _chartWidth = 300;
const double _chartHeight = 190;

List<EnergySeriesPoint> _series(List<double> values) {
  return [
    for (var i = 0; i < values.length; i++)
      EnergySeriesPoint(
        label: '08-${(18 + i).toString().padLeft(2, '0')}',
        date: '2026-08-${(18 + i).toString().padLeft(2, '0')}',
        kwh: values[i],
      ),
  ];
}

Future<void> _pump(WidgetTester tester, List<EnergySeriesPoint> points) async {
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
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _chartWidth,
            height: _chartHeight,
            child: EnergyUsageChart(
              points: points,
              costLabel: (kwh) => 'บาท ${(kwh * 4).toStringAsFixed(2)}',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// แตะจุดที่ [index] โดยคำนวณพิกัดจากสูตรเดียวกับที่ตัววาดใช้
Future<void> _tapPoint(WidgetTester tester, int index, int total) async {
  final topLeft = tester.getTopLeft(find.byType(EnergyUsageChart));
  final positions = EnergyChartGeometry.resolve(
    const Size(_chartWidth, _chartHeight),
    List<double>.filled(total, 1),
  );
  await tester.tapAt(topLeft + Offset(positions[index].dx, _chartHeight / 2));
  await tester.pumpAndSettle();
}

void main() {
  group('EnergyChartGeometry', () {
    test('แท่งแรกและแท่งสุดท้ายอยู่กลางช่องของตัวเอง', () {
      const size = Size(_chartWidth, _chartHeight);
      final points = EnergyChartGeometry.resolve(size, const [0, 1, 2]);
      final slot = EnergyChartGeometry.slot(size, 3);

      expect(points.length, 3);
      expect(points.first.dx, closeTo(EnergyChartGeometry.left + slot / 2, 0.001));
      expect(
        points.last.dx,
        closeTo(_chartWidth - EnergyChartGeometry.right - slot / 2, 0.001),
      );
    });

    test('ค่าสูงสุดอยู่บนสุด ค่าศูนย์อยู่ล่างสุด', () {
      final points = EnergyChartGeometry.resolve(
        const Size(_chartWidth, _chartHeight),
        const [0, 0.005],
      );

      expect(points.last.dy, closeTo(EnergyChartGeometry.top, 0.001));
      expect(
        points.first.dy,
        _chartHeight - EnergyChartGeometry.bottom,
      );
    });

    test('ทุกค่าเป็นศูนย์ก็ยังวาดได้ ไม่หารด้วยศูนย์', () {
      final points = EnergyChartGeometry.resolve(
        const Size(_chartWidth, _chartHeight),
        const [0, 0, 0],
      );

      expect(points.length, 3);
      for (final point in points) {
        expect(point.dy.isFinite, isTrue);
      }
    });

    test('จุดเดียวคืนรายการว่าง (หน้าจอขึ้นข้อความแทนกราฟ)', () {
      final points = EnergyChartGeometry.resolve(
        const Size(_chartWidth, _chartHeight),
        const [1.0],
      );

      expect(points, isEmpty);
    });

    test('แตะตรงไหนของช่องก็ได้แท่งของช่องนั้น และไม่หลุดขอบ', () {
      const size = Size(_chartWidth, _chartHeight);
      final slot = EnergyChartGeometry.slot(size, 24);

      expect(EnergyChartGeometry.indexAt(0, size, 24), 0);
      expect(
        EnergyChartGeometry.indexAt(EnergyChartGeometry.left + slot * 15.9, size, 24),
        15,
      );
      expect(EnergyChartGeometry.indexAt(_chartWidth + 50, size, 24), 23);
    });
  });

  group('niceScaleMax', () {
    test('ปัดขึ้นเป็นตัวเลขกลมที่อ่านง่าย', () {
      expect(niceScaleMax(3.56), 4);
      expect(niceScaleMax(17.3), 20);
      expect(niceScaleMax(0.005), 0.005);
      expect(niceScaleMax(0.42), 0.5);
      expect(niceScaleMax(212), 250);
      expect(niceScaleMax(0), 1);
    });
  });

  group('axisLabelsFor', () {
    test('รายชั่วโมงเขียนแค่ทุก 6 ชั่วโมง', () {
      final points = [
        for (var h = 0; h < 24; h++)
          EnergySeriesPoint(
            label: '${h.toString().padLeft(2, '0')}:00',
            date: '2026-10-09',
            hour: h,
            kwh: 0,
          ),
      ];
      final labels = axisLabelsFor(points, true);

      expect(labels.where((label) => label.isNotEmpty).toList(), [
        '00:00',
        '06:00',
        '12:00',
        '18:00',
      ]);
    });

    test('7 วันใช้ชื่อวันแบบย่อ', () {
      final points = [
        for (var d = 3; d <= 9; d++)
          EnergySeriesPoint(
            label: '10-0$d',
            date: '2026-10-0$d',
            kwh: 1,
          ),
      ];

      // 3 ต.ค. 2569 เป็นวันเสาร์ ไล่ไปจนถึงศุกร์ 9 ต.ค.
      expect(axisLabelsFor(points, true), ['ส', 'อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ']);
    });

    test('30 วันมีวันที่ทุก 7 วันกับวันสุดท้าย ไม่ชิดกันจนทับ', () {
      final start = DateTime(2026, 9, 10);
      final points = [
        for (var i = 0; i < 30; i++)
          EnergySeriesPoint(
            label: '',
            date: start
                .add(Duration(days: i))
                .toIso8601String()
                .substring(0, 10),
            kwh: 1,
          ),
      ];
      final labels = axisLabelsFor(points, true);
      final shown = [
        for (var i = 0; i < labels.length; i++)
          if (labels[i].isNotEmpty) i,
      ];

      expect(shown, [0, 7, 14, 21, 29]);
      expect(labels.last, formatDayMonth(DateTime(2026, 10, 9), true));
    });
  });

  group('EnergyUsageChart', () {
    testWidgets('ข้อมูลน้อยกว่าสองจุดขึ้นข้อความแทนกราฟ', (tester) async {
      await _pump(tester, _series([1.5]));

      expect(find.text('ข้อมูลยังไม่พอวาดกราฟ'), findsOneWidget);
    });

    testWidgets('แตะจุดแล้วขึ้นกล่องบอกค่าไฟของจุดนั้น', (tester) async {
      await _pump(tester, _series([0, 0, 0, 0.005]));

      expect(find.textContaining('Wh'), findsNothing);

      await _tapPoint(tester, 3, 4);

      // ค่าเล็กระดับที่ชาร์จมือถือต้องอ่านออก ไม่ใช่ 0.0 kWh
      expect(find.text('5.00 Wh'), findsOneWidget);
      // ตั้งแต่ 3.13.1 กล่องรายละเอียดแสดงวันที่แบบไทย (เทสต์ใช้ locale th)
      expect(find.text(formatIsoDateText('2026-08-21', true)), findsOneWidget);
      expect(find.text('บาท 0.02'), findsOneWidget);
    });

    testWidgets('แตะจุดเดิมซ้ำเป็นการปิดกล่อง', (tester) async {
      await _pump(tester, _series([0, 0, 0, 0.005]));

      await _tapPoint(tester, 3, 4);
      expect(find.text('5.00 Wh'), findsOneWidget);

      await _tapPoint(tester, 3, 4);
      expect(find.text('5.00 Wh'), findsNothing);
    });

    testWidgets('แตะคนละจุดแล้วกล่องย้ายตาม ไม่ค้างที่จุดเดิม', (tester) async {
      await _pump(tester, _series([0.4, 1.1, 3.2, 0.8]));

      await _tapPoint(tester, 2, 4);
      expect(find.text('3.20 kWh'), findsOneWidget);

      await _tapPoint(tester, 0, 4);
      expect(find.text('3.20 kWh'), findsNothing);
      expect(find.text('0.40 kWh'), findsOneWidget);
    });

    testWidgets('เปลี่ยนช่วงเวลาแล้วจุดที่เลือกไว้เกินขอบ ต้องไม่พัง', (
      tester,
    ) async {
      await _pump(tester, _series([0.4, 1.1, 3.2, 0.8]));
      await _tapPoint(tester, 3, 4);
      expect(find.text('0.80 kWh'), findsOneWidget);

      // ช่วงใหม่มีแค่ 2 จุด ดัชนี 3 ที่ค้างอยู่จะชี้เลยขอบรายการ
      await _pump(tester, _series([0.4, 1.1]));

      expect(tester.takeException(), isNull);
      expect(find.text('0.80 kWh'), findsNothing);
    });
  });
}
