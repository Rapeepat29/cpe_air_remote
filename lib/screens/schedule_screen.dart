import 'dart:convert';
import 'dart:typed_data';

import '../localization/localized_material.dart';

import '../controllers/schedule_controller.dart';
import '../models/class_schedule.dart';
import '../models/room.dart';
import '../models/room_calendar.dart';
import '../theme/app_theme.dart';
import '../utils/file_saver.dart';
import '../widgets/floor_selector.dart';
import '../widgets/section_title.dart';
import '../widgets/status_pill.dart';
import 'booking_editor_screen.dart';
import 'schedule_management_screen.dart';
import 'term_calendar_screen.dart';

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

/// หน้าตารางเรียนและการใช้ห้อง ดูเป็นรายวันตามวันที่จริง เลื่อนทีละสัปดาห์ได้
///
/// นอกจากคาบเรียนประจำ ยังมีการใช้ห้องที่มีวันที่กำกับ (ประชุม สอบ กิจกรรม)
/// และวันเปิด–ปิดภาคเรียน วันเดียวกันในสัปดาห์คนละสัปดาห์จึงอาจมีรายการไม่เหมือนกัน
/// (เหมือนเว็บแอป webapp/assets/js/views/schedule.js)
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
  /// วันที่ที่กำลังดู `yyyy-MM-dd` (null = วันนี้)
  String? _selectedDate;
  int _selectedFloor = 3;

  String get _today => widget.controller.today;
  String get _date => _selectedDate ?? _today;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeek());
  }

  Future<void> _loadWeek() async {
    if (!mounted) return;
    final start = weekStartIso(_date);
    await widget.controller.loadBookings(from: start, to: addDaysIso(start, 6));
  }

  void _selectDate(String date) {
    final before = weekStartIso(_date);
    setState(() => _selectedDate = date);
    if (weekStartIso(date) != before) _loadWeek();
  }

  Future<void> _refresh() async {
    await widget.controller.reload();
    final start = weekStartIso(_date);
    await widget.controller.loadBookings(
      from: start,
      to: addDaysIso(start, 6),
      force: true,
    );
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
                initialDay: dayOfWeekOfIso(_date),
                onRoomsChanged: widget.onRoomsChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTermCalendar() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TermCalendarScreen(
          controller: widget.controller,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  Future<void> _addBooking([String roomNumber = '']) async {
    final result = await showBookingEditor(
      context,
      controller: widget.controller,
      rooms: widget.rooms,
      date: _date,
      roomNumber: roomNumber,
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == BookingEditorResult.timetable
              ? l10n(context, 'เพิ่มคาบเรียนในตารางแล้ว', 'Class added to the timetable.')
              : l10n(context, 'เพิ่มการใช้ห้องแล้ว', 'Room use added.'),
        ),
      ),
    );
  }

  Future<void> _bookingActions(RoomBooking booking) async {
    final isThai = AppLocalizations.of(context).isThai;
    final date = _date;
    final repeating = booking.repeat != BookingRepeat.once;
    final canStop = repeating && date.compareTo(booking.startDate) > 0;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                booking.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${context.tr('Room')} ${booking.roomNumber} · '
                '${booking.startTime}-${booking.endTime}\n'
                '${describeBookingRepeat(booking, isThai)}',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('booking-action-edit'),
              leading: const Icon(Icons.edit_rounded),
              title: Text(context.tr('Edit')),
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
            if (canStop)
              ListTile(
                key: const Key('booking-action-stop'),
                leading: const Icon(Icons.event_busy_rounded),
                title: Text(
                  l10n(
                    context,
                    'หยุดตั้งแต่ ${shortIsoDate(date, true)}',
                    'Stop from ${shortIsoDate(date, false)}',
                  ),
                ),
                subtitle: Text(
                  l10n(context, 'เก็บครั้งก่อนหน้าไว้', 'Keeps the earlier dates'),
                ),
                onTap: () => Navigator.of(sheetContext).pop('stop'),
              ),
            ListTile(
              key: const Key('booking-action-delete'),
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                repeating
                    ? l10n(context, 'ลบทั้งชุด', 'Delete the whole series')
                    : context.tr('Delete'),
                style: TextStyle(color: Theme.of(sheetContext).colorScheme.error),
              ),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'edit') {
      final result = await showBookingEditor(
        context,
        controller: widget.controller,
        rooms: widget.rooms,
        date: date,
        booking: booking,
      );
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n(context, 'บันทึกการแก้ไขแล้ว', 'Changes saved.'))),
        );
      }
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      if (action == 'stop') {
        await widget.controller.updateBooking(
          booking.copyWith(endDate: addDaysIso(date, -1)),
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n(
                context,
                'หยุด "${booking.title}" ตั้งแต่ ${shortIsoDate(date, true)} แล้ว',
                'Stopped "${booking.title}" from ${shortIsoDate(date, false)}.',
              ),
            ),
          ),
        );
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              l10n(context, 'ลบ "${booking.title}"?', 'Delete "${booking.title}"?'),
            ),
            content: Text(describeBookingRepeat(booking, isThai)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.tr('Delete')),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await widget.controller.deleteBooking(booking.id);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n(context, 'ลบแล้ว', 'Deleted.'))),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(context.tr(error.toString()))));
    }
  }

  Future<void> _downloadCsv() async {
    final controller = widget.controller;
    final semester = controller.timetable?.semester ?? '';
    final label = semester.isEmpty ? 'current' : semester.replaceAll('/', '-');
    final csv = schedulesToCsv(controller.schedules, semester);
    final result = await saveExportFile(
      fileName: 'rmutt-timetable-$label-$_today.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileExtension: 'csv',
      mimeType: 'text/csv',
      typeLabel: 'CSV',
    );
    if (!mounted) return;
    if (result.status == FileSaveStatus.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(result.error ?? 'Error'))),
      );
    } else if (result.status == FileSaveStatus.saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('CSV file saved.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final date = _date;
          return Column(
            children: [
              _ScheduleHeader(
                canManage: widget.isAdmin,
                onManage: _openManager,
                onAddBooking: () => _addBooking(),
                selectedDate: dateOfIso(date),
                isToday: date == _today,
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
    final isThai = AppLocalizations.of(context).isThai;

    if (controller.isLoading && !controller.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null && !controller.hasLoaded) {
      return _ScheduleLoadError(
        message: controller.errorMessage!,
        onRetry: controller.reload,
      );
    }

    final date = _date;
    final today = _today;
    final floors = widget.rooms.map((room) => room.floor).toSet().toList()
      ..sort();
    if (floors.isNotEmpty && !floors.contains(_selectedFloor)) {
      _selectedFloor = floors.first;
    }
    final floorRooms = widget.rooms
        .where((room) => room.floor == _selectedFloor)
        .toList();
    bool hasEntries(Room room) =>
        controller.classesOn(room.number, date).isNotEmpty ||
        controller.bookingsOn(room.number, date).isNotEmpty;
    final scheduledRooms = floorRooms.where(hasEntries).toList();
    final otherRooms = floorRooms
        .where((room) => !scheduledRooms.contains(room))
        .toList();
    final term = controller.activeTimetableTerm;
    final outsideTerm = controller.isOutsideTerm(date);
    final now = TimeOfDay.now();
    final nowText = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          if (controller.schedules.isNotEmpty || controller.timetable != null) ...[
            _TimetableInfoCard(
              controller: controller,
              isAdmin: widget.isAdmin,
              onOpenTerms: _openTermCalendar,
              onSetDates: (semester) => editAcademicTerm(
                context,
                controller,
                presetSemester: semester,
              ),
              onDownloadCsv: _downloadCsv,
            ),
            const SizedBox(height: 12),
          ] else ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('open-term-calendar'),
                onPressed: _openTermCalendar,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(l10n(context, 'ปฏิทินภาคเรียน', 'Term calendar')),
              ),
            ),
          ],
          _WeekNavigator(
            date: date,
            today: today,
            isThai: isThai,
            onSelect: _selectDate,
          ),
          const SizedBox(height: 12),
          FloorSelector(
            selectedFloor: _selectedFloor,
            floors: floors,
            onChanged: (floor) {
              setState(() => _selectedFloor = floor);
            },
          ),
          if (outsideTerm && term != null) ...[
            const SizedBox(height: 12),
            _NoteBox(
              icon: Icons.beach_access_rounded,
              color: AppColors.orange,
              text: l10n(
                context,
                'วันที่นี้อยู่นอกภาคเรียน ${term.semester} '
                    '(${shortIsoDate(term.startDate, true)} – ${shortIsoDate(term.endDate, true)}) '
                    'ตารางเรียนไม่มีผล ห้องที่ไม่มีการใช้ห้องอื่นถือว่าว่าง',
                'This date is outside semester ${term.semester} '
                    '(${shortIsoDate(term.startDate, false)} – ${shortIsoDate(term.endDate, false)}). '
                    'The timetable does not apply; rooms without other bookings count as empty.',
              ),
            ),
          ],
          if (controller.calendarError != null) ...[
            const SizedBox(height: 12),
            _NoteBox(
              icon: Icons.cloud_off_rounded,
              color: AppColors.red,
              text: l10n(
                context,
                'โหลดการใช้ห้องหรือปฏิทินภาคเรียนไม่สำเร็จ ดึงหน้าจอลงเพื่อลองใหม่',
                'Could not load room bookings or the term calendar. Pull down to retry.',
              ),
            ),
          ],
          const SizedBox(height: 20),
          SectionTitle(title: context.tr('Classrooms (Scheduled Control)')),
          const SizedBox(height: 11),
          if (controller.bookingsLoading && scheduledRooms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (scheduledRooms.isEmpty)
            _EmptyScheduleCard(canManage: widget.isAdmin)
          else
            ...scheduledRooms.map(
              (room) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScheduleCard(
                  room: room,
                  schedules: controller.classesOn(room.number, date),
                  bookings: controller.bookingsOn(room.number, date),
                  nowText: date == today ? nowText : null,
                  isAdmin: widget.isAdmin,
                  isThai: isThai,
                  onTap: () => widget.onOpenRoom(room),
                  onAddBooking: () => _addBooking(room.number),
                  onBookingTap: _bookingActions,
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

/// เลื่อนทีละสัปดาห์ และเลือกวันในสัปดาห์ (อาทิตย์–เสาร์ พร้อมวันที่)
class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.date,
    required this.today,
    required this.isThai,
    required this.onSelect,
  });

  final String date;
  final String today;
  final bool isThai;
  final ValueChanged<String> onSelect;

  static const _thaiShort = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
  static const _englishShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final weekStart = weekStartIso(date);
    final weekEnd = addDaysIso(weekStart, 6);
    final thisWeek = weekStart == weekStartIso(today);
    final names = isThai ? _thaiShort : _englishShort;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('schedule-previous-week'),
                tooltip: l10n(context, 'สัปดาห์ก่อน', 'Previous week'),
                onPressed: () => onSelect(addDaysIso(date, -7)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${shortIsoDate(weekStart, isThai)} – ${shortIsoDate(weekEnd, isThai)}',
                      key: const Key('schedule-week-label'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      thisWeek
                          ? l10n(context, 'สัปดาห์นี้', 'This week')
                          : weekStart.compareTo(today) > 0
                          ? l10n(context, 'สัปดาห์ถัดไป', 'Upcoming week')
                          : l10n(context, 'สัปดาห์ที่ผ่านมา', 'Past week'),
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (date != today)
                TextButton(
                  key: const Key('schedule-go-today'),
                  onPressed: () => onSelect(today),
                  child: Text(context.tr('Today')),
                ),
              IconButton(
                key: const Key('schedule-next-week'),
                tooltip: l10n(context, 'สัปดาห์หน้า', 'Next week'),
                onPressed: () => onSelect(addDaysIso(date, 7)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: List.generate(7, (index) {
              final day = addDaysIso(weekStart, index);
              final selected = day == date;
              final isToday = day == today;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 6 ? 0 : 3),
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: '${names[index]} ${shortIsoDate(day, isThai)}',
                    child: InkWell(
                      key: Key('schedule-overview-day-$index'),
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => onSelect(day),
                      child: AnimatedContainer(
                        key: selected
                            ? Key('schedule-overview-day-selected-$index')
                            : null,
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? colors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          border: isToday && !selected
                              ? Border.all(color: colors.primary)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              names[index],
                              maxLines: 1,
                              style: TextStyle(
                                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${dateOfIso(day).day}',
                              style: TextStyle(
                                color: selected ? colors.onPrimary : colors.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// แถบบอกว่าตารางที่ใช้อยู่เป็นของภาคเรียนไหน และตอนนี้มีผลหรือไม่
///
/// ตารางแต่ละเทอมไม่เหมือนกัน ถ้าลืมเปลี่ยน ระบบปิดแอร์จะใช้คาบของเทอมเก่า
class _TimetableInfoCard extends StatelessWidget {
  const _TimetableInfoCard({
    required this.controller,
    required this.isAdmin,
    required this.onOpenTerms,
    required this.onSetDates,
    required this.onDownloadCsv,
  });

  final ScheduleController controller;
  final bool isAdmin;
  final VoidCallback onOpenTerms;
  final ValueChanged<String> onSetDates;
  final VoidCallback onDownloadCsv;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isThai = AppLocalizations.of(context).isThai;
    final schedules = controller.schedules;
    final info = controller.timetable;
    final semester = info?.semester ?? '';
    final roomCount = schedules.map((row) => row.roomNumber).toSet().length;
    final term = controller.termFor(semester);
    final today = controller.today;

    final details = <String>[
      isThai
          ? '${schedules.length} คาบ ใน $roomCount ห้อง'
          : '${schedules.length} classes in $roomCount rooms',
      if (info?.importedAt != null)
        isThai
            ? 'นำเข้าเมื่อ ${shortIsoDate(isoDateOf(info!.importedAt!.toLocal()), true)}'
                  '${info.importedBy != null ? ' โดย ${info.importedBy}' : ''}'
            : 'Imported ${shortIsoDate(isoDateOf(info!.importedAt!.toLocal()), false)}'
                  '${info.importedBy != null ? ' by ${info.importedBy}' : ''}',
    ];

    Widget statusLine;
    if (semester.isEmpty) {
      statusLine = Text(
        l10n(
          context,
          'ยังไม่ระบุภาคเรียน — นำเข้าจากไฟล์ครั้งถัดไประบบจะจำให้',
          'Semester not recorded yet — the next file import will set it.',
        ),
        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
      );
    } else if (term == null) {
      statusLine = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          StatusPill(
            label: l10n(context, 'ยังไม่ได้ตั้งวันเปิด–ปิดภาค', 'No semester dates'),
            color: AppColors.orange,
            backgroundColor: AppColors.orangeSoft,
          ),
          Text(
            l10n(context, 'ระบบใช้ตารางนี้ทุกวัน รวมช่วงปิดภาค', 'Used every day, including breaks'),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
          ),
          if (isAdmin)
            TextButton(
              key: const Key('set-term-dates'),
              onPressed: () => onSetDates(semester),
              child: Text(l10n(context, 'ตั้งวันเปิด–ปิด', 'Set dates')),
            ),
        ],
      );
    } else {
      final status = term.statusOn(today);
      final (label, color) = termStatusLabel(status, isThai);
      var text = '${shortIsoDate(term.startDate, isThai)} – ${shortIsoDate(term.endDate, isThai)}';
      if (status == TermStatus.active) {
        final left = daysBetweenIso(today, term.endDate);
        text += left == 0
            ? l10n(context, ' · วันนี้วันสุดท้าย', ' · last day today')
            : l10n(context, ' · อีก $left วันปิดภาค', ' · $left days left');
      } else if (status == TermStatus.before) {
        final wait = daysBetweenIso(today, term.startDate);
        text += l10n(
          context,
          ' · ทุกห้องถือว่าว่างจนถึงวันเปิดภาค (อีก $wait วัน)',
          ' · rooms count as empty until it starts ($wait days)',
        );
      } else if (status == TermStatus.after) {
        text += l10n(context, ' · ปิดภาคแล้ว ทุกห้องถือว่าว่าง', ' · ended, rooms count as empty');
      }
      statusLine = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          StatusPill(label: label, color: color, backgroundColor: color.withValues(alpha: 0.14)),
          Text(text, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5)),
        ],
      );
    }

    return Container(
      key: const Key('timetable-info-card'),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_chart_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  semester.isEmpty
                      ? l10n(context, 'ตารางเรียนที่ใช้อยู่', 'Current timetable')
                      : l10n(context, 'ตารางเรียนภาคเรียน $semester', 'Timetable · semester $semester'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            details.join(' · '),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
          ),
          const SizedBox(height: 6),
          statusLine,
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                key: const Key('open-term-calendar'),
                onPressed: onOpenTerms,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(l10n(context, 'ปฏิทินภาคเรียน', 'Term calendar')),
              ),
              if (schedules.isNotEmpty)
                TextButton.icon(
                  key: const Key('download-timetable-csv'),
                  onPressed: onDownloadCsv,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(l10n(context, 'ดาวน์โหลด CSV', 'Download CSV')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
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
    required this.onAddBooking,
    required this.selectedDate,
    required this.isToday,
  });

  final bool canManage;
  final VoidCallback onManage;
  final VoidCallback onAddBooking;
  final DateTime selectedDate;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final selectedDateLabel = _formatScheduleDate(context, selectedDate);
    final palette = AppPalette.of(context);

    return Container(
      height: 74,
      color: palette.bar,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (canManage)
            IconButton(
              key: const Key('add-booking-button'),
              tooltip: AppLocalizations.of(context).isThai
                  ? 'เพิ่มการใช้ห้อง (ประชุม สอบ กิจกรรม)'
                  : 'Add room use (meeting, exam, event)',
              onPressed: onAddBooking,
              icon: Icon(Icons.event_available_rounded, color: palette.onBar),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.tr('Room Schedule'),
                  style: TextStyle(
                    color: palette.onBar,
                    fontFamily: kDisplayFont,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
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
                      color: palette.onBar.withValues(alpha: 0.90),
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
              icon: Icon(
                Icons.edit_calendar_rounded,
                color: palette.onBar,
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
    required this.bookings,
    required this.nowText,
    required this.isAdmin,
    required this.isThai,
    required this.onTap,
    required this.onAddBooking,
    required this.onBookingTap,
  });

  final Room room;
  final List<ClassSchedule> schedules;
  final List<RoomBooking> bookings;

  /// เวลาตอนนี้ `HH:mm` ถ้ากำลังดูวันนี้ ใช้ไฮไลต์คาบที่กำลังเรียน
  final String? nowText;
  final bool isAdmin;
  final bool isThai;
  final VoidCallback onTap;
  final VoidCallback onAddBooking;
  final ValueChanged<RoomBooking> onBookingTap;

  bool _isNow(String start, String end) {
    final now = nowText;
    return now != null && now.compareTo(start) >= 0 && now.compareTo(end) < 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // คาบเรียนกับการใช้ห้องเรียงรวมกันตามเวลาเริ่ม
    final rows = <({String start, Widget child})>[
      for (final schedule in schedules)
        (
          start: schedule.startTime,
          child: _EntryRow(
            time: '${schedule.startTime} - ${schedule.endTime}',
            title: schedule.subjectName,
            lines: [
              if (schedule.section.isNotEmpty) schedule.section,
              if (schedule.instructor.isNotEmpty) schedule.instructor,
            ],
            isNow: _isNow(schedule.startTime, schedule.endTime),
          ),
        ),
      for (final booking in bookings)
        (
          start: booking.startTime,
          child: _EntryRow(
            key: Key('booking-row-${booking.id}'),
            time: '${booking.startTime} - ${booking.endTime}',
            title: booking.title,
            tag: bookingCategoryLabel(booking.category, isThai),
            lines: [
              if (booking.note.isNotEmpty) booking.note,
              describeBookingRepeat(booking, isThai),
            ],
            isNow: _isNow(booking.startTime, booking.endTime),
            onTap: isAdmin ? () => onBookingTap(booking) : null,
          ),
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 13),
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
                    label: isThai ? '${rows.length} รายการ' : '${rows.length} items',
                    color: colors.primary,
                    backgroundColor: colors.primaryContainer,
                  ),
                  if (isAdmin)
                    IconButton(
                      key: Key('add-booking-${room.number}'),
                      tooltip: isThai
                          ? 'เพิ่มการใช้ห้อง ${room.number}'
                          : 'Add room use for ${room.number}',
                      visualDensity: VisualDensity.compact,
                      onPressed: onAddBooking,
                      icon: Icon(Icons.add_circle_outline_rounded, color: colors.primary),
                    ),
                ],
              ),
              Divider(color: colors.outlineVariant, height: 16),
              ...rows.map((row) => row.child),
            ],
          ),
        ),
      ),
    );
  }
}

/// หนึ่งแถวในการ์ดห้อง: คาบเรียน หรือการใช้ห้อง (มีป้ายประเภท)
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.time,
    required this.title,
    required this.lines,
    required this.isNow,
    this.tag,
    this.onTap,
    super.key,
  });

  final String time;
  final String title;
  final List<String> lines;
  final bool isNow;
  final String? tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = tag != null ? AppColors.blue : colors.primary;
    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      decoration: BoxDecoration(
        color: isNow ? accent.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, color: accent, size: 6),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 88,
            child: Text(
              time,
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
                Text.rich(
                  TextSpan(
                    children: [
                      if (tag != null)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              tag!,
                              style: const TextStyle(
                                color: AppColors.blue,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      TextSpan(text: title),
                    ],
                  ),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final line in lines) ...[
                  const SizedBox(height: 1),
                  Text(
                    line,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.more_vert_rounded, size: 16, color: colors.onSurfaceVariant),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
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
