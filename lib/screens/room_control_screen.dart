import '../localization/localized_material.dart';

import '../controllers/air_conditioner_controller.dart';
import '../controllers/room_controller.dart';
import '../models/air_conditioner.dart';
import '../models/room.dart';
import '../services/air_conditioner_repository.dart';
import '../services/ble_provisioning_service.dart';
import '../services/occupancy_sensor_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/air_control_card.dart';
import 'ble_provisioning_screen.dart';
import 'occupancy_provisioning_screen.dart';

class RoomControlScreen extends StatefulWidget {
  const RoomControlScreen({
    required this.room,
    required this.isAdmin,
    required this.controller,
    required this.roomController,
    required this.repository,
    required this.occupancyRepository,
    required this.bleService,
    super.key,
  });

  final Room room;
  final bool isAdmin;
  final AirConditionerController controller;
  final RoomController roomController;
  final AirConditionerRepository repository;
  final OccupancySensorRepository occupancyRepository;
  final BleProvisioningService bleService;

  @override
  State<RoomControlScreen> createState() => _RoomControlScreenState();
}

class _RoomControlScreenState extends State<RoomControlScreen> {
  // RoomController.reload() สร้าง Room object ใหม่ทุกครั้ง ถ้าหน้าจอนี้ยึด
  // object ที่ได้ตอนเปิดหน้า ค่าที่โหลดมาใหม่จะไม่ขึ้นจนกว่าจะออกแล้วเข้าห้อง
  // ใหม่ จึงต้องอ่านห้องล่าสุดจาก controller ทุกครั้งที่ build
  Room get room =>
      widget.roomController.roomByNumber(widget.room.number) ?? widget.room;

  @override
  void initState() {
    super.initState();
    // ดึงค่าล่าสุดทันทีที่เปิดห้อง ไม่ต้องรอรอบอัตโนมัติ 10 วินาที
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        widget.roomController,
      ]),
      builder: (context, _) {
        final colors = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 62,
            title: Column(
              children: [
                Text(
                  context.tr('${context.tr('Room')} ${room.number}'),
                  style: TextStyle(
                    color: AppPalette.of(context).onBar,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  context.tr(room.type),
                  style: TextStyle(
                    color: AppPalette.of(context)
                        .onBar
                        .withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: context.tr('Refresh devices'),
                onPressed: widget.controller.isLoading
                    ? null
                    : _refreshAll,
                icon: widget.controller.isLoading
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppPalette.of(context).onBar,
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        color: AppPalette.of(context).onBar,
                      ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _RoomSummaryCard(
                room: room,
                isAdmin: widget.isAdmin,
                onConfigureSensor: _openOccupancyProvisioning,
                onRemoveSensor: room.hasOccupancySensor
                    ? _confirmRemoveOccupancySensor
                    : null,
              ),
              if (widget.controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(widget.controller.errorMessage!),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Air conditioner list'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${room.airConditioners.length} / 6 ${context.tr('units')}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (room.airConditioners.isEmpty)
                _EmptyAirCard(isAdmin: widget.isAdmin)
              else
                ...room.airConditioners.map(
                  (air) => Padding(
                    key: ValueKey(air.deviceId ?? air.id),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AirControlCard(
                      air: air,
                      isAdmin: widget.isAdmin,
                      onCommand: widget.controller.sendCommand,
                      onRename: (name) => widget.controller.rename(air, name),
                      onReconfigure: () => _openProvisioning(air),
                      onDelete: () => _confirmDeleteAir(air),
                      onRetry: _refreshAll,
                      roomAutoOffDeadline: room.autoOffDeadlineAt,
                      roomAutoOffAttempts: room.autoOffAttempts,
                    ),
                  ),
                ),
            ],
          ),
          // ปุ่มล่าง: เพิ่มเซนเซอร์ (เมื่อยังไม่มี) และเพิ่มอุปกรณ์ ESP32
          bottomNavigationBar: widget.isAdmin
              ? _BottomActions(
                  showAddSensor: !room.hasOccupancySensor,
                  canAddAir: room.airConditioners.length < 6,
                  onAddSensor: _openOccupancyProvisioning,
                  onAddAir: () => _openProvisioning(),
                )
              : null,
        );
      },
    );
  }

  Future<void> _openProvisioning([AirConditioner? existingAir]) async {
    if (!widget.isAdmin) return;
    if (existingAir == null && room.airConditioners.length >= 6) return;
    final deviceId = existingAir?.deviceId;
    if (deviceId != null) {
      try {
        await widget.repository.enterSetupMode(deviceId);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'The app could not request Bluetooth setup through MQTT. '
                'The ESP32 may already be in recovery mode; try searching. '
                'If it is not found, hold BOOT and press RESET.',
              ),
            ),
          ),
        );
      }
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => BleProvisioningScreen(
          roomNumber: room.number,
          usedAirNumbers: room.airConditioners.map((air) => air.id).toSet(),
          repository: widget.repository,
          bleService: widget.bleService,
          existingAir: existingAir,
        ),
      ),
    );
    if (saved == true) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await widget.controller.refresh();
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      widget.controller.refresh(),
      widget.roomController.reload(),
    ]);
  }

  Future<void> _openOccupancyProvisioning() async {
    if (!widget.isAdmin) return;
    final deviceId = room.occupancySensorDeviceId;
    if (deviceId != null) {
      try {
        await widget.occupancyRepository.enterSetupMode(deviceId);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'The occupancy ESP32 may already be in setup mode. If it is not found, hold BOOT and press RESET.',
              ),
            ),
          ),
        );
      }
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => OccupancyProvisioningScreen(
          room: room,
          repository: widget.occupancyRepository,
          bleService: widget.bleService,
        ),
      ),
    );
    if (saved == true) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await widget.roomController.reload();
    }
  }

  Future<void> _confirmRemoveOccupancySensor() async {
    final deviceId = room.occupancySensorDeviceId;
    if (deviceId == null || !widget.isAdmin) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove occupancy sensor')),
        content: Text(
          context.tr('Remove the occupancy sensor from this room?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(context.tr('Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.occupancyRepository.remove(deviceId);
      await widget.roomController.reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAir(AirConditioner air) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Remove Air Conditioner')),
        content: Text(
          context.tr('${context.tr('Remove')} ${air.name} ${context.tr('from this room?')}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(context.tr('Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.remove(air);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

/// การ์ดสรุปห้อง: แอร์ที่เปิดอยู่ กำลังไฟรวม และสถานะของห้องเป็นรายการ ชื่อ–ค่า
class _RoomSummaryCard extends StatelessWidget {
  const _RoomSummaryCard({
    required this.room,
    required this.isAdmin,
    required this.onConfigureSensor,
    required this.onRemoveSensor,
  });

  final Room room;
  final bool isAdmin;
  final VoidCallback onConfigureSensor;
  final VoidCallback? onRemoveSensor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final airs = room.airConditioners;
    final onCount = airs.where((air) => air.canControl && air.isOn).length;
    final onlineCount = airs.where((air) => air.isOnline).length;
    final (sensorText, sensorColor) = _sensorStatus(context, palette);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Air conditioners running'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$onCount',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' / ${airs.length} ${context.tr('units')}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      context.tr('Total power'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(room.totalPower / 1000).toStringAsFixed(2)} kW',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _SummaryRow(
            label: context.tr('ESP32 online'),
            value:
                '$onlineCount ${context.tr('of')} ${airs.length}',
          ),
          _SummaryRow(
            label: context.tr('Control mode'),
            value: context.tr('MQTT (real devices)'),
          ),
          _SummaryRow(
            label: context.tr('Occupancy sensor'),
            value: sensorText,
            valueColor: sensorColor,
            trailing: isAdmin
                ? PopupMenuButton<String>(
                    tooltip: context.tr('Options'),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'configure') onConfigureSensor();
                      if (value == 'remove') onRemoveSensor?.call();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'configure',
                        child: Text(
                          context.tr(
                            room.hasOccupancySensor
                                ? 'Reconfigure'
                                : 'Add sensor',
                          ),
                        ),
                      ),
                      if (room.hasOccupancySensor)
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(
                            context.tr('Remove'),
                            style: TextStyle(color: palette.danger),
                          ),
                        ),
                    ],
                  )
                : null,
          ),
        ],
      ),
    );
  }

  /// ข้อความสั้นของสถานะเซนเซอร์ เรียงจากเรื่องที่ต้องแก้ก่อน
  (String, Color) _sensorStatus(BuildContext context, AppPalette palette) {
    final colors = Theme.of(context).colorScheme;
    if (!room.hasOccupancySensor) {
      return (context.tr('Not installed'), palette.warn);
    }
    if (room.occupancySensorProvisionStatus == 'reserved') {
      return (context.tr('Awaiting confirmation'), palette.warn);
    }
    if (!room.occupancySensorOnline) {
      return (context.tr('Sensor offline'), palette.warn);
    }
    if (!room.occupancySensorAvailable) {
      return (context.tr('Radar data unavailable'), palette.warn);
    }
    if (room.isOccupied) {
      return (context.tr('People detected'), palette.accent);
    }
    return (context.tr('No people detected'), colors.onSurface);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: EdgeInsets.only(left: 16, right: trailing == null ? 16 : 0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: valueColor ?? colors.onSurface,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// ปุ่มล่างของหน้าห้อง (แอดมินเท่านั้น)
class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.showAddSensor,
    required this.canAddAir,
    required this.onAddSensor,
    required this.onAddAir,
  });

  final bool showAddSensor;
  final bool canAddAir;
  final VoidCallback onAddSensor;
  final VoidCallback onAddAir;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (showAddSensor) ...[
                Expanded(
                  child: OutlinedButton(
                    key: const Key('room-add-sensor-button'),
                    onPressed: onAddSensor,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(context.tr('Add sensor')),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  key: const Key('room-add-air-button'),
                  onPressed: canAddAir ? onAddAir : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    context.tr(
                      canAddAir ? 'Add ESP32 device' : '6-unit limit reached',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAirCard extends StatelessWidget {
  const _EmptyAirCard({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bluetooth_searching_rounded,
            color: colors.onSurfaceVariant,
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('This room has no ESP32 device yet'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              isAdmin
                  ? 'Find the device via Bluetooth to set up Wi-Fi and MQTT.'
                  : 'An administrator must configure the ESP32 via Bluetooth.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
