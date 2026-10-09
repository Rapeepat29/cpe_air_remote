import '../localization/localized_material.dart';

import '../models/energy_data.dart';
import '../theme/app_theme.dart';
import '../utils/number_format.dart';
import '../utils/thai_date.dart';

/// กราฟแท่งการใช้พลังงาน หนึ่งแท่งต่อหนึ่งช่วง (ชั่วโมงหรือวัน)
///
/// ออกแบบให้อ่านง่ายทุกช่วงเวลา ตั้งแต่ 24 แท่งของ "วันนี้" ไปจนถึง 30 แท่ง:
/// - ไม่เขียนตัวเลขทุกแท่ง มีป้ายแค่แท่งที่สูงที่สุด ค่าของแท่งอื่นแตะเพื่อดู
/// - ช่วงที่ไม่ใช้ไฟเหลือขีดจาง ๆ ไม่มีป้าย `0.00 kWh` ซ้ำเต็มแกน
/// - แกนตั้งบอกขนาดด้วยตัวเลขกลม ๆ 3 ระดับ และบอกหน่วยไว้บนสุด
/// - ข้อมูลรายวันตั้งแต่ 7 วันขึ้นไปมีเส้นประบอกค่าเฉลี่ยต่อวัน
///
/// ทุกแท่งใช้หน่วยเดียวกันเสมอ โดยคิดจากค่าที่สูงที่สุดของชุด เพราะถ้าปล่อยให้
/// แต่ละแท่งเลือกหน่วยเอง แท่งที่เป็น `900 Wh` จะดูเหมือนมากกว่า `1.2 kWh`
class EnergyUsageChart extends StatefulWidget {
  const EnergyUsageChart({
    required this.points,
    required this.costLabel,
    super.key,
  });

  final List<EnergySeriesPoint> points;

  /// ข้อความค่าเงินของหนึ่งแท่ง เช่น `บาท 0.02`
  final String Function(double kwh) costLabel;

  @override
  State<EnergyUsageChart> createState() => _EnergyUsageChartState();
}

class _EnergyUsageChartState extends State<EnergyUsageChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant EnergyUsageChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // เปลี่ยนช่วงเวลาแล้วจำนวนแท่งเปลี่ยน ดัชนีเดิมอาจชี้เลยขอบ
    final selected = _selectedIndex;
    if (selected != null && selected >= widget.points.length) {
      _selectedIndex = null;
    }
  }

  void _selectAt(double dx, Size size, {bool toggle = false}) {
    final index = EnergyChartGeometry.indexAt(dx, size, widget.points.length);
    if (index == null) return;
    setState(() {
      _selectedIndex = toggle && _selectedIndex == index ? null : index;
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

    final isThai = AppLocalizations.of(context).isThai;
    final values = widget.points.map((point) => point.kwh).toList();
    final reference = energyScaleReference(values);
    final daily = widget.points.every((point) => point.hour == null);

    String? averageLabel;
    if (daily && values.length >= 7) {
      final average = values.reduce((a, b) => a + b) / values.length;
      if (average > 0) {
        final text = formatEnergy(average, scaleReference: reference).text;
        averageLabel = isThai ? 'เฉลี่ย $text/วัน' : 'Avg $text/day';
      }
    }

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
                    labels: axisLabelsFor(widget.points, isThai),
                    scaleReference: reference,
                    selectedIndex: selected,
                    peakPrefix: isThai ? 'สูงสุด' : 'Peak',
                    averageLabel: averageLabel,
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

/// ป้ายใต้แกนนอน ช่องที่เป็น `''` คือไม่ต้องเขียน
///
/// - รายชั่วโมง: ทุก 6 ชั่วโมง (00:00 06:00 12:00 18:00) ไม่ต้องอ่าน 24 ป้าย
/// - รายวันไม่เกิน 10 วัน: ชื่อวันแบบย่อ (จ อ พ …) เพราะคนจำเป็นวันในสัปดาห์
/// - รายวันมากกว่านั้น: วันที่ทุก 7 วันกับวันสุดท้าย เว้นตัวที่ชิดวันสุดท้าย
List<String> axisLabelsFor(List<EnergySeriesPoint> points, bool isThai) {
  final count = points.length;
  final last = count - 1;
  final hourly = points.every((point) => point.hour != null);

  return [
    for (var i = 0; i < count; i++)
      _axisLabel(points[i], i, last, hourly, isThai),
  ];
}

String _axisLabel(
  EnergySeriesPoint point,
  int index,
  int last,
  bool hourly,
  bool isThai,
) {
  if (hourly) {
    final hour = point.hour!;
    if (hour % 6 == 0) return '${hour.toString().padLeft(2, '0')}:00';
    return '';
  }

  final date = DateTime.tryParse(point.date);
  if (date == null) return index == 0 || index == last ? point.label : '';

  if (last + 1 <= 10) return formatWeekdayShort(date, isThai);
  if (index == last) return formatDayMonth(date, isThai);
  if (index % 7 == 0 && index < last - 3) return formatDayMonth(date, isThai);
  return '';
}

/// กล่องรายละเอียดของแท่งที่เลือก
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
    // เกาะไว้เหนือแท่ง ถ้าชนขอบบนก็ย้ายไปอยู่ใต้ยอดแท่งแทน
    const height = 66.0;
    final above = anchor.dy - height - 10;
    final top = above >= 0 ? above : anchor.dy + 12;

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

/// ค่าบนสุดของแกนตั้งแบบตัวเลขกลม (1, 2, 2.5, 5 × 10^n) ที่ไม่น้อยกว่า [value]
///
/// แกนที่จบที่ 3.56 อ่านยาก จบที่ 4 แล้วมีเส้นกลางที่ 2 อ่านง่ายกว่ามาก
double niceScaleMax(double value) {
  if (value <= 0) return 1;
  var magnitude = 1.0;
  while (magnitude * 10 <= value) {
    magnitude *= 10;
  }
  while (magnitude > value) {
    magnitude /= 10;
  }
  for (final step in const [1.0, 2.0, 2.5, 4.0, 5.0, 10.0]) {
    final candidate = step * magnitude;
    if (candidate >= value - 1e-9) return candidate;
  }
  return 10 * magnitude;
}

/// พิกัดของกราฟ แยกออกมาให้ตัววาดกับตัวรับสัมผัสใช้สูตรเดียวกัน
///
/// ถ้าสองที่คำนวณแยกกัน แท่งที่แตะได้จะเลื่อนจากแท่งที่เห็นทันทีที่แก้ระยะขอบ
abstract final class EnergyChartGeometry {
  /// เว้นซ้ายไว้ให้ตัวเลขแกนตั้ง
  static const double left = 30;

  /// เว้นด้านบนไว้ให้ป้ายค่าสูงสุดและหน่วยของแกน
  static const double top = 22;
  static const double bottom = 22;
  static const double right = 4;

  /// ความกว้างของช่องหนึ่งแท่ง
  static double slot(Size size, int count) {
    if (count <= 0) return 0;
    return (size.width - left - right) / count;
  }

  /// ความกว้างของตัวแท่งเอง เว้นช่องไฟ ~40% และไม่อ้วนเกิน 28 px
  static double barWidth(Size size, int count) {
    final width = slot(size, count) * 0.62;
    if (width > 28) return 28;
    if (width < 1.5) return 1.5;
    return width;
  }

  /// แท่งที่อยู่ตรง [dx] (คิดทั้งช่อง ไม่ต้องแตะโดนตัวแท่งพอดี)
  static int? indexAt(double dx, Size size, int count) {
    final width = slot(size, count);
    if (width <= 0) return null;
    final index = ((dx - left) / width).floor();
    if (index < 0) return 0;
    if (index >= count) return count - 1;
    return index;
  }

  /// จุดกึ่งกลางยอดของแต่ละแท่ง
  static List<Offset> resolve(Size size, List<double> values) {
    if (values.length < 2) return const [];

    final chartHeight = size.height - top - bottom;
    final width = slot(size, values.length);
    if (chartHeight <= 0 || width <= 0) return const [];

    final maxValue = niceScaleMax(energyScaleReference(values));

    return [
      for (var i = 0; i < values.length; i++)
        Offset(
          left + width * (i + 0.5),
          top + chartHeight * (1 - (values[i] / maxValue).clamp(0.0, 1.0)),
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
    this.peakPrefix = 'Peak',
    this.averageLabel,
  });

  final List<double> values;

  /// ป้ายใต้แท่ง ช่องว่างคือไม่ต้องเขียน (ดู [axisLabelsFor])
  final List<String> labels;
  final double scaleReference;
  final int? selectedIndex;

  /// คำหน้าป้ายของแท่งสูงสุด เช่น `สูงสุด`
  final String peakPrefix;

  /// ป้ายของเส้นค่าเฉลี่ย null = ไม่ต้องวาดเส้น
  final String? averageLabel;

  static const Color _mutedText = Color(0xFFE3F7EA);
  static const Color _barColor = Color(0xFFBFE8CF);
  static const Color _averageColor = Color(0xFFFFE08A);

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
    final bottomY = size.height - EnergyChartGeometry.bottom;
    final chartHeight = bottomY - top;
    final chartRight = size.width - EnergyChartGeometry.right;
    final maxValue = niceScaleMax(scaleReference);

    _paintGrid(canvas, left, chartRight, top, chartHeight, maxValue);

    final barWidth = EnergyChartGeometry.barWidth(size, values.length);
    final largest = values.reduce((a, b) => a > b ? a : b);
    final peakIndex = largest > 0 ? values.indexOf(largest) : -1;
    final selected = selectedIndex;
    final radius = Radius.circular(barWidth >= 6 ? 3 : 1);

    for (var i = 0; i < points.length; i++) {
      final x = points[i].dx - barWidth / 2;
      if (values[i] <= 0) {
        // ไม่ใช้ไฟเลย เหลือขีดจาง ๆ ให้รู้ว่ามีช่วงนี้อยู่ แต่ไม่แย่งสายตา
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, bottomY - 2.5, barWidth, 2.5),
            const Radius.circular(1),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.22),
        );
        continue;
      }
      // ค่าเล็กมากก็ยังต้องเห็นเป็นแท่ง ไม่ใช่หายไปกับเส้นฐาน
      final barTop = points[i].dy > bottomY - 2.5 ? bottomY - 2.5 : points[i].dy;
      final highlighted = i == selected || (selected == null && i == peakIndex);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(x, barTop, x + barWidth, bottomY),
          topLeft: radius,
          topRight: radius,
        ),
        Paint()..color = highlighted ? Colors.white : _barColor,
      );
    }

    _paintAverage(canvas, left, chartRight, top, chartHeight, maxValue);

    // ป้ายแท่งสูงสุด ซ่อนไว้ตอนมีแท่งที่เลือกอยู่ เพราะกล่องรายละเอียดบอกแล้ว
    if (peakIndex >= 0 && selected == null) {
      final text = '$peakPrefix '
          '${formatEnergy(largest, scaleReference: scaleReference).text}';
      final painter = _text(
        text,
        const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      );
      final x = clampToBox(
        points[peakIndex].dx - painter.width / 2,
        size.width - painter.width,
      );
      final y = points[peakIndex].dy - painter.height - 4;
      painter.paint(canvas, Offset(x, y < 0 ? 0 : y));
    }

    _paintAxisLabels(canvas, size, points);
  }

  void _paintGrid(
    Canvas canvas,
    double left,
    double right,
    double top,
    double chartHeight,
    double maxValue,
  ) {
    final reference = formatEnergy(maxValue);
    final factor = switch (reference.unit) {
      'Wh' => 1000.0,
      'MWh' => 0.001,
      _ => 1.0,
    };
    const style = TextStyle(color: _mutedText, fontSize: 9);

    for (var i = 0; i <= 2; i++) {
      final y = top + chartHeight * i / 2;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        Paint()
          ..color = Colors.white.withValues(alpha: i == 2 ? 0.45 : 0.18)
          ..strokeWidth = 1,
      );
      final value = maxValue * (2 - i) / 2 * factor;
      final painter = _text(_tickText(value), style);
      painter.paint(
        canvas,
        Offset(left - painter.width - 5, y - painter.height / 2),
      );
    }

    // หน่วยของแกนอยู่บนสุดที่เดียว ไม่ต้องติดทุกตัวเลข
    _text(reference.unit, style).paint(canvas, const Offset(0, 0));
  }

  void _paintAverage(
    Canvas canvas,
    double left,
    double right,
    double top,
    double chartHeight,
    double maxValue,
  ) {
    final label = averageLabel;
    if (label == null) return;

    final average = values.reduce((a, b) => a + b) / values.length;
    final y = top + chartHeight * (1 - (average / maxValue).clamp(0.0, 1.0));
    final paint = Paint()
      ..color = _averageColor
      ..strokeWidth = 1.5;
    // เส้นประวาดเองเป็นช่วง ๆ เพราะ Canvas ไม่มีเส้นประให้
    for (var x = left; x < right; x += 8) {
      final end = x + 4 > right ? right : x + 4;
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }

    final painter = _text(
      label,
      const TextStyle(
        color: _averageColor,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
    );
    painter.paint(
      canvas,
      Offset(right - painter.width, y - painter.height - 2),
    );
  }

  void _paintAxisLabels(Canvas canvas, Size size, List<Offset> points) {
    const style = TextStyle(color: _mutedText, fontSize: 9);
    var lastRight = double.negativeInfinity;

    for (var i = 0; i < labels.length && i < points.length; i++) {
      if (labels[i].isEmpty) continue;
      final painter = _text(labels[i], style);
      final x = clampToBox(
        points[i].dx - painter.width / 2,
        size.width - painter.width,
      );
      // ป้ายชนกันก็ข้ามตัวหลังไป ไม่ซ้อนทับจนอ่านไม่ออก
      if (x < lastRight + 4) continue;
      painter.paint(canvas, Offset(x, size.height - 15));
      lastRight = x + painter.width;
    }
  }

  @override
  bool shouldRepaint(covariant EnergyChartPainter oldDelegate) {
    // เทียบทีละสมาชิก ไม่ใช่เทียบตัวรายการ เพราะทุกครั้งที่ build จะสร้าง
    // List ใหม่เสมอ ถ้าเทียบด้วย != จะกลายเป็นวาดใหม่ทุกเฟรมโดยไม่จำเป็น
    return !_sameItems(oldDelegate.values, values) ||
        !_sameItems(oldDelegate.labels, labels) ||
        oldDelegate.scaleReference != scaleReference ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.peakPrefix != peakPrefix ||
        oldDelegate.averageLabel != averageLabel;
  }
}

/// ตัวเลขบนแกนตั้ง ตัดศูนย์ท้ายทิ้ง: 4 / 2.5 / 0.25
String _tickText(double value) {
  var text = value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
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
