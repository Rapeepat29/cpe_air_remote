import 'package:cpe_air_remote/localization/app_localizations.dart';
import 'package:cpe_air_remote/models/energy_data.dart';
import 'package:cpe_air_remote/utils/thai_date.dart';
import 'package:cpe_air_remote/widgets/energy_usage_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const double _chartWidth = 300;
const double _chartHeight = 162;

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
    test('จุดแรกและจุดสุดท้ายอยู่ชิดขอบพื้นที่วาด', () {
      final points = EnergyChartGeometry.resolve(
        const Size(_chartWidth, _chartHeight),
        const [0, 1, 2],
      );

      expect(points.length, 3);
      expect(points.first.dx, EnergyChartGeometry.left);
      expect(
        points.last.dx,
        _chartWidth - EnergyChartGeometry.right,
      );
    });

    test('ค่าสูงสุดอยู่บนสุด ค่าศูนย์อยู่ล่างสุด', () {
      final points = EnergyChartGeometry.resolve(
        const Size(_chartWidth, _chartHeight),
        const [0, 0.005],
      );

      expect(points.last.dy, EnergyChartGeometry.top);
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

    test('จุดเดียวยังวาดเส้นไม่ได้ จึงคืนรายการว่าง', () {
      final points = EnergyChartGeometry.resolve(
        const Size(_chartWidth, _chartHeight),
        const [1.0],
      );

      expect(points, isEmpty);
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
