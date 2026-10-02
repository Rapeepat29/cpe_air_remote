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
import '../widgets/auto_off_countdown.dart';
import '../widgets/status_pill.dart';
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
        final onlineCount = room.airConditioners
            .where((air) => air.isOnline)
            .length;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 62,
            title: Column(
              children: [
                Text(
                  context.tr('${context.tr('Room')} ${room.number}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  context.tr(room.type),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10,
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
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.cloud_done_rounded,
                      title: '$onlineCount/${room.airConditioners.length}',
                      subtitle: context.tr('ESP32 online'),
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.hub_rounded,
                      title: context.tr('MQTT'),
                      subtitle: context.tr('Real control'),
                      color: AppColors.orange,
                    ),
                  ),
                ],
              ),
              if (room.isAutoOffPending) ...[
                const SizedBox(height: 12),
                AutoOffCountdown(
                  key: const Key('control-auto-off-countdown'),
                  deadline: room.autoOffDeadlineAt,
                  attempts: room.autoOffAttempts,
                  inClass: room.autoOffInClass,
                ),
              ],
              const SizedBox(height: 12),
              _OccupancyCard(
                room: room,
                isAdmin: widget.isAdmin,
                onConfigure: _openOccupancyProvisioning,
                onRemove: room.hasOccupancySensor
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('Air Conditioners'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: context.tr(
                      '${room.airConditioners.length}/6 ${context.tr('units')}',
                    ),
                    color: AppColors.primary,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              if (room.airConditioners.isEmpty)
                _EmptyAirCard(
                  isAdmin: widget.isAdmin,
                  onAdd: _openProvisioning,
                )
              else
                ...room.airConditioners.map(
                  (air) => Padding(
                    key: ValueKey(air.deviceId ?? air.id),
                    padding: const EdgeInsets.only(bottom: 13),
                    child: AirControlCard(
                      air: air,
                      isAdmin: widget.isAdmin,
                      onCommand: widget.controller.sendCommand,
                      onRename: (name) => widget.controller.rename(air, name),
                      onReconfigure: () => _openProvisioning(air),
                      onDelete: () => _confirmDeleteAir(air),
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: widget.isAdmin
              ? FloatingActionButton.extended(
                  onPressed: room.airConditioners.length >= 6
                      ? null
                      : _openProvisioning,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.bluetooth_rounded),
                  label: Text(
                    context.tr(
                      room.airConditioners.length >= 6
                          ? '6-unit limit reached'
                          : 'Add ESP32 Air Conditioner',
                    ),
                  ),
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

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({
    required this.room,
    required this.isAdmin,
    required this.onConfigure,
    required this.onRemove,
  });

  final Room room;
  final bool isAdmin;
  final VoidCallback onConfigure;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasSensor = room.hasOccupancySensor;
    final ready = hasSensor &&
        room.occupancySensorOnline &&
        room.occupancySensorAvailable;

    late final IconData icon;
    late final String title;
    late final String subtitle;
    late final Color color;
    if (!hasSensor) {
      icon = Icons.sensors_off_rounded;
      title = 'No occupancy sensor';
      subtitle = 'Add one ESP32 + LD2410 for this room';
      color = colors.onSurfaceVariant;
    } else if (room.occupancySensorProvisionStatus == 'reserved') {
      icon = Icons.pending_rounded;
      title = 'Occupancy sensor not activated yet';
      subtitle = 'Saved in the database but the ESP32 has not confirmed '
          'over MQTT. Set it up over Bluetooth again.';
      color = AppColors.orange;
    } else if (!room.occupancySensorOnline) {
      icon = Icons.cloud_off_rounded;
      title = 'Occupancy sensor offline';
      subtitle = 'The last room state may be out of date';
      color = AppColors.orange;
    } else if (!room.occupancySensorAvailable) {
      icon = Icons.radar_rounded;
      title = 'LD2410 data unavailable';
      subtitle = 'Check the radar UART connection';
      color = AppColors.orange;
    } else if (room.isOccupied) {
      icon = Icons.groups_rounded;
      title = 'People detected in this room';
      subtitle = 'A static target gate is greater than 25';
      color = AppColors.green;
    } else {
      icon = Icons.person_off_outlined;
      title = 'No people detected in this room';
      subtitle = 'Every static target gate is 25 or lower';
      color = colors.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(title),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  context.tr(subtitle),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ready)
                  Text(
                    'LD2410 • threshold > ${room.occupancyStaticThreshold}',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.82),
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          ),
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'configure') onConfigure();
                if (value == 'remove') onRemove?.call();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'configure',
                  child: Text(
                    context.tr(hasSensor ? 'Reconfigure' : 'Add sensor'),
                  ),
                ),
                if (hasSensor)
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      context.tr('Remove'),
                      style: const TextStyle(color: AppColors.red),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: color, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAirCard extends StatelessWidget {
  const _EmptyAirCard({required this.isAdmin, required this.onAdd});

  final bool isAdmin;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bluetooth_searching_rounded,
            color: colors.onSurfaceVariant,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('This room has no registered ESP32 yet'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.tr(
              isAdmin
                  ? 'Find the board via Bluetooth to configure Wi-Fi and MQTT.'
                  : 'An administrator must configure the ESP32 via Bluetooth.',
            ),
            textAlign: TextAlign.center,
          ),
          if (isAdmin) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.bluetooth_rounded),
              label: Text(context.tr('Find ESP32')),
            ),
          ],
        ],
      ),
    );
  }
}
