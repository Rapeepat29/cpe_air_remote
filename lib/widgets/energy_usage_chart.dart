import '../localization/localized_material.dart';

import '../models/energy_data.dart';
import '../theme/app_theme.dart';
import '../utils/number_format.dart';
import '../utils/thai_date.dart';

/// กราฟการใช้พลังงาน พร้อมป้ายบอกค่าไฟของแต่ละจุด
///
/// ป้ายค่าไฟจะติดอยู่เหนือจุดตลอด ถ้าจุดถี่จนป้ายจะทับกันเองจะเว้นระยะให้
/// อัตโนมัติ และแตะหรือลากนิ้วบนกราฟเพื่อดูรายละเอียดของจุดที่ต้องการได้
///
/// ทุกจุดใช้หน่วยเดียวกันเสมอ โดยคิดจากค่าที่สูงที่สุดของชุด เพราะถ้าปล่อยให้
/// แต่ละจุดเลือกหน่วยเอง จุดที่เป็น `900 Wh` จะดูเหมือนมากกว่า `1.2 kWh`
class EnergyUsageChart extends StatefulWidget {
  const EnergyUsageChart({
    required this.points,
    required this.costLabel,
    super.key,
  });

  final List<EnergySeriesPoint> points;

  /// ข้อความค่าเงินของหนึ่งจุด เช่น `บาท 0.02`
  final String Function(double kwh) costLabel;

  @override
  State<EnergyUsageChart> createState() => _EnergyUsageChartState();
}

class _EnergyUsageChartState extends State<EnergyUsageChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant EnergyUsageChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // เปลี่ยนช่วงเวลาแล้วจำนวนจุดเปลี่ยน ดัชนีเดิมอาจชี้เลยขอบ
    final selected = _selectedIndex;
    if (selected != null && selected >= widget.points.length) {
      _selectedIndex = null;
    }
  }

  void _selectAt(double dx, Size size, {bool toggle = false}) {
    final positions = EnergyChartGeometry.resolve(
      size,
      widget.points.map((point) => point.kwh).toList(),
    );
    if (positions.isEmpty) return;

    var nearest = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < positions.length; i++) {
      final distance = (positions[i].dx - dx).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = i;
      }
    }

    setState(() {
      _selectedIndex = toggle && _selectedIndex == nearest ? null : nearest;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return Center(
        child: Text(
          context.tr('Not enough data to draw a chart yet'),
          style: const TextStyle(color: Color(0xFFD5E1E5), fontSize: 11),
        ),
      );
    }

    final values = widget.points.map((point) => point.kwh).toList();
    final reference = energyScaleReference(values);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final positions = EnergyChartGeometry.resolve(size, values);
        final selected = _selectedIndex;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _selectAt(
            details.localPosition.dx,
            size,
            toggle: true,
          ),
          onHorizontalDragStart: (details) =>
              _selectAt(details.localPosition.dx, size),
          onHorizontalDragUpdate: (details) =>
              _selectAt(details.localPosition.dx, size),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: EnergyChartPainter(
                    values: values,
                    labels: widget.points
                        .map((point) => point.label)
                        .toList(),
                    scaleReference: reference,
                    selectedIndex: selected,
                  ),
                ),
              ),
              if (selected != null && selected < positions.length)
                _Tooltip(
                  anchor: positions[selected],
                  size: size,
                  point: widget.points[selected],
                  energy: formatEnergy(
                    widget.points[selected].kwh,
                    scaleReference: reference,
                  ),
                  cost: widget.costLabel(widget.points[selected].kwh),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// กล่องรายละเอียดของจุดที่เลือก
class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.anchor,
    required this.size,
    required this.point,
    required this.energy,
    required this.cost,
  });

  static const double width = 132;

  final Offset anchor;
  final Size size;
  final EnergySeriesPoint point;
  final EnergyDisplay energy;
  final String cost;

  String _title(bool isThai) {
    if (point.date.isEmpty) return point.label;
    final date = formatIsoDateText(point.date, isThai);
    final hour = point.hour;
    if (hour == null) return date;
    return '$date  ${hour.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    // เกาะไว้เหนือจุด ถ้าชนขอบบนก็ย้ายไปอยู่ใต้จุดแทน
    const height = 66.0;
    final above = anchor.dy - height - 12;
    final top = above >= 0 ? above : anchor.dy + 14;

    return Positioned(
      left: clampToBox(anchor.dx - width / 2, size.width - width),
      top: clampToBox(top, size.height - height),
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title(AppLocalizations.of(context).isThai),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              energy.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              cost,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// จำกัดค่าให้อยู่ระหว่าง 0 ถึง [limit]
///
/// ใช้แทน `clamp` ตรง ๆ เพราะถ้าจอแคบกว่าป้ายหรือกล่องรายละเอียด ค่า [limit]
/// จะติดลบ แล้ว `clamp` จะโยน ArgumentError ทิ้งเพราะขอบล่างมากกว่าขอบบน
double clampToBox(double value, double limit) {
  if (limit <= 0) return 0;
  if (value < 0) return 0;
  if (value > limit) return limit;
  return value;
}

/// พิกัดของกราฟ แยกออกมาให้ตัววาดกับตัวรับสัมผัสใช้สูตรเดียวกัน
///
/// ถ้าสองที่คำนวณแยกกัน จุดที่แตะได้จะเลื่อนจากจุดที่เห็นทันทีที่แก้ระยะขอบ
abstract final class EnergyChartGeometry {
  static const double left = 18;

  /// เว้นด้านบนไว้ให้ป้ายค่าไฟ ไม่ให้ป้ายของจุดสูงสุดโดนตัด
  static const double top = 24;
  static const double bottom = 28;
  static const double right = 4;

  static List<Offset> resolve(Size size, List<double> values) {
    if (values.length < 2) return const [];

    final chartHeight = size.height - top - bottom;
    final chartWidth = size.width - left - right;
    if (chartHeight <= 0 || chartWidth <= 0) return const [];

    final largest = energyScaleReference(values);
    // ทุกค่าเป็นศูนย์ก็ยังต้องหารได้ จึงกันตัวหารเป็นศูนย์ไว้
    final maxValue = largest > 0 ? largest : 1.0;

    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          left + (chartWidth * i / (values.length - 1)),
          top + chartHeight * (1 - values[i] / maxValue),
        ),
    ];
  }
}

class EnergyChartPainter extends CustomPainter {
  const EnergyChartPainter({
    required this.values,
    required this.labels,
    required this.scaleReference,
    this.selectedIndex,
  });

  final List<double> values;
  final List<String> labels;
  final double scaleReference;
  final int? selectedIndex;

  static const Color _mutedText = Color(0xFFD5E1E5);

  TextPainter _text(String value, TextStyle style) {
    return TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = EnergyChartGeometry.resolve(size, values);
    if (points.isEmpty) return;

    const left = EnergyChartGeometry.left;
    const top = EnergyChartGeometry.top;
    final chartHeight =
        size.height - top - EnergyChartGeometry.bottom;
    final chartWidth = size.width - left - EnergyChartGeometry.right;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final middleX = (current.dx + next.dx) / 2;
      path.cubicTo(middleX, current.dy, middleX, next.dy, next.dx, next.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.3,
    );

    final selected = selectedIndex;
    if (selected != null && selected < points.length) {
      canvas.drawLine(
        Offset(points[selected].dx, top),
        Offset(points[selected].dx, top + chartHeight),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..strokeWidth = 1.2,
      );
    }

    final pointFill = Paint()..color = AppColors.primary;
    final pointBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < points.length; i++) {
      final radius = i == selected ? 6.2 : 4.3;
      canvas.drawCircle(points[i], radius, pointFill);
      canvas.drawCircle(points[i], radius, pointBorder);
    }

    _paintValueLabels(canvas, size, points);
    _paintAxisLabels(canvas, size, chartWidth);
  }

  /// ป้ายค่าไฟเหนือจุด เว้นระยะเองเมื่อจุดถี่เกินกว่าที่ป้ายจะไม่ทับกัน
  void _paintValueLabels(Canvas canvas, Size size, List<Offset> points) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
    );
    // ติดหน่วยไปกับป้ายทุกใบ เพราะกราฟสลับหน่วยตามชุดข้อมูลได้
    // เห็นแค่ `5.00` ลอย ๆ จะไม่รู้ว่าเป็น Wh หรือ kWh
    final texts = [
      for (final value in values)
        formatEnergy(value, scaleReference: scaleReference).text,
    ];

    var widest = 0.0;
    for (final text in texts) {
      final painter = _text(text, style);
      if (painter.width > widest) widest = painter.width;
    }

    final spacing = points[1].dx - points.first.dx;
    final needed = widest + 8;
    // จุดถี่จนไม่มีที่ว่างเลย ก็เหลือแค่ป้ายแรกกับป้ายสุดท้าย
    // ถ้าไม่กัน spacing เป็นศูนย์ไว้ การหารจะได้อนันต์ แล้ว ceil() จะโยน error
    final step = spacing <= 0
        ? points.length
        : (spacing >= needed ? 1 : (needed / spacing).ceil());

    var lastPaintedX = double.negativeInfinity;
    for (var i = 0; i < points.length; i++) {
      final isSelected = i == selectedIndex;
      final isLast = i == points.length - 1;
      // จุดที่เลือกอยู่มีกล่องรายละเอียดของตัวเองแล้ว ไม่ต้องมีป้ายซ้ำ
      if (isSelected) {
        lastPaintedX = points[i].dx;
        continue;
      }
      // จุดสุดท้ายมักเป็นค่าล่าสุดที่คนอยากเห็น จึงพยายามวาดให้เสมอถ้ายังมีที่
      final scheduled = i % step == 0;
      if (!scheduled && !isLast) continue;
      if (points[i].dx - lastPaintedX < needed) continue;

      final painter = _text(texts[i], style);
      final x = clampToBox(
        points[i].dx - painter.width / 2,
        size.width - painter.width,
      );
      final y = points[i].dy - painter.height - 7;
      painter.paint(canvas, Offset(x, y < 0 ? 0 : y));
      lastPaintedX = points[i].dx;
    }
  }

  void _paintAxisLabels(Canvas canvas, Size size, double chartWidth) {
    const style = TextStyle(color: _mutedText, fontSize: 9);
    final step = labels.length > 12 ? (labels.length / 6).ceil() : 1;

    for (var i = 0; i < labels.length; i++) {
      if (i % step != 0 && i != labels.length - 1) continue;
      final painter = _text(labels[i], style);
      final x = EnergyChartGeometry.left +
          (chartWidth * i / (labels.length - 1));
      painter.paint(
        canvas,
        Offset(
          clampToBox(x - painter.width / 2, size.width - painter.width),
          size.height - 16,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant EnergyChartPainter oldDelegate) {
    // เทียบทีละสมาชิก ไม่ใช่เทียบตัวรายการ เพราะทุกครั้งที่ build จะสร้าง
    // List ใหม่เสมอ ถ้าเทียบด้วย != จะกลายเป็นวาดใหม่ทุกเฟรมโดยไม่จำเป็น
    return !_sameItems(oldDelegate.values, values) ||
        !_sameItems(oldDelegate.labels, labels) ||
        oldDelegate.scaleReference != scaleReference ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

/// เทียบรายการทีละสมาชิก
///
/// เขียนเองแทนที่จะใช้ `listEquals` เพราะตัวนั้นอยู่ใน `foundation.dart`
/// ซึ่ง `widgets.dart` ส่งต่อมาให้แค่บางชื่อด้วย `show` และไม่มีชื่อนี้อยู่ด้วย
bool _sameItems<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}
