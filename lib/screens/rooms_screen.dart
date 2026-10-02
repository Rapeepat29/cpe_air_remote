import '../localization/localized_material.dart';

import '../models/room.dart';
import '../controllers/room_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/auto_off_countdown.dart';
import '../widgets/floor_selector.dart';
import '../widgets/status_pill.dart';
import 'room_management_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    required this.rooms,
    required this.controller,
    required this.isAdmin,
    required this.onOpenRoom,
    super.key,
  });

  final List<Room> rooms;
  final RoomController controller;
  final bool isAdmin;
  final ValueChanged<Room> onOpenRoom;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  int _selectedFloor = 3;

  Future<void> _openManager() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: RoomManagementScreen(controller: widget.controller),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final floors = widget.rooms.map((room) => room.floor).toSet().toList()
      ..sort();
    if (floors.isEmpty) {
      _selectedFloor = 0;
    } else if (!floors.contains(_selectedFloor)) {
      _selectedFloor = floors.first;
    }
    final filteredRooms = widget.rooms
        .where((room) => room.floor == _selectedFloor)
        .toList();

    return SafeArea(
      bottom: false,
      child: ColoredBox(
        color: colors.surfaceContainerLow,
        child: Column(
          children: [
            _RoomsHeader(
              isAdmin: widget.isAdmin,
              onManageRooms: _openManager,
            ),
            if (widget.controller.isLoading && !widget.controller.hasLoaded)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.controller.reload,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    FloorSelector(
                      selectedFloor: _selectedFloor,
                      floors: floors,
                      onChanged: (floor) {
                        setState(() => _selectedFloor = floor);
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedFloor == 0
                                ? 'Special rooms'
                                : '${context.tr('Floor')} $_selectedFloor',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: '${filteredRooms.length} ${context.tr('rooms')}',
                          color: colors.primary,
                          backgroundColor: colors.primaryContainer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (filteredRooms.isEmpty)
                      _EmptyRoomsCard(colorScheme: colors)
                    else
                      ...filteredRooms.map(
                        (room) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RoomCard(
                            room: room,
                            onTap: () => widget.onOpenRoom(room),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomsHeader extends StatelessWidget {
  const _RoomsHeader({
    required this.isAdmin,
    required this.onManageRooms,
  });

  final bool isAdmin;
  final VoidCallback onManageRooms;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('rooms-header'),
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.primary,
      child: Row(
        children: [
          const SizedBox(width: 44),
          Expanded(
            child: Text(
              context.tr('Choose a Room to Control'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (isAdmin)
            IconButton(
              key: const Key('manage-rooms-button'),
              tooltip: context.tr('Manage Rooms'),
              onPressed: onManageRooms,
              color: Colors.white,
              icon: const Icon(Icons.settings_rounded, size: 24),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _EmptyRoomsCard extends StatelessWidget {
  const _EmptyRoomsCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.meeting_room_outlined,
            color: colorScheme.primary,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('No rooms in this group.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.onTap,
  });

  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final occupancyReady = room.hasOccupancySensor &&
        room.occupancySensorOnline &&
        room.occupancySensorAvailable;
    final occupancyIcon = !room.hasOccupancySensor
        ? Icons.sensors_off_rounded
        : !occupancyReady
        ? Icons.radar_rounded
        : room.isOccupied
        ? Icons.groups_rounded
        : Icons.person_off_outlined;
    final occupancyLabel = !room.hasOccupancySensor
        ? 'No sensor'
        : !occupancyReady
        ? 'Sensor unavailable'
        : room.isOccupied
        ? 'Occupied'
        : 'Vacant';
    final occupancyColor = occupancyReady && room.isOccupied
        ? AppColors.green
        : room.hasOccupancySensor && !occupancyReady
        ? AppColors.orange
        : colors.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.ac_unit_rounded,
                    color: colors.primary,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${context.tr('Room')} ${room.number}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(
                            label: '${room.displayedAirCount} ${context.tr('units')}',
                            color: colors.primary,
                            backgroundColor: colors.primaryContainer,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        room.type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (room.isAutoOffPending) ...[
                        const SizedBox(height: 6),
                        AutoOffCountdown(
                          key: const Key('room-auto-off-countdown'),
                          deadline: room.autoOffDeadlineAt,
                          attempts: room.autoOffAttempts,
                          inClass: room.autoOffInClass,
                          compact: true,
                        ),
                      ],
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(
                            occupancyIcon,
                            color: occupancyColor,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr(occupancyLabel),
                            style: TextStyle(
                              color: occupancyColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: room.isOnline
                                  ? AppColors.green
                                  : AppColors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            room.isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
