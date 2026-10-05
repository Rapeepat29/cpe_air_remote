import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ไอคอนโลโก้ RMUTT Save Energy วาดด้วยโค้ด
///
/// วาดเองแทนการใช้ไฟล์ภาพ เพราะแอปยังไม่มีแพ็กเกจอ่าน SVG และไฟล์ PNG
/// จะเบลอเมื่อขยาย พิกัดทั้งหมดมาจาก rmutt-save-energy-icon.svg (กรอบ 240×240)
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 34, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'RMUTT Save Energy',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _BrandMarkPainter()),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 240;
    canvas.save();
    canvas.scale(scale);

    // พื้นสี่เหลี่ยมมุมมน
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 240, 240),
        const Radius.circular(56),
      ),
      Paint()..color = AppColors.charcoal,
    );

    canvas.translate(-2, -10);

    // ใบไม้
    final leaf = Path()
      ..moveTo(110, 150)
      ..cubicTo(150, 144, 184, 170, 184, 208)
      ..cubicTo(146, 208, 110, 186, 110, 150)
      ..close();
    canvas.drawPath(leaf, Paint()..color = AppColors.leaf);

    // เส้นกลางใบ
    canvas.drawLine(
      const Offset(122, 160),
      const Offset(172, 198),
      Paint()
        ..color = AppColors.charcoal
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // ตัว R
    final letter = Path()
      ..moveTo(82, 184)
      ..lineTo(82, 73)
      ..lineTo(126, 73)
      ..arcToPoint(
        const Offset(126, 139),
        radius: const Radius.circular(33),
        clockwise: true,
      )
      ..lineTo(82, 139);
    canvas.drawPath(
      letter,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) => false;
}

/// ชื่อแอปแบบโลโก้: R และ Energy สีเขียว ส่วน MUTT สีตามแถบหัว
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({this.fontSize = 20, super.key});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final green = TextStyle(color: palette.barLogoGreen);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'R', style: green),
          const TextSpan(text: 'MUTT '),
          TextSpan(text: 'Energy', style: green),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.onBar,
        fontFamily: kDisplayFont,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}
