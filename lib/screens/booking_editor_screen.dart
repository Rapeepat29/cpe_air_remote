import '../localization/localized_material.dart';

import '../controllers/schedule_controller.dart';
import '../models/class_schedule.dart';
import '../models/room.dart';
import '../models/room_calendar.dart';
import '../utils/thai_date.dart';

/// ผลของฟอร์ม: บันทึกเป็นการใช้ห้อง หรือเป็นคาบในตารางเรียน
enum BookingEditorResult { booking, timetable }

/// เปิดฟอร์ม "เพิ่ม/แก้ไขการใช้ห้อง" แบบเต็มจอ
///
/// เหมือนฟอร์มของเว็บแอป (`webapp/assets/js/views/booking-form.js`):
/// ประชุม สอบ กิจกรรม หรือคาบเรียน ทำซ้ำได้สี่แบบ
///   วันเดียว / ทุกวันในช่วงวันที่ / ทุกสัปดาห์ (เลือกวัน) / ในตารางเรียนภาคนี้
/// ระหว่างเวลาที่ใช้ห้อง ระบบปิดแอร์ถือว่าห้องอยู่ในคาบ (รอ 15 นาที ไม่แจ้งเตือน)
Future<BookingEditorResult?> showBookingEditor(
  BuildContext context, {
  required ScheduleController controller,
  required List<Room> rooms,
  required String date,
  RoomBooking? booking,
  String roomNumber = '',
}) {
  return Navigator.of(context).push<BookingEditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BookingEditorScreen(
        controller: controller,
        rooms: rooms,
        date: date,
        booking: booking,
        roomNumber: roomNumber,
      ),
    ),
  );
}

/// ข้อความตามภาษาที่เลือก ใช้กับข้อความใหม่ของหน้านี้
String l10n(BuildContext context, String thai, String english) =>
    AppLocalizations.of(context).isThai ? thai : english;

/// วันแบบย่อ 0 = อาทิตย์
const _thaiDayShort = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
const _englishDayShort = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
const thaiDayNames = [
  'อาทิตย์',
  'จันทร์',
  'อังคาร',
  'พุธ',
  'พฤหัสบดี',
  'ศุกร์',
  'เสาร์',
];
const englishDayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// วันที่แบบสั้นสำหรับแสดงผล เช่น `9 ต.ค. 2569`
String shortIsoDate(String iso, bool isThai) {
  if (iso.isEmpty) return '—';
  return formatDisplayDate(dateOfIso(iso), isThai);
}

/// ข้อความสั้นอธิบายการทำซ้ำ เช่น "ทุกวันพุธ · 7 ต.ค. – 31 ธ.ค."
String describeBookingRepeat(RoomBooking booking, bool isThai) {
  final start = shortIsoDate(booking.startDate, isThai);
  final end = shortIsoDate(booking.endDate, isThai);
  switch (booking.repeat) {
    case BookingRepeat.once:
      return isThai ? 'วันเดียว · $start' : 'Once · $start';
    case BookingRepeat.daily:
      return isThai ? 'ทุกวัน · $start – $end' : 'Daily · $start – $end';
    case BookingRepeat.weekly:
      final names = isThai ? thaiDayNames : englishDayNames;
      final days = booking.daysOfWeek.map((day) => names[day]).join(' ');
      return isThai ? 'ทุกวัน$days · $start – $end' : 'Every $days · $start – $end';
  }
}

enum _Repeat { once, daily, weekly, timetable }

class BookingEditorScreen extends StatefulWidget {
  const BookingEditorScreen({
    required this.controller,
    required this.rooms,
    required this.date,
    this.booking,
    this.roomNumber = '',
    super.key,
  });

  final ScheduleController controller;
  final List<Room> rooms;

  /// วันที่ตั้งต้น `yyyy-MM-dd` (วันที่กำลังดูอยู่)
  final String date;
  final RoomBooking? booking;
  final String roomNumber;

  @override
  State<BookingEditorScreen> createState() => _BookingEditorScreenState();
}

class _BookingEditorScreenState extends State<BookingEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late String _roomNumber;
  late String _category;
  late _Repeat _repeat;
  late String _startDate;
  late String _endDate;
  late String _startTime;
  late String _endTime;
  late Set<int> _days;
  String? _error;
  bool _busy = false;

  bool get _editing => widget.booking != null;

  /// เพิ่มเป็นคาบในตารางเรียนได้เฉพาะตอนเพิ่มใหม่ และ Backend รุ่นที่รู้จักภาคเรียน
  bool get _canUseTimetable => !_editing && widget.controller.supportsReplaceAll;

  @override
  void initState() {
    super.initState();
    final booking = widget.booking;
    final date = widget.date;
    _title = TextEditingController(text: booking?.title ?? '');
    _note = TextEditingController(text: booking?.note ?? '');
    final rooms = widget.rooms.map((room) => room.number).toSet();
    final initialRoom = booking?.roomNumber ?? widget.roomNumber;
    _roomNumber = rooms.contains(initialRoom) ? initialRoom : '';
    _category = booking?.category ?? 'meeting';
    _repeat = switch (booking?.repeat) {
      BookingRepeat.daily => _Repeat.daily,
      BookingRepeat.weekly => _Repeat.weekly,
      _ => _Repeat.once,
    };
    _startDate = booking?.startDate ?? date;
    _endDate =
        booking?.endDate ?? addDaysIso(date, 6 - dayOfWeekOfIso(date));
    _startTime = booking?.startTime ?? '13:00';
    _endTime = booking?.endTime ?? '15:00';
    _days = booking != null && booking.daysOfWeek.isNotEmpty
        ? booking.daysOfWeek.toSet()
        : {dayOfWeekOfIso(date)};
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  AcademicTerm? get _term => widget.controller.activeTimetableTerm;

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _startTime : _endTime;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 13,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      ),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final text = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (start) {
        _startTime = text;
      } else {
        _endTime = text;
      }
      _error = null;
    });
  }

  Future<void> _pickDate({required bool start}) async {
    final current = dateOfIso(start ? _startDate : _endDate);
    final first = DateTime.now().subtract(const Duration(days: 365));
    final picked = await showAppDatePicker(
      context: context,
      initialDate: current.isBefore(first) ? first : current,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final iso = isoDateOf(picked);
      if (start) {
        _startDate = iso;
        if (_endDate.compareTo(_startDate) < 0) _endDate = _startDate;
      } else {
        _endDate = iso;
      }
      _error = null;
    });
  }

  void _setRepeat(_Repeat value) {
    setState(() {
      _repeat = value;
      if (value == _Repeat.weekly && _endDate.compareTo(_startDate) <= 0) {
        final term = _term;
        _endDate = term != null && term.endDate.compareTo(_startDate) > 0
            ? term.endDate
            : addDaysIso(_startDate, 27);
      }
      _error = null;
    });
  }

  void _setCategory(String value) {
    setState(() {
      _category = value;
      // "ในตารางเรียน" เหมาะกับคาบเรียนประจำเท่านั้น
      if (_repeat == _Repeat.timetable && value != 'class') {
        _repeat = _Repeat.weekly;
      }
    });
  }

  BookingRepeat get _bookingRepeat => switch (_repeat) {
    _Repeat.daily => BookingRepeat.daily,
    _Repeat.weekly => BookingRepeat.weekly,
    _ => BookingRepeat.once,
  };

  int get _occurrences => countBookingOccurrences(
    repeat: _bookingRepeat,
    startDate: _startDate,
    endDate: _repeat == _Repeat.once ? _startDate : _endDate,
    daysOfWeek: _days.toList(),
  );

  String _summary(bool isThai) {
    final time = '$_startTime–$_endTime';
    final names = isThai ? thaiDayNames : englishDayNames;
    final days = (_days.toList()..sort()).map((day) => names[day]).join(' ');
    if (_repeat == _Repeat.timetable) {
      if (_days.isEmpty) {
        return isThai
            ? 'เลือกวันในสัปดาห์อย่างน้อยหนึ่งวัน'
            : 'Choose at least one weekday';
      }
      final semester = widget.controller.timetable?.semester ?? '';
      return isThai
          ? 'ทุกวัน$days $time · ในตารางเรียน'
                '${semester.isEmpty ? '' : ' ภาคเรียน $semester'}'
          : 'Every $days $time · in the timetable'
                '${semester.isEmpty ? '' : ' (semester $semester)'}';
    }
    final count = _occurrences;
    if (count == 0) {
      if (_repeat == _Repeat.weekly && _days.isEmpty) {
        return isThai
            ? 'เลือกวันในสัปดาห์อย่างน้อยหนึ่งวัน'
            : 'Choose at least one weekday';
      }
      return isThai
          ? 'ช่วงวันที่ไม่มีวันที่ตรงกับที่เลือก'
          : 'No dates in this range match the chosen days';
    }
    final preview = RoomBooking(
      id: '',
      roomNumber: _roomNumber,
      title: '',
      category: _category,
      repeat: _bookingRepeat,
      daysOfWeek: _days.toList()..sort(),
      startDate: _startDate,
      endDate: _repeat == _Repeat.once ? _startDate : _endDate,
      startTime: _startTime,
      endTime: _endTime,
    );
    return isThai
        ? '${describeBookingRepeat(preview, true)} · $time · รวม $count ครั้ง'
        : '${describeBookingRepeat(preview, false)} · $time · $count times';
  }

  Future<void> _save() async {
    final isThai = AppLocalizations.of(context).isThai;
    String? fail;
    if (_roomNumber.isEmpty) {
      fail = isThai ? 'กรุณาเลือกห้อง' : 'Please choose a room.';
    } else if (_title.text.trim().isEmpty) {
      fail = isThai
          ? 'กรุณากรอกชื่อการใช้ห้อง'
          : 'Please enter what the room is used for.';
    } else if (_endTime.compareTo(_startTime) <= 0) {
      fail = isThai
          ? 'เวลาสิ้นสุดต้องหลังเวลาเริ่ม'
          : 'End time must be after start time.';
    } else if ((_repeat == _Repeat.weekly || _repeat == _Repeat.timetable) &&
        _days.isEmpty) {
      fail = isThai
          ? 'กรุณาเลือกวันในสัปดาห์อย่างน้อยหนึ่งวัน'
          : 'Please choose at least one weekday.';
    } else if (_repeat != _Repeat.timetable &&
        _repeat != _Repeat.once &&
        _endDate.compareTo(_startDate) < 0) {
      fail = isThai
          ? 'วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่ม'
          : 'The end date must not be before the start date.';
    } else if (_repeat != _Repeat.timetable && _occurrences == 0) {
      fail = isThai
          ? 'ในช่วงวันที่ที่เลือกไม่มีวันที่ตรงกับวันในสัปดาห์ที่เลือกเลย'
          : 'No dates in this range match the chosen weekdays.';
    } else if (_repeat == _Repeat.timetable) {
      for (final day in _days) {
        if (widget.controller.overlaps(
          roomNumber: _roomNumber,
          dayOfWeek: day,
          startTime: _startTime,
          endTime: _endTime,
        )) {
          fail = isThai
              ? 'เวลานี้ทับคาบเรียนเดิมในวัน${thaiDayNames[day]}'
              : 'This time overlaps an existing class on ${englishDayNames[day]}.';
          break;
        }
      }
    }
    if (fail != null) {
      setState(() => _error = fail);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_repeat == _Repeat.timetable) {
        // คาบเรียนประจำ: หนึ่งแถวต่อหนึ่งวัน ผ่าน API ตารางเรียนเดิม
        for (final day in _days.toList()..sort()) {
          await widget.controller.createSchedule(
            ClassSchedule(
              id: '',
              roomNumber: _roomNumber,
              dayOfWeek: day,
              subjectName: _title.text.trim(),
              section: _note.text.trim(),
              startTime: _startTime,
              endTime: _endTime,
            ),
          );
        }
        if (!mounted) return;
        Navigator.of(context).pop(BookingEditorResult.timetable);
        return;
      }

      final booking = RoomBooking(
        id: widget.booking?.id ?? '',
        roomNumber: _roomNumber,
        title: _title.text.trim(),
        category: _category,
        note: _note.text.trim(),
        repeat: _bookingRepeat,
        daysOfWeek: _days.toList()..sort(),
        startDate: _startDate,
        endDate: _repeat == _Repeat.once ? _startDate : _endDate,
        startTime: _startTime,
        endTime: _endTime,
      );
      if (_editing) {
        await widget.controller.updateBooking(booking);
      } else {
        await widget.controller.createBooking(booking);
      }
      if (!mounted) return;
      Navigator.of(context).pop(BookingEditorResult.booking);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = context.tr(error.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isThai = AppLocalizations.of(context).isThai;
    final rooms = [...widget.rooms]
      ..sort((a, b) {
        final floor = a.floor.compareTo(b.floor);
        return floor != 0 ? floor : a.number.compareTo(b.number);
      });

    final repeats = <(_Repeat, String, String)>[
      (
        _Repeat.once,
        l10n(context, 'วันเดียว', 'Once'),
        l10n(context, 'ใช้ห้องครั้งเดียว', 'A single day'),
      ),
      (
        _Repeat.daily,
        l10n(context, 'ทุกวัน', 'Daily'),
        l10n(context, 'ทุกวันในช่วงวันที่ เช่น ทั้งสัปดาห์นี้', 'Every day in a date range'),
      ),
      (
        _Repeat.weekly,
        l10n(context, 'ทุกสัปดาห์', 'Weekly'),
        l10n(context, 'วันเดิมของทุกสัปดาห์ เช่น ทุกวันพุธ', 'Same weekdays every week'),
      ),
      if (_canUseTimetable && _category == 'class')
        (
          _Repeat.timetable,
          l10n(context, 'ในตารางเรียน', 'In the timetable'),
          l10n(
            context,
            'ทุกสัปดาห์ตลอดภาคเรียน · เพิ่มเป็นคาบในตารางเรียน',
            'Every week for the whole semester · added as a class',
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? l10n(context, 'แก้ไขการใช้ห้อง', 'Edit room use')
              : l10n(context, 'เพิ่มการใช้ห้อง', 'Add room use'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Text(
              l10n(
                context,
                'ระหว่างเวลาที่ใช้ห้อง ระบบจะถือว่าห้องอยู่ในคาบ: ห้องว่างจะรอ 15 นาทีก่อนปิดแอร์ '
                    'และไม่แจ้งเตือนว่าใช้แอร์นอกคาบ',
                'While the room is in use the system treats it as in class: an empty '
                    'room waits 15 minutes before the AC is turned off, with no '
                    'out-of-class alert.',
              ),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('booking-room-field'),
              initialValue: _roomNumber.isEmpty ? null : _roomNumber,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n(context, 'ห้อง', 'Room'),
                prefixIcon: const Icon(Icons.meeting_room_rounded),
              ),
              items: [
                for (final room in rooms)
                  DropdownMenuItem(
                    value: room.number,
                    child: Text(
                      '${room.number} · ${room.type}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _roomNumber = value ?? ''),
            ),
            const SizedBox(height: 14),
            _Label(l10n(context, 'ประเภท', 'Type')),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final category in bookingCategories)
                  ChoiceChip(
                    key: Key('booking-category-$category'),
                    label: Text(bookingCategoryLabel(category, isThai)),
                    selected: _category == category,
                    onSelected: _busy ? null : (_) => _setCategory(category),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('booking-title-field'),
              controller: _title,
              maxLength: 100,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n(context, 'ใช้ห้องเพื่อ', 'Used for'),
                hintText: l10n(
                  context,
                  'เช่น ประชุมภาควิชา, สอบกลางภาค',
                  'e.g. Department meeting, Midterm exam',
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('booking-note-field'),
              controller: _note,
              maxLength: 255,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n(context, 'รายละเอียด', 'Details'),
                hintText: l10n(
                  context,
                  'ผู้รับผิดชอบ / อาจารย์ / กลุ่มเรียน (ไม่ใส่ก็ได้)',
                  'Organizer / lecturer / section (optional)',
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    key: const Key('booking-start-time'),
                    label: l10n(context, 'เวลาเริ่ม', 'Start time'),
                    value: _startTime,
                    icon: Icons.schedule_rounded,
                    onTap: _busy ? null : () => _pickTime(start: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerField(
                    key: const Key('booking-end-time'),
                    label: l10n(context, 'เวลาสิ้นสุด', 'End time'),
                    value: _endTime,
                    icon: Icons.schedule_rounded,
                    onTap: _busy ? null : () => _pickTime(start: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Label(l10n(context, 'ทำซ้ำ', 'Repeat')),
            RadioGroup<_Repeat>(
              groupValue: _repeat,
              onChanged: (value) {
                if (value == null || _busy) return;
                _setRepeat(value);
              },
              child: Column(
                children: [
                  for (final (value, title, hint) in repeats)
                    RadioListTile<_Repeat>(
                      key: Key('booking-repeat-${value.name}'),
                      value: value,
                      enabled: !_busy,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(hint),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ..._repeatDetail(context, isThai),
            const SizedBox(height: 14),
            Container(
              key: const Key('booking-summary'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _summary(isThai),
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: colors.error, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('booking-save-button'),
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                _editing
                    ? l10n(context, 'บันทึกการแก้ไข', 'Save changes')
                    : l10n(context, 'เพิ่มการใช้ห้อง', 'Add room use'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _repeatDetail(BuildContext context, bool isThai) {
    final dayPicker = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var day = 0; day < 7; day++)
          FilterChip(
            key: Key('booking-day-$day'),
            label: Text((isThai ? _thaiDayShort : _englishDayShort)[day]),
            selected: _days.contains(day),
            onSelected: _busy
                ? null
                : (on) => setState(() {
                    if (on) {
                      _days.add(day);
                    } else {
                      _days.remove(day);
                    }
                  }),
          ),
      ],
    );

    Widget quick(String label, String endDate) => ActionChip(
      label: Text(label),
      onPressed: _busy ? null : () => setState(() => _endDate = endDate),
    );

    switch (_repeat) {
      case _Repeat.once:
        return [
          _PickerField(
            key: const Key('booking-start-date'),
            label: l10n(context, 'วันที่', 'Date'),
            value: shortIsoDate(_startDate, isThai),
            icon: Icons.event_rounded,
            onTap: _busy ? null : () => _pickDate(start: true),
          ),
        ];
      case _Repeat.timetable:
        final term = _term;
        return [
          _Label(l10n(context, 'วันในสัปดาห์', 'Weekdays')),
          dayPicker,
          const SizedBox(height: 8),
          Text(
            term != null
                ? l10n(
                    context,
                    'มีผลทุกสัปดาห์ระหว่างวันเปิด–ปิดภาค '
                        '${shortIsoDate(term.startDate, true)} – ${shortIsoDate(term.endDate, true)}',
                    'Applies every week between '
                        '${shortIsoDate(term.startDate, false)} and ${shortIsoDate(term.endDate, false)}',
                  )
                : l10n(
                    context,
                    'มีผลทุกสัปดาห์ จนกว่าจะเปลี่ยนตารางเรียน (ตั้งวันเปิด–ปิดภาคได้ที่ปฏิทินภาคเรียน)',
                    'Applies every week until the timetable changes '
                        '(set semester dates in the term calendar)',
                  ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ];
      case _Repeat.daily:
      case _Repeat.weekly:
        final term = _term;
        return [
          if (_repeat == _Repeat.weekly) ...[
            _Label(l10n(context, 'วันในสัปดาห์', 'Weekdays')),
            dayPicker,
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _PickerField(
                  key: const Key('booking-start-date'),
                  label: l10n(context, 'ตั้งแต่วันที่', 'From'),
                  value: shortIsoDate(_startDate, isThai),
                  icon: Icons.event_rounded,
                  onTap: _busy ? null : () => _pickDate(start: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerField(
                  key: const Key('booking-end-date'),
                  label: l10n(context, 'ถึงวันที่', 'Until'),
                  value: shortIsoDate(_endDate, isThai),
                  icon: Icons.event_rounded,
                  onTap: _busy ? null : () => _pickDate(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n(context, 'สิ้นสุดเร็ว:', 'Quick end:'),
                style: const TextStyle(fontSize: 12),
              ),
              if (_repeat == _Repeat.daily) ...[
                quick(
                  l10n(context, 'ถึงสิ้นสัปดาห์นี้', 'End of this week'),
                  addDaysIso(_startDate, 6 - dayOfWeekOfIso(_startDate)),
                ),
                quick(
                  l10n(context, '5 วัน', '5 days'),
                  addDaysIso(_startDate, 4),
                ),
              ] else ...[
                if (term != null && term.endDate.compareTo(_startDate) > 0)
                  quick(
                    l10n(
                      context,
                      'ถึงวันปิดภาค (${shortIsoDate(term.endDate, true)})',
                      'Until term end (${shortIsoDate(term.endDate, false)})',
                    ),
                    term.endDate,
                  ),
                quick(
                  l10n(context, '4 สัปดาห์', '4 weeks'),
                  addDaysIso(_startDate, 27),
                ),
                quick(
                  l10n(context, '3 เดือน', '3 months'),
                  addDaysIso(_startDate, 90),
                ),
              ],
            ],
          ),
        ];
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// ช่องที่แตะแล้วเปิดตัวเลือก (เวลา/วันที่)
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
