import '../localization/localized_material.dart';

import '../controllers/dashboard_controller.dart';
import '../models/energy_data.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';

/// ตัวเลือกช่วงเวลาของหน้าหลักและหน้าสถิติ
///
/// เลือกได้เป็นวัน สัปดาห์ เดือน หรือ `กำหนดเอง` ซึ่งจะเปิดปฏิทินให้เลือก
/// วันเริ่มถึงวันสิ้นสุดในหน้าจอเดียว
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    required this.controller,
    this.onSurfaceDark = false,
    super.key,
  });

  final DashboardController controller;

  /// true เมื่อวางบนพื้นหลังสีเขียวเข้ม ตัวอักษรจะเปลี่ยนเป็นสีขาว
  final bool onSurfaceDark;

  Future<void> _choose(BuildContext context, EnergyPeriodKind kind) async {
    if (kind != EnergyPeriodKind.custom) {
      await controller.setPeriod(kind);
      return;
    }
    await pickCustomRange(context, controller);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = onSurfaceDark ? Colors.white : colors.onSurface;
    final background = onSurfaceDark
        ? Colors.white.withValues(alpha: 0.18)
        : colors.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<EnergyPeriodKind>(
          key: const Key('period-selector'),
          value: controller.period,
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: colors.surface,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: foreground,
            size: 20,
          ),
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          selectedItemBuilder: (context) => [
            for (final kind in EnergyPeriodKind.values)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  kind == EnergyPeriodKind.custom
                      ? describeCustomRange(context, controller)
                      : context.tr(kind.label),
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
          items: [
            for (final kind in EnergyPeriodKind.values)
              DropdownMenuItem(
                value: kind,
                child: Text(
                  context.tr(kind.label),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          onChanged: (kind) {
            if (kind != null) _choose(context, kind);
          },
        ),
      ),
    );
  }
}

/// เปิดปฏิทินเลือกช่วงวันเอง แล้วสั่งโหลดข้อมูลใหม่
Future<void> pickCustomRange(
  BuildContext context,
  DashboardController controller,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final initial = controller.customFrom != null && controller.customTo != null
      ? DateTimeRange(
          start: controller.customFrom!,
          end: controller.customTo!,
        )
      : DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );

  final picked = await showAppDateRangePicker(
    context: context,
    firstDate: DateTime(2024),
    lastDate: today,
    initialRange: initial,
    title: context.tr('Pick a date range'),
  );
  if (picked == null) return;
  await controller.setCustomRange(picked.start, picked.end);
}

/// ข้อความบนปุ่มเมื่อเลือกช่วงเอง เช่น `1 ส.ค. – 5 ส.ค.`
String describeCustomRange(
  BuildContext context,
  DashboardController controller,
) {
  final from = controller.customFrom;
  final to = controller.customTo;
  if (from == null || to == null) return context.tr('Custom range');
  final isThai = AppLocalizations.of(context).isThai;
  final fromText = formatDayMonth(from, isThai);
  final toText = formatDayMonth(to, isThai);
  return fromText == toText ? fromText : '$fromText – $toText';
}

/// ป้ายบอกว่าเพิ่มขึ้นหรือลดลงกี่เปอร์เซ็นต์เทียบกับช่วงก่อนหน้า
class ChangeBadge extends StatelessWidget {
  const ChangeBadge({required this.changePercent, super.key});

  final double? changePercent;

  @override
  Widget build(BuildContext context) {
    final value = changePercent;
    if (value == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          context.tr('No earlier data to compare'),
          style: const TextStyle(
            color: Color(0xFFD7E3E7),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final isDown = value <= 0;
    final magnitude = value.abs().toStringAsFixed(
      value.abs() >= 10 ? 0 : 1,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: (isDown ? AppColors.green : AppColors.red)
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDown ? Icons.south_rounded : Icons.north_rounded,
            color: const Color(0xFFD8FFE0),
            size: 15,
          ),
          const SizedBox(width: 4),
          Text(
            '${context.tr(isDown ? 'Down' : 'Up')} $magnitude%',
            style: const TextStyle(
              color: Color(0xFFD8FFE0),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
