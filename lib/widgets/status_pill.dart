import '../localization/localized_material.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.color,
    super.key,
    this.backgroundColor,
    this.icon,
  });

  final String label;
  final Color color;
  final Color? backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // สีสถานะส่วนใหญ่ (AppColors) เข้มสำหรับพื้นสว่าง บนพื้นเข้มของธีมเทา/ดำ
    // ตัวหนังสือจะจมหาย จึงผสมขาวเข้าไปให้สว่างขึ้นแต่ยังเป็นสีเดิม
    final foreground = isDark ? Color.lerp(color, Colors.white, 0.45)! : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.18)
            : backgroundColor ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: foreground, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
