import '../localization/localized_material.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../models/energy_data.dart';
import '../models/room.dart';
import '../models/system_alert.dart';
import '../theme/app_theme.dart';
import '../utils/number_format.dart';
import '../widgets/brand_mark.dart';
import '../widgets/period_selector.dart';
import '../widgets/section_title.dart';
import '../widgets/status_pill.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.rooms,
    required this.appSettingsController,
    required this.dashboardController,
    required this.onOpenRoom,
    required this.onOpenControl,
    super.key,
  });

  final List<Room> rooms;
  final AppSettingsController appSettingsController;
  final DashboardController dashboardController;
  final ValueChanged<Room> onOpenRoom;
  final VoidCallback onOpenControl;

  Room? _room(String number) {
    for (final room in rooms) {
      if (room.number == number) return room;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: dashboardController,
      builder: (context, _) {
        final summary = dashboardController.summary;
        final alerts = dashboardController.alerts;

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              _HomeHeader(openAlerts: dashboardController.openAlertCount),
              if (dashboardController.isLoading &&
                  !dashboardController.hasLoaded)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: dashboardController.refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                    children: [
                      _EnergyCard(
                        summary: summary,
                        controller: dashboardController,
                        electricityCost: appSettingsController
                            .calculateElectricityCost(summary.totalKwh),
                        onTap: onOpenControl,
                      ),
                      if (dashboardController.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _ErrorNote(
                          message: dashboardController.errorMessage!,
                        ),
                      ],
                      const SizedBox(height: 22),
                      SectionTitle(
                        title: context.tr('🔔 System Alerts'),
                        trailing: dashboardController.openAlertCount > 0
                            ? StatusPill(
                                label: context.tr(
                                  '${dashboardController.openAlertCount} '
                                  'need attention',
                                ),
                                color: AppColors.orange,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      if (dashboardController.alertsErrorMessage != null)
                        _ErrorNote(
                          message: dashboardController.alertsErrorMessage!,
                        )
                      else if (alerts.isEmpty)
                        const _NoAlertsCard()
                      else
                        ...alerts.map(
                          (alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AlertCard(
                              alert: alert,
                              room: _room(alert.roomNumber),
                              onTap: () {
                                final room = _room(alert.roomNumber);
                                if (room != null) onOpenRoom(room);
                              },
                              onAcknowledge: alert.isOpen
                                  ? () => _acknowledge(context, alert)
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _acknowledge(BuildContext context, SystemAlert alert) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await dashboardController.acknowledge(alert.id);
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('ApiException: ', ''),
            ),
            backgroundColor: AppColors.red,
          ),
        );
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.openAlerts});

  final int openAlerts;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      height: 58,
      color: palette.bar,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const BrandMark(size: 32),
          const SizedBox(width: 10),
          const Expanded(child: BrandWordmark()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: openAlerts > 0 ? palette.warnSoft : palette.accentSoft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              openAlerts > 0
                  ? '${context.tr('Building 16')} · $openAlerts'
                  : context.tr('Building 16'),
              style: TextStyle(
                color: openAlerts > 0 ? palette.warn : palette.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({
    required this.summary,
    required this.controller,
    required this.electricityCost,
    required this.onTap,
  });

  final EnergySummary summary;
  final DashboardController controller;
  final double electricityCost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    // สลับหน่วยตามขนาดของค่า ที่ชาร์จมือถือระดับ 0.005 kWh จะได้ไม่กลายเป็น 0.0
    final total = formatEnergy(summary.totalKwh);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        // ธีมพื้นเข้มใช้เส้นขอบแทนเงา เพราะเงาบนพื้นเข้มมองไม่เห็น
        border: isLight ? null : Border.all(color: colors.outlineVariant),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: PeriodSelector(controller: controller),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.bolt_rounded, color: palette.accent, size: 28),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr('Energy used'),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                total.value,
                style: TextStyle(
                  color: palette.accent,
                  fontFamily: kDisplayFont,
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  total.unit,
                  style: TextStyle(
                    color: palette.accent,
                    fontFamily: kDisplayFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary.from.isEmpty
                ? context.tr('No stored hours yet.')
                : (summary.from == summary.to
                      ? summary.from
                      : '${summary.from} – ${summary.to}'),
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: colors.outlineVariant),
          const SizedBox(height: 10),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payments_rounded,
                    color: palette.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      // ประกอบเป็นประโยคอังกฤษก่อน แล้วให้ตัวแปลจัดทั้งก้อน
                      // ภาษาไทยวางหน่วยเงินไว้ท้ายประโยค การแปลทีละคำแล้ว
                      // ต่อกันเองจะได้ `ค่าไฟโดยประมาณ: บาท 1,420.13` ซึ่งผิด
                      'Estimated cost: THB '
                      '${formatDecimal(electricityCost)}',
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoAlertsCard extends StatelessWidget {
  const _NoAlertsCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.verified_rounded,
            color: colors.primary,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Nothing needs attention right now'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              'Alerts appear here when an air conditioner runs outside '
              'class hours, or after the system switches one off.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.red,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.room,
    required this.onTap,
    required this.onAcknowledge,
  });

  final SystemAlert alert;
  final Room? room;
  final VoidCallback onTap;
  final VoidCallback? onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = alert.isWarning
        ? (alert.isOpen ? AppColors.orange : colors.onSurfaceVariant)
        : colors.primary;
    final currentRoom = room;
    final title = currentRoom == null
        ? '${context.tr('Room')} ${alert.roomNumber}'
        : context.tr('Room ${currentRoom.number} (${currentRoom.type})');

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  alert.isWarning
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded,
                  color: statusColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          formatClock(alert.createdAt),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.tr(alert.kind.message),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                    if (alert.deviceName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        alert.deviceName,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        StatusPill(
                          label: _statusLabel(),
                          color: statusColor,
                        ),
                        if (onAcknowledge != null) ...[
                          const Spacer(),
                          TextButton(
                            onPressed: onAcknowledge,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                            child: Text(context.tr('Mark as handled')),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel() => switch (alert.status) {
    'open' => 'Pending',
    'acknowledged' => 'Handled',
    _ => 'Completed',
  };
}

/// 2026-08-21T18:30:00Z -> '18:30' ตามเวลาเครื่องของผู้ใช้
String formatClock(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
