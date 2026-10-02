import '../localization/localized_material.dart';

import '../controllers/schedule_controller.dart';
import '../models/class_schedule.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/floor_selector.dart';
import '../widgets/section_title.dart';
import '../widgets/status_pill.dart';
import '../widgets/weekday_selector.dart';
import 'schedule_management_screen.dart';

int scheduleDayIndexForDate(DateTime date) => date.weekday % 7;

DateTime scheduleDateForDay(DateTime anchorDate, int scheduleDay) {
  assert(scheduleDay >= 0 && scheduleDay <= 6);
  final dateOnly = DateTime(
    anchorDate.year,
    anchorDate.month,
    anchorDate.day,
  );
  return dateOnly.add(
    Duration(days: scheduleDay - scheduleDayIndexForDate(dateOnly)),
  );
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    required this.rooms,
    required this.controller,
    required this.isAdmin,
    required this.onOpenRoom,
    this.onRoomsChanged,
    super.key,
  });

  final List<Room> rooms;
  final ScheduleController controller;
  final bool isAdmin;
  final ValueChanged<Room> onOpenRoom;
  final Future<void> Function()? onRoomsChanged;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final DateTime _today;
  late int _selectedDay;
  int _selectedFloor = 3;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selectedDay = scheduleDayIndexForDate(_today);
  }

  Future<void> _openManager() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ScheduleManagementScreen(
                rooms: widget.rooms,
                controller: widget.controller,
                initialFloor: _selectedFloor,
                initialDay: _selectedDay,
                onRoomsChanged: widget.onRoomsChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          return Column(
            children: [
              _ScheduleHeader(
                canManage: widget.isAdmin,
                onManage: _openManager,
                selectedDate: scheduleDateForDay(_today, _selectedDay),
                isToday: _selectedDay == scheduleDayIndexForDate(_today),
              ),
              Expanded(child: _buildContent(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final controller = widget.controller;

    if (controller.isLoading && !controller.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null && !controller.hasLoaded) {
      return _ScheduleLoadError(
        message: controller.errorMessage!,
        onRetry: controller.reload,
      );
    }

    final floors = widget.rooms.map((room) => room.floor).toSet().toList()
      ..sort();
    if (floors.isNotEmpty && !floors.contains(_selectedFloor)) {
      _selectedFloor = floors.first;
    }
    final floorRooms = widget.rooms
        .where((room) => room.floor == _selectedFloor)
        .toList();
    final scheduledRooms = floorRooms.where((room) {
      return controller.schedulesFor(room.number, _selectedDay).isNotEmpty;
    }).toList();
    final otherRooms = floorRooms
        .where((room) => !scheduledRooms.contains(room))
        .toList();

    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          WeekdaySelector(
            key: const Key('schedule-overview-weekday-selector'),
            selectedDay: _selectedDay,
            dayKeyPrefix: 'schedule-overview-day',
            onChanged: (day) => setState(() => _selectedDay = day),
          ),
          const SizedBox(height: 12),
          FloorSelector(
            selectedFloor: _selectedFloor,
            floors: floors,
            onChanged: (floor) {
              setState(() => _selectedFloor = floor);
            },
          ),
          const SizedBox(height: 20),
          SectionTitle(title: context.tr('Classrooms (Scheduled Control)')),
          const SizedBox(height: 11),
          if (scheduledRooms.isEmpty)
            _EmptyScheduleCard(canManage: widget.isAdmin)
          else
            ...scheduledRooms.map(
              (room) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScheduleCard(
                  room: room,
                  schedules: controller.schedulesFor(room.number, _selectedDay),
                  onTap: () => widget.onOpenRoom(room),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SectionTitle(title: context.tr('Offices / Other Rooms')),
          const SizedBox(height: 11),
          ...otherRooms.map(
            (room) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _CompactRoomCard(
                room: room,
                onTap: () => widget.onOpenRoom(room),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({
    required this.canManage,
    required this.onManage,
    required this.selectedDate,
    required this.isToday,
  });

  final bool canManage;
  final VoidCallback onManage;
  final DateTime selectedDate;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final selectedDateLabel = _formatScheduleDate(context, selectedDate);

    return Container(
      height: 74,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.tr('Room Schedule'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Semantics(
                  label: context.tr(isToday ? 'Today' : 'Selected date'),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: isToday ? 'Today' : 'Selected date',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: ' · $selectedDateLabel'),
                      ],
                    ),
                    key: const Key('schedule-selected-date-label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.90),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              key: const Key('manage-schedule-button'),
              tooltip: context.tr('Manage Timetable'),
              onPressed: onManage,
              icon: const Icon(
                Icons.edit_calendar_rounded,
                color: Colors.white,
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  String _formatScheduleDate(BuildContext context, DateTime date) {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const thaiMonths = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    const englishMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final localizations = AppLocalizations.of(context);
    final weekday = context.tr(weekdays[scheduleDayIndexForDate(date)]);
    if (localizations.isThai) {
      return '$weekday ${date.day} ${thaiMonths[date.month - 1]} '
          '${date.year + 543}';
    }
    return '$weekday, ${date.day} ${englishMonths[date.month - 1]} '
        '${date.year}';
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.room,
    required this.schedules,
    required this.onTap,
  });

  final Room room;
  final List<ClassSchedule> schedules;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.school_rounded,
                    color: colors.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${context.tr('Room')} ${room.number}',
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StatusPill(
                    label: context.tr('Scheduled'),
                    color: colors.primary,
                    backgroundColor: colors.primaryContainer,
                  ),
                ],
              ),
              Divider(color: colors.outlineVariant, height: 16),
              ...schedules.map(
                (schedule) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.circle,
                          color: colors.primary,
                          size: 6,
                        ),
                      ),
                      const SizedBox(width: 9),
                      SizedBox(
                        width: 88,
                        child: Text(
                          '${schedule.startTime} - ${schedule.endTime}',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.subjectName,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (schedule.section.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                schedule.section,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                            if (schedule.instructor.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      schedule.instructor,
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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

class _EmptyScheduleCard extends StatelessWidget {
  const _EmptyScheduleCard({required this.canManage});

  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            color: colors.onSurfaceVariant,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('No class schedule for this floor and day.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (canManage) ...[
            const SizedBox(height: 4),
            Text(
              context.tr('Use the calendar button at the top right to add a class.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleLoadError extends StatelessWidget {
  const _ScheduleLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: colors.error, size: 38),
            const SizedBox(height: 10),
            Text(
              context.tr('Could not load the class schedule.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              context.tr(message),
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('Try Again')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactRoomCard extends StatelessWidget {
  const _CompactRoomCard({required this.room, required this.onTap});

  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: _iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_icon, color: _iconColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.tr('Room')} ${room.number}',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      room.type,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                room.isOccupied ? 'In Use' : room.type,
                style: TextStyle(
                  color: room.isOccupied
                      ? AppColors.green
                      : colors.onSurfaceVariant,
                  fontSize: 9.5,
                  fontWeight: room.isOccupied
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _iconColor {
    switch (room.roomIndex % 3) {
      case 0:
        return AppColors.orange;
      case 1:
        return const Color(0xFF6368CC);
      default:
        return const Color(0xFF996B55);
    }
  }

  IconData get _icon {
    switch (room.roomIndex % 3) {
      case 0:
        return Icons.science_rounded;
      case 1:
        return Icons.meeting_room_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }
}
