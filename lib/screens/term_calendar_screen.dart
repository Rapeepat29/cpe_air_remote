import '../localization/localized_material.dart';

import '../controllers/schedule_controller.dart';
import '../models/room_calendar.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';
import 'booking_editor_screen.dart';

/// ปฏิทินภาคเรียน: วันเปิด–ปิดของแต่ละเทอม (เหมือนเว็บแอป term-calendar.js)
///
/// ตารางเรียนที่ใช้อยู่มีผลเฉพาะระหว่างวันเปิด–ปิดของภาคเรียนของมัน ก่อนเปิด
/// หรือหลังปิดภาค Backend ถือว่าทุกห้องอยู่นอกคาบ จึงไม่ต้องล้างตารางตอนปิดภาค
/// และนำเข้าตารางเทอมหน้าไว้ล่วงหน้าได้
class TermCalendarScreen extends StatelessWidget {
  const TermCalendarScreen({
    required this.controller,
    required this.isAdmin,
    this.presetSemester,
    super.key,
  });

  final ScheduleController controller;
  final bool isAdmin;

  /// เปิดฟอร์มตั้งวันของภาคเรียนนี้ทันทีเมื่อเข้าหน้า (จากปุ่ม "ตั้งวันเปิด–ปิด")
  final String? presetSemester;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n(context, 'ปฏิทินภาคเรียน', 'Term calendar'))),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              key: const Key('add-term-button'),
              onPressed: () => editAcademicTerm(
                context,
                controller,
                presetSemester: _suggestSemester(),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n(context, 'เพิ่มภาคเรียน', 'Add semester')),
            )
          : null,
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          final terms = controller.terms;
          final current = controller.timetable?.semester ?? '';
          final isThai = AppLocalizations.of(context).isThai;

          return RefreshIndicator(
            onRefresh: controller.reloadCalendar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 96),
              children: [
                Text(
                  l10n(
                    context,
                    'ตารางเรียนมีผลเฉพาะระหว่างวันเปิด–ปิดของภาคเรียนของมัน ก่อนเปิดหรือหลังปิดภาค '
                        'ระบบถือว่าทุกห้องว่าง: ห้องว่างเกิน 5 นาทีสั่งปิดแอร์ และแจ้งเตือนเมื่อมีคนเปิดแอร์ใช้ '
                        'จึงไม่ต้องล้างตารางตอนปิดภาค และนำเข้าตารางเทอมหน้าไว้ล่วงหน้าได้ '
                        'ภาคเรียนที่ไม่ได้ตั้งวันไว้ ระบบใช้ตารางทุกวัน',
                    'A timetable only applies between its semester\'s start and end dates. '
                        'Outside them every room counts as empty: AC is turned off after 5 '
                        'minutes and use is reported. No need to clear the timetable at the '
                        'end of term, and next term\'s timetable can be imported early. '
                        'A semester without dates uses the timetable every day.',
                  ),
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 14),
                if (controller.calendarError != null && terms.isEmpty)
                  Text(
                    context.tr(controller.calendarError!),
                    style: TextStyle(color: colors.error),
                  )
                else if (terms.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Text(
                      isAdmin
                          ? l10n(
                              context,
                              'ยังไม่ได้ตั้งวันเปิด–ปิดภาคเรียน กด "เพิ่มภาคเรียน" เช่น 1/2569 และ 2/2569 ของปีนี้',
                              'No semester dates yet. Tap "Add semester", e.g. 1/2569 and 2/2569.',
                            )
                          : l10n(
                              context,
                              'ผู้ดูแลระบบยังไม่ได้ตั้งวันเปิด–ปิดภาคเรียน',
                              'The administrator has not set semester dates yet.',
                            ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final term in terms)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TermCard(
                        term: term,
                        today: controller.today,
                        isCurrent: term.semester == current,
                        isThai: isThai,
                        onEdit: isAdmin
                            ? () => editAcademicTerm(context, controller, term: term)
                            : null,
                        onDelete: isAdmin
                            ? () => _deleteTerm(context, term, term.semester == current)
                            : null,
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// เดาภาคเรียนถัดไปให้กรอกน้อยลง (เหมือนเว็บ)
  String _suggestSemester() {
    final preset = presetSemester;
    if (preset != null && preset.isNotEmpty) return preset;
    final current = controller.timetable?.semester ?? '';
    if (current.isNotEmpty && controller.termFor(current) == null) return current;
    final terms = controller.terms;
    final last = terms.isEmpty ? current : terms.last.semester;
    final match = RegExp(r'^([1-3])/(\d{4})$').firstMatch(last);
    if (match == null) return '';
    final term = int.parse(match.group(1)!);
    final year = int.parse(match.group(2)!);
    return term >= 2 ? '1/${year + 1}' : '2/$year';
  }

  Future<void> _deleteTerm(
    BuildContext context,
    AcademicTerm term,
    bool inUse,
  ) async {
    final isThai = AppLocalizations.of(context).isThai;
    final range =
        '${shortIsoDate(term.startDate, isThai)} – ${shortIsoDate(term.endDate, isThai)}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          l10n(
            context,
            'ลบภาคเรียน ${term.semester} ออกจากปฏิทิน?',
            'Remove semester ${term.semester} from the calendar?',
          ),
        ),
        content: Text(
          '$range\n\n${inUse ? l10n(context, 'ตารางเรียนที่ใช้อยู่เป็นของภาคนี้ เมื่อลบแล้วระบบจะใช้ตารางทุกวัน รวมช่วงปิดภาค', 'The current timetable belongs to this semester. After removing it the timetable applies every day, including breaks.') : l10n(context, 'ตารางเรียนและข้อมูลไฟฟ้าไม่ถูกลบ', 'Timetables and energy data are not deleted.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n(context, 'ลบออกจากปฏิทิน', 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.deleteAcademicTerm(term.semester);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n(context, 'ลบภาคเรียน ${term.semester} แล้ว', 'Semester ${term.semester} removed.'),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(context.tr(error.toString()))));
    }
  }
}

/// ฟอร์มเพิ่ม/แก้วันเปิด–ปิดภาคเรียน ใช้ได้จากหน้าตารางเรียนด้วย
Future<void> editAcademicTerm(
  BuildContext context,
  ScheduleController controller, {
  AcademicTerm? term,
  String presetSemester = '',
}) async {
  final saved = await showDialog<AcademicTerm>(
    context: context,
    builder: (_) => _TermDialog(
      controller: controller,
      term: term,
      presetSemester: presetSemester,
    ),
  );
  if (saved == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n(context, 'บันทึกภาคเรียน ${saved.semester} แล้ว', 'Semester ${saved.semester} saved.'),
      ),
    ),
  );
}

class _TermDialog extends StatefulWidget {
  const _TermDialog({
    required this.controller,
    required this.presetSemester,
    this.term,
  });

  final ScheduleController controller;
  final AcademicTerm? term;
  final String presetSemester;

  @override
  State<_TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends State<_TermDialog> {
  late final TextEditingController _semester;
  String? _startDate;
  String? _endDate;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _semester = TextEditingController(
      text: widget.term?.semester ?? widget.presetSemester,
    );
    _startDate = widget.term?.startDate;
    _endDate = widget.term?.endDate;
  }

  @override
  void dispose() {
    _semester.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final start = _startDate;
    final end = _endDate;
    final range = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3, 12, 31),
      initialRange: start != null && end != null
          ? DateTimeRange(start: dateOfIso(start), end: dateOfIso(end))
          : null,
      title: l10n(context, 'วันเปิด – วันปิดภาคเรียน', 'Semester start – end'),
    );
    if (range == null || !mounted) return;
    setState(() {
      _startDate = isoDateOf(range.start);
      _endDate = isoDateOf(range.end);
      _error = null;
    });
  }

  Future<void> _save() async {
    final semester = _semester.text.trim();
    if (!AcademicTerm.semesterPattern.hasMatch(semester)) {
      setState(
        () => _error = l10n(
          context,
          'ภาคเรียนต้องเป็นรูปแบบ เทอม/ปีการศึกษา เช่น 1/2569',
          'Use term/academic year, e.g. 1/2569',
        ),
      );
      return;
    }
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null) {
      setState(
        () => _error = l10n(
          context,
          'กรุณาเลือกวันเปิดและวันปิดภาคเรียน',
          'Please choose the start and end dates.',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.controller.saveAcademicTerm(
        AcademicTerm(semester: semester, startDate: start, endDate: end),
        previousSemester: widget.term?.semester,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
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
    final isThai = AppLocalizations.of(context).isThai;
    final colors = Theme.of(context).colorScheme;
    final start = _startDate;
    final end = _endDate;
    return AlertDialog(
      title: Text(
        widget.term == null
            ? l10n(context, 'เพิ่มภาคเรียน', 'Add semester')
            : l10n(
                context,
                'แก้วันเปิด–ปิด ภาคเรียน ${widget.term!.semester}',
                'Edit semester ${widget.term!.semester}',
              ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n(
                context,
                'ตารางเรียนของภาคนี้จะมีผลเฉพาะระหว่างวันเปิดถึงวันปิด (รวมสองวันนั้น)',
                'The timetable applies only from the start to the end date (inclusive).',
              ),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('term-semester-field'),
              controller: _semester,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: l10n(context, 'ภาคเรียน (เทอม/ปีการศึกษา)', 'Semester (term/year)'),
                hintText: l10n(context, 'เช่น 1/2569', 'e.g. 1/2569'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('term-dates-button'),
              onPressed: _busy ? null : _pickRange,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                start != null && end != null
                    ? '${shortIsoDate(start, isThai)} – ${shortIsoDate(end, isThai)}'
                    : l10n(context, 'เลือกวันเปิด – วันปิดภาค', 'Choose start – end dates'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: colors.error, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          key: const Key('term-save-button'),
          onPressed: _busy ? null : _save,
          child: Text(context.tr('Save')),
        ),
      ],
    );
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({
    required this.term,
    required this.today,
    required this.isCurrent,
    required this.isThai,
    this.onEdit,
    this.onDelete,
  });

  final AcademicTerm term;
  final String today;
  final bool isCurrent;
  final bool isThai;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = termStatusLabel(term.statusOn(today), isThai);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? colors.primary : colors.outlineVariant,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      term.semester,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Text(
                        l10n(context, 'ตารางที่ใช้อยู่', 'Current timetable'),
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${shortIsoDate(term.startDate, isThai)} – ${shortIsoDate(term.endDate, isThai)}',
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: context.tr('Edit'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: context.tr('Delete'),
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: colors.error),
            ),
        ],
      ),
    );
  }
}

/// ป้ายสถานะภาคเรียนวันนี้
(String, Color) termStatusLabel(TermStatus status, bool isThai) {
  return switch (status) {
    TermStatus.active => (isThai ? 'กำลังเปิดภาค' : 'In session', AppColors.green),
    TermStatus.before => (isThai ? 'ยังไม่เปิดภาค' : 'Not started', const Color(0xFF3B82C4)),
    TermStatus.after => (isThai ? 'ปิดภาคแล้ว' : 'Ended', const Color(0xFF8A9399)),
    TermStatus.unknown => (isThai ? 'ไม่ทราบสถานะ' : 'Unknown', const Color(0xFF8A9399)),
  };
}
