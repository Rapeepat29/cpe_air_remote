import '../localization/localized_material.dart';

/// วันที่ทั้งแอป: ภาษาไทยแสดงปี พ.ศ. ภาษาอังกฤษแสดงปี ค.ศ.
///
/// ค่าที่เก็บและส่งไป Backend ยังเป็น ค.ศ. เสมอ (DateTime / yyyy-MM-dd)
/// ไฟล์นี้แปลงแค่ตอนแสดงผลและตอนรับค่าที่ผู้ใช้พิมพ์

const _thaiMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];
const _thaiMonthsFull = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
const _englishMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _englishMonthsFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _thaiWeekdaysShort = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
const _englishWeekdaysShort = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

/// ผลต่างระหว่าง พ.ศ. กับ ค.ศ.
const buddhistEraOffset = 543;

String _two(int value) => value.toString().padLeft(2, '0');

/// ปีตามภาษา: ไทย = พ.ศ. อังกฤษ = ค.ศ.
int displayYear(DateTime date, bool isThai) =>
    isThai ? date.year + buddhistEraOffset : date.year;

/// เช่น `9 มิ.ย. 2569` / `9 Jun 2026`
String formatDisplayDate(DateTime date, bool isThai) {
  final months = isThai ? _thaiMonthsShort : _englishMonthsShort;
  return '${date.day} ${months[date.month - 1]} ${displayYear(date, isThai)}';
}

/// เช่น `9 มิ.ย. 2569 14:05`
String formatDisplayDateTime(DateTime value, bool isThai) {
  final local = value.toLocal();
  return '${formatDisplayDate(local, isThai)} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// เช่น `9 มิ.ย.` ใช้ในที่แคบที่ไม่ต้องมีปี
String formatDayMonth(DateTime date, bool isThai) {
  final months = isThai ? _thaiMonthsShort : _englishMonthsShort;
  return '${date.day} ${months[date.month - 1]}';
}

/// เช่น `มิถุนายน 2569`
String formatMonthYear(DateTime date, bool isThai) {
  final months = isThai ? _thaiMonthsFull : _englishMonthsFull;
  return '${months[date.month - 1]} ${displayYear(date, isThai)}';
}

/// ตัวเลขล้วนสำหรับช่องพิมพ์ เช่น `09/06/2569`
String formatNumericDate(DateTime date, bool isThai) {
  return '${_two(date.day)}/${_two(date.month)}/${displayYear(date, isThai)}';
}

/// แปลงวันที่จากข้อความ `yyyy-MM-dd` ของ Backend มาแสดง คืนข้อความเดิมถ้าอ่านไม่ได้
String formatIsoDateText(String value, bool isThai) {
  final date = DateTime.tryParse(value);
  return date == null ? value : formatDisplayDate(date, isThai);
}

/// อ่านวันที่ที่ผู้ใช้พิมพ์ `วว/ดด/ปปปป` (ใช้ / - หรือ . คั่นก็ได้)
///
/// ปีตั้งแต่ 2400 ขึ้นไปถือเป็น พ.ศ. แล้วลบ 543 ให้ คนพิมพ์ ค.ศ. ก็ยังใช้ได้
/// คืน null ถ้ารูปแบบผิดหรือไม่มีวันนั้นจริง (เช่น 31/02)
DateTime? parseNumericDate(String text) {
  final match = RegExp(
    r'^\s*(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})\s*$',
  ).firstMatch(text);
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  var year = int.parse(match[3]!);
  if (year >= 2400) year -= buddhistEraOffset;
  if (month < 1 || month > 12 || day < 1) return null;
  final date = DateTime(year, month, day);
  if (date.month != month || date.day != day) return null;
  return date;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// เลือกวันเดียว แทน showDatePicker ของ Flutter (ซึ่งแสดงได้แค่ ค.ศ.)
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? title,
}) async {
  final range = await showDialog<DateTimeRange>(
    context: context,
    builder: (_) => AppDatePickerDialog(
      title: title,
      rangeMode: false,
      initialRange: DateTimeRange(start: initialDate, end: initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
  return range?.start;
}

/// เลือกช่วงวัน แทน showDateRangePicker ของ Flutter
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialRange,
  String? title,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => AppDatePickerDialog(
      title: title,
      rangeMode: true,
      initialRange: initialRange,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

/// ปฏิทินของแอป: แสดง พ.ศ. ในภาษาไทย แตะเลือกจากปฏิทิน หรือสลับไปพิมพ์วันที่ก็ได้
class AppDatePickerDialog extends StatefulWidget {
  const AppDatePickerDialog({
    required this.rangeMode,
    required this.firstDate,
    required this.lastDate,
    this.initialRange,
    this.title,
    super.key,
  });

  /// true = เลือกช่วง (วันแรก–วันสุดท้าย) false = เลือกวันเดียว
  final bool rangeMode;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialRange;
  final String? title;

  @override
  State<AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<AppDatePickerDialog> {
  late DateTime _month;
  DateTime? _start;
  DateTime? _end;
  bool _typing = false;

  final _startText = TextEditingController();
  final _endText = TextEditingController();
  String? _startError;
  String? _endError;

  DateTime get _first => _dateOnly(widget.firstDate);
  DateTime get _last => _dateOnly(widget.lastDate);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRange;
    if (initial != null) {
      _start = _dateOnly(initial.start);
      _end = _dateOnly(initial.end);
    }
    var base = _start ?? _dateOnly(DateTime.now());
    if (base.isAfter(_last)) base = _last;
    if (base.isBefore(_first)) base = _first;
    _month = DateTime(base.year, base.month);
  }

  @override
  void dispose() {
    _startText.dispose();
    _endText.dispose();
    super.dispose();
  }

  bool get _isThai => AppLocalizations.of(context).isThai;

  void _toggleTyping() {
    setState(() {
      _typing = !_typing;
      _startError = null;
      _endError = null;
      if (_typing) {
        _startText.text =
            _start == null ? '' : formatNumericDate(_start!, _isThai);
        _endText.text = _end == null ? '' : formatNumericDate(_end!, _isThai);
      }
    });
  }

  void _pick(DateTime day) {
    setState(() {
      if (!widget.rangeMode) {
        _start = day;
        _end = day;
        return;
      }
      final start = _start;
      if (start == null || _end != null || day.isBefore(start)) {
        _start = day;
        _end = null;
      } else {
        _end = day;
      }
    });
  }

  /// ตรวจค่าที่พิมพ์ คืนวันที่ถ้าใช้ได้ ไม่งั้นตั้งข้อความผิดพลาดแล้วคืน null
  DateTime? _readField(TextEditingController field, void Function(String?) setError) {
    final date = parseNumericDate(field.text);
    if (date == null) {
      setError(context.tr('Use day/month/year, e.g. 01/06/2569'));
      return null;
    }
    if (date.isBefore(_first) || date.isAfter(_last)) {
      setError(
        '${context.tr('Choose a date between')} '
        '${formatDisplayDate(_first, _isThai)} – '
        '${formatDisplayDate(_last, _isThai)}',
      );
      return null;
    }
    setError(null);
    return date;
  }

  void _save() {
    if (_typing) {
      String? startError;
      String? endError;
      final start = _readField(_startText, (e) => startError = e);
      final end = widget.rangeMode
          ? _readField(_endText, (e) => endError = e)
          : start;
      if (start != null && end != null && end.isBefore(start)) {
        endError = context.tr('The last day must not be before the first day');
      }
      setState(() {
        _startError = startError;
        _endError = endError;
      });
      if (startError != null || endError != null) return;
      if (start == null || end == null) return;
      Navigator.of(context).pop(DateTimeRange(start: start, end: end));
      return;
    }
    final start = _start;
    final end = _end;
    if (start == null || end == null) return;
    Navigator.of(context).pop(DateTimeRange(start: start, end: end));
  }

  String _headline() {
    final start = _start;
    final end = _end;
    if (!widget.rangeMode) {
      return start == null
          ? context.tr('Tap a date')
          : formatDisplayDate(start, _isThai);
    }
    if (start == null) return context.tr('Tap the first day');
    if (end == null) {
      return '${formatDisplayDate(start, _isThai)} – '
          '${context.tr('tap the last day')}';
    }
    return '${formatDisplayDate(start, _isThai)} – '
        '${formatDisplayDate(end, _isThai)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canSave = _typing || (_start != null && _end != null);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ??
                              context.tr(
                                widget.rangeMode
                                    ? 'Choose a date range'
                                    : 'Choose a date',
                              ),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _typing
                              ? context.tr('Type the date')
                              : _headline(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('date-picker-mode-toggle'),
                    tooltip: context.tr(
                      _typing ? 'Pick from calendar' : 'Type the date',
                    ),
                    onPressed: _toggleTyping,
                    icon: Icon(
                      _typing
                          ? Icons.calendar_month_rounded
                          : Icons.edit_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_typing) _buildTyping(context) else _buildCalendar(context),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('Cancel')),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    key: const Key('date-picker-save'),
                    onPressed: canSave ? _save : null,
                    child: Text(context.tr('Save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTyping(BuildContext context) {
    final hint = _isThai ? 'วว/ดด/ปปปป (พ.ศ.)' : 'dd/mm/yyyy';
    InputDecoration decoration(String label, String? error) => InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      errorMaxLines: 2,
      border: const OutlineInputBorder(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('date-picker-start-field'),
          controller: _startText,
          autofocus: true,
          keyboardType: TextInputType.datetime,
          decoration: decoration(
            context.tr(widget.rangeMode ? 'First day' : 'Date'),
            _startError,
          ),
          onSubmitted: (_) => widget.rangeMode ? null : _save(),
        ),
        if (widget.rangeMode) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('date-picker-end-field'),
            controller: _endText,
            keyboardType: TextInputType.datetime,
            decoration: decoration(context.tr('Last day'), _endError),
            onSubmitted: (_) => _save(),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = _month.weekday % 7; // อาทิตย์ = 0
    final firstMonth = DateTime(_first.year, _first.month);
    final lastMonth = DateTime(_last.year, _last.month);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.tr('Previous month'),
              onPressed: _month.isAfter(firstMonth)
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                formatMonthYear(_month, _isThai),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: context.tr('Next month'),
              onPressed: _month.isBefore(lastMonth)
                  ? () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final name
                in _isThai ? _thaiWeekdaysShort : _englishWeekdaysShort)
              Expanded(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              _dayCell(context, DateTime(_month.year, _month.month, d)),
          ],
        ),
      ],
    );
  }

  Widget _dayCell(BuildContext context, DateTime day) {
    final colors = Theme.of(context).colorScheme;
    final start = _start;
    final end = _end;
    final enabled = !day.isBefore(_first) && !day.isAfter(_last);
    final isEdge = day == start || day == end;
    final inRange =
        start != null && end != null && day.isAfter(start) && day.isBefore(end);
    final isToday = day == _dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isEdge
            ? colors.primary
            : inRange
            ? colors.primary.withValues(alpha: 0.16)
            : Colors.transparent,
        shape: CircleBorder(
          side: isToday && !isEdge
              ? BorderSide(color: colors.primary)
              : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? () => _pick(day) : null,
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isEdge ? FontWeight.w700 : FontWeight.w400,
                color: !enabled
                    ? colors.onSurface.withValues(alpha: 0.3)
                    : isEdge
                    ? colors.onPrimary
                    : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
