import '../localization/localized_material.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../models/energy_data.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/number_format.dart';
import '../widgets/energy_usage_chart.dart';
import '../widgets/floor_selector.dart';
import '../widgets/period_selector.dart';
import '../widgets/section_title.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({
    required this.rooms,
    required this.appSettingsController,
    required this.dashboardController,
    super.key,
  });

  final List<Room> rooms;
  final AppSettingsController appSettingsController;
  final DashboardController dashboardController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        dashboardController,
        appSettingsController,
      ]),
      builder: (context, _) {
        final summary = dashboardController.summary;
        final floors = rooms.map((room) => room.floor).toSet().toList()
          ..sort();
        final visibleRooms = dashboardController.floor == null
            ? summary.rooms
            : summary.rooms
                  .where(
                    (usage) =>
                        usage.floorNumber == dashboardController.floor,
                  )
                  .toList();
        // ทุกการ์ดใช้หน่วยเดียวกัน คิดจากห้องที่กินไฟมากสุดของรายการที่เห็น
        // ไม่งั้น 900 Wh จะดูเหมือนมากกว่า 1.2 kWh
        final roomScale = energyScaleReference(
          visibleRooms.map((usage) => usage.kwh),
        );

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              _SummaryHeader(
                summary: summary,
                controller: dashboardController,
                appSettingsController: appSettingsController,
              ),
              if (dashboardController.isLoading &&
                  !dashboardController.hasLoaded)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: dashboardController.refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                    children: [
                      if (floors.length > 1) ...[
                        FloorSelector(
                          selectedFloor: dashboardController.floor ?? -1,
                          floors: [-1, ...floors],
                          onChanged: (floor) => dashboardController.setFloor(
                            floor == -1 ? null : floor,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SectionTitle(
                        title: context.tr('Usage by Room'),
                        trailing: Text(
                          dashboardController.floor == null
                              ? context.tr('All floors')
                              : context.tr(
                                  'Floor ${dashboardController.floor}',
                                ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 13),
                      if (dashboardController.errorMessage != null)
                        _Note(
                          icon: Icons.error_outline_rounded,
                          color: AppColors.red,
                          text: dashboardController.errorMessage!,
                        )
                      else if (visibleRooms.isEmpty)
                        _Note(
                          icon: Icons.insights_rounded,
                          color: AppColors.orange,
                          text: context.tr(
                            'No stored energy for this period yet. Values '
                            'appear once an ESP32 with a PZEM-004T reports '
                            'in.',
                          ),
                        )
                      else
                        ...visibleRooms.map(
                          (usage) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _UsageRoomCard(
                              usage: usage,
                              scaleReference: roomScale,
                              appSettingsController: appSettingsController,
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
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.summary,
    required this.controller,
    required this.appSettingsController,
  });

  final EnergySummary summary;
  final DashboardController controller;
  final AppSettingsController appSettingsController;

  @override
  Widget build(BuildContext context) {
    // ยอดรวมใช้หน่วยของตัวเอง เพราะเป็นตัวเลขเดี่ยว ไม่ได้เทียบกับใคร
    final total = formatEnergy(summary.totalKwh);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Energy Summary'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PeriodSelector(controller: controller, onSurfaceDark: true),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            summary.from.isEmpty
                ? context.tr(summary.kind.label)
                : (summary.from == summary.to
                      ? summary.from
                      : '${summary.from} – ${summary.to}'),
            style: const TextStyle(color: Color(0xFFD7E3E7), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      // เช่นเดียวกับหน้าหลัก ให้ตัวแปลจัดทั้งประโยค
                      // เพราะภาษาไทยวางคำว่าบาทไว้ท้าย ไม่ใช่หน้าตัวเลข
                      '≈ THB '
                      '${formatDecimal(
                        appSettingsController.calculateElectricityCost(
                          summary.totalKwh,
                        ),
                      )}',
                      style: const TextStyle(
                        color: Color(0xFFCDF1D2),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              ChangeBadge(changePercent: summary.changePercent),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 162,
            width: double.infinity,
            child: EnergyUsageChart(
              points: summary.series,
              costLabel: (kwh) =>
                  '${context.tr('THB')} '
                  '${formatDecimal(
                    appSettingsController.calculateElectricityCost(kwh),
                  )}',
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageRoomCard extends StatelessWidget {
  const _UsageRoomCard({
    required this.usage,
    required this.scaleReference,
    required this.appSettingsController,
  });

  final EnergyRoomUsage usage;

  /// ค่าที่สูงสุดของรายการนี้ ใช้เลือกหน่วยร่วมของทุกการ์ด
  final double scaleReference;
  final AppSettingsController appSettingsController;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final energy = formatEnergy(usage.kwh, scaleReference: scaleReference);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.ac_unit_rounded,
              color: Color(0xFF72A5AE),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('${usage.deviceCount} units'),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr(
                    'Floor ${usage.floorNumber} · Room ${usage.roomNumber}',
                  ),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${context.tr('Runtime')} '
                  '${formatDecimal(usage.runtimeMinutes, decimalPlaces: 0)}'
                  ' ${context.tr('min')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                energy.text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${context.tr('THB')} '
                '${formatDecimal(
                  appSettingsController.calculateElectricityCost(usage.kwh),
                )}',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
