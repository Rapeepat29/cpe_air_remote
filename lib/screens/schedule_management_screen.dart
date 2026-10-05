import '../localization/localized_material.dart';

import '../controllers/schedule_controller.dart';
import '../models/class_schedule.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/floor_selector.dart';
import '../widgets/weekday_selector.dart';
import 'schedule_import_screen.dart';

class ScheduleManagementScreen extends StatefulWidget {
  const ScheduleManagementScreen({
    required this.rooms,
    required this.controller,
    required this.initialFloor,
    required this.initialDay,
    this.onRoomsChanged,
    super.key,
  });

  final List<Room> rooms;
  final ScheduleController controller;
  final int initialFloor;
  final int initialDay;
  final Future<void> Function()? onRoomsChanged;

  @override
  State<ScheduleManagementScreen> createState() =>
      _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  late int _selectedFloor;
  late int _selectedDay;
  late String _selectedRoomNumber;
  bool _isClearingAll = false;

  static const _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFloor = widget.initialFloor;
    _selectedDay = widget.initialDay;
    _selectedRoomNumber = _preferredRoomNumber();
  }

  String _preferredRoomNumber() {
    final floorRooms = _roomsOnFloor(widget.initialFloor);
    for (final room in floorRooms) {
      if (widget.controller
          .schedulesFor(room.number, widget.initialDay)
          .isNotEmpty) {
        return room.number;
      }
    }
    return floorRooms.isEmpty ? '' : floorRooms.first.number;
  }

  List<Room> _roomsOnFloor(int floor) {
    return widget.rooms.where((room) => room.floor == floor).toList()
      ..sort((first, second) => first.roomIndex.compareTo(second.roomIndex));
  }

  List<int> get _floors =>
      (widget.rooms.map((room) => room.floor).toSet().toList()..sort());

  void _changeFloor(int floor) {
    final rooms = _roomsOnFloor(floor);
    if (rooms.isEmpty) return;
    setState(() {
      _selectedFloor = floor;
      _selectedRoomNumber = rooms.first.number;
    });
  }

  Future<void> _openEditor([ClassSchedule? schedule]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _ScheduleEditorSheet(
        controller: widget.controller,
        roomNumber: _selectedRoomNumber,
        dayOfWeek: _selectedDay,
        schedule: schedule,
      ),
    );
  }

  Future<void> _openImporter() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ScheduleImportScreen(
                controller: widget.controller,
                onRoomsChanged: widget.onRoomsChanged,
              ),
            ),
          ),
        ),
      ),
    );
    if (imported == true && mounted) {
      final floors = _floors;
      if (floors.isEmpty) {
        setState(() {
          _selectedFloor = 0;
          _selectedRoomNumber = '';
        });
        return;
      }
      final nextFloor = floors.contains(_selectedFloor)
          ? _selectedFloor
          : floors.first;
      final rooms = _roomsOnFloor(nextFloor);
      setState(() {
        _selectedFloor = nextFloor;
        if (!rooms.any((room) => room.number == _selectedRoomNumber)) {
          _selectedRoomNumber = rooms.first.number;
        }
      });
    }
  }

  Future<void> _confirmDelete(ClassSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete class schedule?')),
        content: Text(
          '${schedule.startTime} - ${schedule.endTime}\n'
          '${schedule.subjectName}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            key: Key('confirm-delete-schedule-${schedule.id}'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.controller.deleteSchedule(schedule.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('Class schedule deleted.'))));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr(error.toString()))));
    }
  }

  Future<void> _confirmClearAll() async {
    final scheduleCount = widget.controller.schedules.length;
    if (scheduleCount == 0 || _isClearingAll) return;

    final message = context
        .tr(
          'This will permanently delete all {count} class schedules from every room. Rooms, air conditioners, users, and other settings will not be deleted.',
        )
        .replaceAll('{count}', '$scheduleCount');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.delete_sweep_rounded, color: colors.error, size: 34),
          title: Text(context.tr('Clear all class schedules?')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              Text(
                context.tr('This action cannot be undone.'),
                style: TextStyle(
                  color: colors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton.icon(
              key: const Key('confirm-clear-all-schedules'),
              style: FilledButton.styleFrom(backgroundColor: colors.error),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_sweep_rounded),
              label: Text(context.tr('Clear all')),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isClearingAll = true);
    try {
      final deletedCount = await widget.controller.deleteAllSchedules();
      if (!mounted) return;
      final successMessage = context.tr(
        'All class schedules have been cleared.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successMessage ($deletedCount)')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr(error.toString()))));
    } finally {
      if (mounted) {
        setState(() => _isClearingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final floorRooms = _roomsOnFloor(_selectedFloor);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('Manage Timetable'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            key: const Key('open-schedule-import'),
            tooltip: context.tr('Import Excel or CSV'),
            onPressed: _openImporter,
            icon: const Icon(Icons.upload_file_rounded),
          ),
          IconButton(
            key: const Key('clear-all-schedules-button'),
            tooltip: context.tr(
              _isClearingAll ? 'Clearing...' : 'Clear all schedules',
            ),
            onPressed:
                widget.controller.schedules.isEmpty || _isClearingAll
                    ? null
                    : _confirmClearAll,
            icon: _isClearingAll
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: AppPalette.of(context).onBar,
                    ),
                  )
                : const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final schedules = widget.controller.schedulesFor(
            _selectedRoomNumber,
            _selectedDay,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
            children: [
              Text(
                context.tr('Choose a room and day, then add or edit its class schedule.'),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 18),
              _FieldLabel(label: context.tr('Floor')),
              const SizedBox(height: 8),
              FloorSelector(
                selectedFloor: _selectedFloor,
                floors: _floors,
                onChanged: _changeFloor,
              ),
              const SizedBox(height: 18),
              _FieldLabel(label: context.tr('Room')),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: floorRooms.map((room) {
                    final selected = room.number == _selectedRoomNumber;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: Key('schedule-room-${room.number}'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _selectedRoomNumber = room.number);
                        },
                        label: Text('${context.tr('Room')} ${room.number}'),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              _FieldLabel(label: context.tr('Day')),
              const SizedBox(height: 8),
              WeekdaySelector(
                key: const Key('schedule-weekday-selector'),
                selectedDay: _selectedDay,
                dayKeyPrefix: 'schedule-day',
                onChanged: (day) {
                  setState(() => _selectedDay = day);
                },
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.tr('Room')} $_selectedRoomNumber',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _days[_selectedDay],
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('add-schedule-button'),
                    onPressed:
                        _selectedRoomNumber.isEmpty ? null : _openEditor,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.tr('Add Class')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.controller.isLoading && !widget.controller.hasLoaded)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (schedules.isEmpty)
                _EmptyManagementCard(
                  roomNumber: _selectedRoomNumber,
                  day: _days[_selectedDay],
                )
              else
                ...schedules.map(
                  (schedule) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ManagementScheduleCard(
                      schedule: schedule,
                      onEdit: () => _openEditor(schedule),
                      onDelete: () => _confirmDelete(schedule),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-schedule-fab'),
        tooltip: context.tr('Add Class'),
        onPressed: _selectedRoomNumber.isEmpty ? null : _openEditor,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ManagementScheduleCard extends StatelessWidget {
  const _ManagementScheduleCard({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  final ClassSchedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: colors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.subjectName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${schedule.startTime} - ${schedule.endTime}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (schedule.section.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    schedule.section,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
                if (schedule.instructor.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 13,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          schedule.instructor,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 10.5,
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
          IconButton(
            key: Key('edit-schedule-${schedule.id}'),
            tooltip: context.tr('Edit'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            key: Key('delete-schedule-${schedule.id}'),
            tooltip: context.tr('Delete'),
            onPressed: onDelete,
            color: colors.error,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyManagementCard extends StatelessWidget {
  const _EmptyManagementCard({required this.roomNumber, required this.day});

  final String roomNumber;
  final String day;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            color: colors.onSurfaceVariant,
            size: 34,
          ),
          const SizedBox(height: 9),
          Text(
            context.tr('No classes have been added yet.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('Add the first class for Room $roomNumber on $day.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEditorSheet extends StatefulWidget {
  const _ScheduleEditorSheet({
    required this.controller,
    required this.roomNumber,
    required this.dayOfWeek,
    this.schedule,
  });

  final ScheduleController controller;
  final String roomNumber;
  final int dayOfWeek;
  final ClassSchedule? schedule;

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  late final TextEditingController _subjectController;
  late final TextEditingController _sectionController;
  late final TextEditingController _instructorController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isSaving = false;
  String? _errorMessage;

  static const _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController(
      text: widget.schedule?.subjectName ?? '',
    );
    _sectionController = TextEditingController(
      text: widget.schedule?.section ?? '',
    );
    _instructorController = TextEditingController(
      text: widget.schedule?.instructor ?? '',
    );
    _startTime = _parseTime(widget.schedule?.startTime ?? '08:00');
    _endTime = _parseTime(widget.schedule?.endTime ?? '09:00');
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _sectionController.dispose();
    _instructorController.dispose();
    super.dispose();
  }

  Future<void> _selectTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startTime = selected;
      } else {
        _endTime = selected;
      }
      _errorMessage = null;
    });
  }

  Future<void> _save() async {
    final subject = _subjectController.text.trim();
    final section = _sectionController.text.trim();
    final instructor = _instructorController.text.trim();
    final startTime = _format24Hour(_startTime);
    final endTime = _format24Hour(_endTime);

    if (subject.isEmpty) {
      setState(
        () => _errorMessage = context.tr('Please enter a subject name.'),
      );
      return;
    }
    if (subject.length > 150) {
      setState(
        () => _errorMessage = context.tr(
          'The subject name must not exceed 150 characters.',
        ),
      );
      return;
    }
    if (section.length > 80) {
      setState(
        () => _errorMessage =
            context.tr('The section must not exceed 80 characters.'),
      );
      return;
    }
    if (instructor.length > 150) {
      setState(
        () => _errorMessage =
            context.tr('The instructor name must not exceed 150 characters.'),
      );
      return;
    }
    if (startTime.compareTo(endTime) >= 0) {
      setState(
        () => _errorMessage = context.tr('End time must be after start time.'),
      );
      return;
    }
    if (widget.controller.overlaps(
      roomNumber: widget.roomNumber,
      dayOfWeek: widget.dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      ignoredId: widget.schedule?.id,
    )) {
      setState(
        () =>
            _errorMessage = context.tr('This time overlaps an existing class.'),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final schedule = ClassSchedule(
      id: widget.schedule?.id ?? '',
      roomNumber: widget.roomNumber,
      dayOfWeek: widget.dayOfWeek,
      subjectName: subject,
      section: section,
      instructor: instructor,
      startTime: startTime,
      endTime: endTime,
    );

    try {
      if (widget.schedule == null) {
        await widget.controller.createSchedule(schedule);
      } else {
        await widget.controller.updateSchedule(schedule);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = context.tr(error.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.schedule == null
                  ? 'Add Class Schedule'
                  : 'Edit Class Schedule',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              context.tr(
                'Room ${widget.roomNumber} · ${_days[widget.dayOfWeek]}',
              ),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('schedule-subject-field'),
              controller: _subjectController,
              autofocus: widget.schedule == null,
              maxLength: 150,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('Subject name'),
                hintText: context.tr('e.g. Computer Network'),
                prefixIcon: const Icon(Icons.menu_book_rounded),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('schedule-section-field'),
              controller: _sectionController,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: context.tr('Section'),
                hintText: context.tr('e.g. (T) 68346CPE'),
                prefixIcon: const Icon(Icons.groups_rounded),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('schedule-instructor-field'),
              controller: _instructorController,
              maxLength: 150,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.tr('Instructor'),
                hintText: context.tr('e.g. Dr. or lecturer name'),
                prefixIcon: const Icon(Icons.person_rounded),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    key: const Key('schedule-start-time'),
                    label: context.tr('Start time'),
                    value: MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(_startTime),
                    onTap: () => _selectTime(start: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    key: const Key('schedule-end-time'),
                    label: context.tr('End time'),
                    value: MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(_endTime),
                    onTap: () => _selectTime(start: false),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('save-schedule-button'),
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  widget.schedule == null ? 'Add Class' : 'Save Changes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  static String _format24Hour(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.tr(label),
          prefixIcon: const Icon(Icons.schedule_rounded),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
