import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../controllers/schedule_controller.dart';
import '../localization/localized_material.dart';
import '../models/schedule_import.dart';
import '../theme/app_theme.dart';
import '../utils/thai_date.dart';

class ScheduleImportScreen extends StatefulWidget {
  const ScheduleImportScreen({
    required this.controller,
    this.onRoomsChanged,
    super.key,
  });

  final ScheduleController controller;
  final Future<void> Function()? onRoomsChanged;

  @override
  State<ScheduleImportScreen> createState() => _ScheduleImportScreenState();
}

class _ScheduleImportScreenState extends State<ScheduleImportScreen> {
  static const _fileTypes = XTypeGroup(
    label: 'Excel or CSV',
    extensions: ['xlsx', 'csv'],
    mimeTypes: [
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/csv',
    ],
    uniformTypeIdentifiers: [
      'org.openxmlformats.spreadsheetml.sheet',
      'public.comma-separated-values-text',
    ],
    webWildCards: [
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/csv',
    ],
  );
  static const _csvType = XTypeGroup(
    label: 'CSV',
    extensions: ['csv'],
    mimeTypes: ['text/csv'],
    uniformTypeIdentifiers: ['public.comma-separated-values-text'],
    webWildCards: ['text/csv'],
  );
  static const _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  ScheduleImportPreview? _preview;
  bool _isReading = false;
  bool _isImporting = false;
  String? _errorMessage;

  /// ภาคเรียนและช่วงวันที่ใช้ตารางนี้ ต้องกรอกก่อนนำเข้า
  final _semesterController = TextEditingController();
  DateTimeRange? _termRange;

  static final _semesterPattern = RegExp(r'^[1-3]/\d{4}$');

  bool get _isBusy => _isReading || _isImporting;

  bool get _semesterValid =>
      _semesterPattern.hasMatch(_semesterController.text.trim());

  bool get _termReady => _semesterValid && _termRange != null;

  @override
  void dispose() {
    _semesterController.dispose();
    super.dispose();
  }

  Future<void> _pickTermRange() async {
    final now = DateTime.now();
    // ใช้ปฏิทินของแอปเอง เพราะปฏิทินของ Flutter แสดงและรับปีเป็น ค.ศ. เท่านั้น
    // ผู้ใช้คุ้นกับ พ.ศ. (เช่น 2569) จึงแสดงปี พ.ศ. เมื่อแอปเป็นภาษาไทย
    final picked = await showAppDateRangePicker(
      context: context,
      title: context.tr('Semester dates'),
      initialRange: _termRange,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _termRange = picked);
  }

  Future<void> _chooseFile() async {
    if (_isBusy) return;

    final file = await openFile(
      acceptedTypeGroups: const [_fileTypes],
    );
    if (file == null || !mounted) return;

    setState(() {
      _isReading = true;
      _errorMessage = null;
      _preview = null;
    });

    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 8 * 1024 * 1024) {
        throw Exception(context.tr('The file must not exceed 8 MB.'));
      }

      final preview = await widget.controller.previewScheduleFile(
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        // ไฟล์ใหม่อาจเป็นคนละเทอม ให้เลือกช่วงวันใหม่ทุกครั้ง
        _semesterController.text = preview.semester;
        _termRange = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = context.tr(error.toString()));
    } finally {
      if (mounted) {
        setState(() => _isReading = false);
      }
    }
  }

  Future<void> _downloadCsv() async {
    final preview = _preview;
    if (preview == null || preview.csv.isEmpty || _isBusy) return;

    try {
      final location = await getSaveLocation(
        suggestedName: 'rmutt_class_schedules_${preview.semester}.csv',
        acceptedTypeGroups: const [_csvType],
      );
      if (location == null) return;

      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(preview.csv)),
        mimeType: 'text/csv',
        name: 'rmutt_class_schedules.csv',
      );
      await file.saveTo(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('CSV file saved.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(error.toString()))),
      );
    }
  }

  Future<void> _confirmImport() async {
    final range = _termRange;
    if (_preview == null || _isBusy || range == null || !_termReady) return;
    final preview = _preview!.withTerm(
      semester: _semesterController.text.trim(),
      startDate: range.start,
      endDate: range.end,
    );

    final isThai = AppLocalizations.of(context).isThai;
    final rangeText =
        '${formatDisplayDate(range.start, isThai)} – '
        '${formatDisplayDate(range.end, isThai)}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Import this timetable?')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isThai
                  ? 'ภาคเรียน ${preview.semester} ใช้ตั้งแต่ $rangeText'
                  : 'Semester ${preview.semester}, in use $rangeText',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              isThai
                  ? 'ระบบจะแทนที่ตารางเดิมเฉพาะ ${preview.roomCount} ห้อง'
                        'ที่พบในไฟล์ และนำเข้า '
                        '${preview.scheduleCount} รายการ'
                  : 'The existing schedules for the ${preview.roomCount} '
                        'rooms in this file will be replaced with '
                        '${preview.scheduleCount} entries.',
            ),
            if (preview.newRooms.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                isThai
                    ? 'ระบบจะสร้างห้องใหม่ ${preview.newRoomCount} ห้อง:'
                    : '${preview.newRoomCount} new rooms will be created:',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                preview.newRooms
                    .map((room) => _roomImportLabel(room, isThai))
                    .join('\n'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            key: const Key('confirm-schedule-import'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('Import Timetable')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.controller.importSchedulePreview(preview);
      if (!mounted) return;
      if (result.createdRooms.isNotEmpty) {
        await widget.onRoomsChanged?.call();
        if (!mounted) return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: 42,
          ),
          title: Text(context.tr('Timetable imported.')),
          content: Text(
            isThai
                ? 'นำเข้า ${result.importedCount} รายการ สำหรับ '
                      '${result.replacedRooms.length} ห้องเรียบร้อยแล้ว'
                      '${result.createdRooms.isEmpty ? '' : '\nสร้างห้องใหม่ ${result.createdRooms.length} ห้อง'}'
                : 'Imported ${result.importedCount} entries for '
                      '${result.replacedRooms.length} rooms.'
                      '${result.createdRooms.isEmpty ? '' : '\nCreated ${result.createdRooms.length} new rooms.'}',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr('Done')),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = context.tr(error.toString()));
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('Import Timetable'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (preview != null)
            IconButton(
              tooltip: context.tr('Choose another file'),
              onPressed: _isBusy ? null : _chooseFile,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          const _IntroductionCard(),
          const SizedBox(height: 14),
          if (_isReading)
            const _ReadingCard()
          else if (preview == null)
            _FilePickerCard(
              onChoose: _chooseFile,
            )
          else
            _PreviewContent(
              preview: preview,
              onChooseAnother: _chooseFile,
              onDownloadCsv: _downloadCsv,
              termSection: _TermCard(
                semesterController: _semesterController,
                semesterValid: _semesterValid,
                range: _termRange,
                onSemesterChanged: () => setState(() {}),
                onPickRange: _isBusy ? null : _pickTermRange,
              ),
            ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            _ErrorCard(message: _errorMessage!),
          ],
        ],
      ),
      bottomNavigationBar: preview == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: FilledButton.icon(
                key: const Key('import-schedule-button'),
                onPressed: _isBusy || !_termReady ? null : _confirmImport,
                icon: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  _isImporting
                      ? 'Importing...'
                      : _termReady
                      ? 'Import Timetable'
                      : 'Choose the semester dates first',
                ),
              ),
            ),
    );
  }
}

class _IntroductionCard extends StatelessWidget {
  const _IntroductionCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Excel is converted automatically'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr('Choose the original .xlsx file. The app reads every room sheet, checks the times, and shows a preview before saving.'),
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilePickerCard extends StatelessWidget {
  const _FilePickerCard({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.table_view_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            context.tr('Choose an Excel or CSV file'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('Supports .xlsx and normalized .csv files up to 8 MB.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('choose-schedule-file'),
            onPressed: onChoose,
            icon: const Icon(Icons.folder_open_rounded),
            label: Text(context.tr('Select File')),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(context.tr('Reading and checking the timetable...')),
        ],
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({
    required this.preview,
    required this.onChooseAnother,
    required this.onDownloadCsv,
    required this.termSection,
  });

  final ScheduleImportPreview preview;
  final VoidCallback onChooseAnother;
  final VoidCallback onDownloadCsv;

  /// ช่องกรอกภาคเรียนและช่วงวันที่ใช้ตาราง วางไว้ใต้ชื่อไฟล์
  final Widget termSection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isThai = AppLocalizations.of(context).isThai;
    final shownSchedules = preview.schedules.take(25).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.description_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview.semester.isEmpty
                          ? context.tr('Semester not specified')
                          : '${context.tr('Semester')} ${preview.semester}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('Choose another file'),
                onPressed: onChooseAnother,
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        termSection,
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '${preview.roomCount}',
                label: context.tr('Rooms'),
                icon: Icons.meeting_room_rounded,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _StatCard(
                value: '${preview.scheduleCount}',
                label: context.tr('Classes'),
                icon: Icons.event_note_rounded,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _StatCard(
                value: '${preview.warnings.length}',
                label: context.tr('Warnings'),
                icon: Icons.info_outline_rounded,
              ),
            ),
          ],
        ),
        if (preview.newRooms.isNotEmpty) ...[
          const SizedBox(height: 12),
          _NewRoomsCard(rooms: preview.newRooms),
        ],
        if (preview.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.orangeSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Please review'),
                  style: const TextStyle(
                    color: Color(0xFF8A4D00),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                ...preview.warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '• $warning',
                      style: const TextStyle(
                        color: Color(0xFF704400),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                isThai
                    ? 'ตัวอย่าง ${shownSchedules.length} รายการแรก'
                    : 'First ${shownSchedules.length} entries',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onDownloadCsv,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text(context.tr('Save CSV')),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ...shownSchedules.map(
          (schedule) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SchedulePreviewCard(schedule: schedule),
          ),
        ),
        if (preview.scheduleCount > shownSchedules.length)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              isThai
                  ? 'และอีก ${preview.scheduleCount - shownSchedules.length} '
                        'รายการ'
                  : 'And ${preview.scheduleCount - shownSchedules.length} '
                        'more entries',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('Nothing is saved yet. Import replaces schedules only for the rooms found in this file. Other rooms are unchanged.'),
                  style: const TextStyle(fontSize: 11.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ภาคเรียนและวันเปิด-ปิดภาคของตารางที่จะนำเข้า
///
/// หนึ่งปีการศึกษามีหลายภาคเรียน ตารางแต่ละชุดจึงใช้ได้เฉพาะช่วงของมัน
/// นอกช่วงนี้ระบบถือว่าไม่มีคาบเรียน (เช่นช่วงปิดภาค) และปิดแอร์ห้องว่างตามปกติ
class _TermCard extends StatelessWidget {
  const _TermCard({
    required this.semesterController,
    required this.semesterValid,
    required this.range,
    required this.onSemesterChanged,
    required this.onPickRange,
  });

  final TextEditingController semesterController;
  final bool semesterValid;
  final DateTimeRange? range;
  final VoidCallback onSemesterChanged;
  final VoidCallback? onPickRange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final isThai = AppLocalizations.of(context).isThai;
    final picked = range;
    final showSemesterError =
        semesterController.text.trim().isNotEmpty && !semesterValid;

    return Container(
      key: const Key('schedule-import-term'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: picked == null ? palette.warn : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.date_range_rounded, color: palette.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('Period this timetable applies to'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              'Outside these dates the system treats every room as having no '
              'classes, for example during the semester break.',
            ),
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('schedule-import-semester'),
            controller: semesterController,
            onChanged: (_) => onSemesterChanged(),
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: context.tr('Semester'),
              hintText: isThai ? 'เช่น 1/2569' : 'e.g. 1/2569',
              errorText: showSemesterError
                  ? context.tr('Use semester/year, e.g. 1/2569')
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('schedule-import-term-dates'),
            onPressed: onPickRange,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 20,
                  color: picked == null ? palette.warn : palette.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: picked == null
                      ? Text(
                          context.tr('Choose the first and last day'),
                          style: TextStyle(
                            color: palette.warn,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${formatDisplayDate(picked.start, isThai)} – '
                              '${formatDisplayDate(picked.end, isThai)}',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isThai
                                  ? 'รวม ${picked.duration.inDays + 1} วัน'
                                  : '${picked.duration.inDays + 1} days',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewRoomsCard extends StatelessWidget {
  const _NewRoomsCard({required this.rooms});

  final List<ScheduleImportRoom> rooms;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isThai = AppLocalizations.of(context).isThai;
    return Container(
      key: const Key('schedule-import-new-rooms'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_home_work_rounded,
                color: colors.primary,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isThai
                      ? 'จะสร้างห้องใหม่ ${rooms.length} ห้อง'
                      : '${rooms.length} new rooms will be created',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rooms.map(
            (room) => Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '• ${_roomImportLabel(room, isThai)}',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isThai
                ? 'ห้องจะถูกสร้างเมื่อกดยืนยันนำเข้าเท่านั้น'
                : 'Rooms are created only after you confirm the import.',
            style: TextStyle(
              color: colors.onPrimaryContainer.withValues(alpha: 0.78),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

String _roomImportLabel(ScheduleImportRoom room, bool isThai) {
  if (room.floorNumber == 0) {
    return isThai
        ? '${room.roomNumber} (ห้องพิเศษ)'
        : '${room.roomNumber} (Special)';
  }
  return isThai
      ? '${room.roomNumber} (ชั้น ${room.floorNumber})'
      : '${room.roomNumber} (Floor ${room.floorNumber})';
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulePreviewCard extends StatelessWidget {
  const _SchedulePreviewCard({required this.schedule});

  final ScheduleImportEntry schedule;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final day = schedule.dayOfWeek >= 0 && schedule.dayOfWeek < 7
        ? _ScheduleImportScreenState._days[schedule.dayOfWeek]
        : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  schedule.roomNumber.startsWith('16') &&
                          schedule.roomNumber.length >= 3
                      ? schedule.roomNumber.substring(2, 3)
                      : 'SP',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  schedule.roomNumber,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.subjectName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  '${context.tr(day)} · ${schedule.startTime}–'
                  '${schedule.endTime}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
