import '../localization/localized_material.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/energy_controller.dart';
import '../models/energy_data.dart';
import '../theme/app_theme.dart';
import '../utils/file_saver.dart';
import '../utils/number_format.dart';
import '../utils/thai_date.dart';
import '../widgets/section_title.dart';

/// หน้า `ฐานข้อมูล`
///
/// แท็บแรกคือค่าไฟที่อัปเดตต่อเนื่องจาก PZEM-004T
/// แท็บที่สองคือการเลือกช่วงวัน ขอบเขต และค่าที่ต้องการ แล้วดาวน์โหลดเป็น Excel
class EnergyDatabaseScreen extends StatefulWidget {
  const EnergyDatabaseScreen({
    required this.controller,
    required this.appSettingsController,
    super.key,
  });

  final EnergyController controller;
  final AppSettingsController appSettingsController;

  @override
  State<EnergyDatabaseScreen> createState() => _EnergyDatabaseScreenState();
}

class _EnergyDatabaseScreenState extends State<EnergyDatabaseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  EnergyScope _scope = EnergyScope.building;
  late DateTime _from;
  late DateTime _to;
  bool _rangeMode = false;
  final Set<String> _selectedRooms = <String>{};
  final Set<String> _selectedDevices = <String>{};
  final Set<String> _selectedMetrics = <String>{'consumption'};
  bool _includeCost = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final today = DateTime.now();
    _from = DateTime(today.year, today.month, today.day);
    _to = _from;
    widget.controller.initialize();
    widget.controller.startLiveUpdates();
  }

  @override
  void dispose() {
    widget.controller.stopLiveUpdates();
    _tabController.dispose();
    super.dispose();
  }

  bool get _isThai => widget.appSettingsController.locale.languageCode == 'th';

  EnergyQuery get _query => EnergyQuery(
    from: _from,
    to: _to,
    scope: _scope,
    rooms: _selectedRooms.toList()..sort(),
    devices: _selectedDevices.toList()..sort(),
    metrics: _orderedMetricKeys(),
    rate: _includeCost ? widget.appSettingsController.electricityRate : 0,
  );

  List<String> _orderedMetricKeys() {
    final allowed = widget.controller.metricsFor(_scope);
    final keys = allowed
        .where((metric) => _selectedMetrics.contains(metric.key))
        .map((metric) => metric.key)
        .toList();
    if (_includeCost && !keys.contains('cost')) keys.add('cost');
    if (keys.isEmpty) keys.add('consumption');
    return keys;
  }

  void _changeScope(EnergyScope scope) {
    setState(() {
      _scope = scope;
      if (!scope.isHighDetail) {
        _selectedRooms.clear();
        _selectedDevices.clear();
        // โหมดสรุปไม่มีค่าที่ละเอียดเกินไป ต้องถอดออกก่อนไม่ให้ค้าง
        final allowed = widget.controller
            .metricsFor(scope)
            .map((metric) => metric.key)
            .toSet();
        _selectedMetrics.removeWhere((key) => !allowed.contains(key));
        if (_selectedMetrics.isEmpty) _selectedMetrics.add('consumption');
      }
      if (scope != EnergyScope.device) _selectedDevices.clear();
    });
    widget.controller.clearPreview();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final oldest = widget.controller.sources.oldestDate;
    // เปิดให้ย้อนได้ถึงข้อมูลชุดแรกที่มีจริง แต่ไม่ต่ำกว่าต้นปี 2024
    final firstDate = oldest != null && oldest.isBefore(DateTime(2024))
        ? DateTime(oldest.year)
        : DateTime(2024);
    final picked = await showAppDatePicker(
      context: context,
      initialDate: isStart ? _from : _to,
      firstDate: firstDate,
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _from = picked;
        if (!_rangeMode || _to.isBefore(_from)) _to = picked;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = picked;
      }
    });
    widget.controller.clearPreview();
  }

  Future<void> _preview() async {
    await widget.controller.loadPreview(_query);
  }

  Future<void> _download() async {
    final controller = widget.controller;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final file = await controller.exportExcel(_query, english: !_isThai);
      final result = await saveExportFile(
        fileName: file.fileName,
        bytes: file.bytes,
      );
      if (!mounted) return;

      final message = switch (result.status) {
        FileSaveStatus.saved =>
          '${context.tr('Excel file saved to')} ${result.path}',
        FileSaveStatus.shared => context.tr('Excel file is ready to share.'),
        FileSaveStatus.cancelled => context.tr('Saving was cancelled.'),
        FileSaveStatus.failed =>
          '${context.tr('Could not save the file.')} ${result.error ?? ''}',
      };
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: result.isSuccess ? AppColors.green : null,
          ),
        );
    } catch (error) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('ApiException: ', ''),
            ),
            backgroundColor: AppColors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        widget.appSettingsController,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Database')),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppPalette.of(context).accent,
              labelColor: AppPalette.of(context).onBar,
              unselectedLabelColor: AppPalette.of(
                context,
              ).onBar.withValues(alpha: 0.72),
              tabs: [
                Tab(text: context.tr('Live readings')),
                Tab(text: context.tr('Export to Excel')),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [_buildLiveTab(context), _buildExportTab(context)],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------- แท็บค่าไฟสด

  Widget _buildLiveTab(BuildContext context) {
    final controller = widget.controller;
    final colors = Theme.of(context).colorScheme;
    final readings = controller.live.readings;

    return RefreshIndicator(
      onRefresh: () => controller.refreshLive(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _LiveSummaryCard(
            snapshot: controller.live,
            appSettingsController: widget.appSettingsController,
          ),
          const SizedBox(height: 14),
          SectionTitle(title: context.tr('Update every')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final seconds in kEnergyRefreshChoices)
                ChoiceChip(
                  label: Text('$seconds ${context.tr('sec')}'),
                  selected: controller.refreshSeconds == seconds,
                  onSelected: (_) => controller.setRefreshSeconds(seconds),
                ),
              FilterChip(
                avatar: Icon(
                  controller.isStreaming
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: Text(
                  controller.isStreaming
                      ? context.tr('Pause')
                      : context.tr('Resume'),
                ),
                selected: controller.isStreaming,
                onSelected: (_) => controller.isStreaming
                    ? controller.stopLiveUpdates()
                    : controller.startLiveUpdates(),
              ),
            ],
          ),
          if (controller.liveError != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: controller.liveError!),
          ],
          const SizedBox(height: 16),
          SectionTitle(title: context.tr('Every air conditioner')),
          const SizedBox(height: 10),
          if (readings.isEmpty)
            _EmptyHint(
              icon: Icons.sensors_off_rounded,
              title: context.tr('No electrical data yet'),
              detail: context.tr(
                'Values appear here once an ESP32 with a PZEM-004T reports in.',
              ),
            )
          else
            for (final reading in readings) ...[
              _LiveReadingCard(reading: reading),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 6),
          Text(
            context.tr(
              'PZEM-004T v3.0 measures voltage, current, active power, '
              'accumulated energy, frequency and power factor.',
            ),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------ แท็บส่งออก

  Widget _buildExportTab(BuildContext context) {
    final controller = widget.controller;

    if (controller.isCatalogLoading && controller.metrics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        if (controller.catalogError != null) ...[
          _ErrorBanner(message: controller.catalogError!),
          const SizedBox(height: 12),
        ],
        _buildDateSection(context),
        const SizedBox(height: 18),
        _buildScopeSection(context),
        if (_scope.isHighDetail) ...[
          const SizedBox(height: 18),
          _buildRoomSection(context),
        ],
        if (_scope == EnergyScope.device) ...[
          const SizedBox(height: 18),
          _buildDeviceSection(context),
        ],
        const SizedBox(height: 18),
        _buildMetricSection(context),
        const SizedBox(height: 20),
        _buildActionRow(context),
        if (controller.previewError != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: controller.previewError!),
        ],
        if (controller.hasPreview) ...[
          const SizedBox(height: 18),
          _buildPreview(context),
        ],
      ],
    );
  }

  Widget _buildDateSection(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return _Panel(
      title: context.tr('Date range'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.today_rounded, size: 18),
                label: Text(context.tr('Single day')),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(context.tr('Date range')),
              ),
            ],
            selected: {_rangeMode},
            onSelectionChanged: (value) {
              setState(() {
                _rangeMode = value.first;
                if (!_rangeMode) _to = _from;
              });
              widget.controller.clearPreview();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: _rangeMode
                      ? context.tr('From')
                      : context.tr('Date'),
                  value: formatDisplayDate(
                    _from,
                    AppLocalizations.of(context).isThai,
                  ),
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              if (_rangeMode) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(
                    label: context.tr('To'),
                    value: formatDisplayDate(
                      _to,
                      AppLocalizations.of(context).isThai,
                    ),
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _coverageText(context),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _coverageText(BuildContext context) {
    final catalog = widget.controller.sources;
    final oldest = catalog.oldestDate;
    final newest = catalog.newestDate;
    if (oldest == null || newest == null) {
      return context.tr('No stored hours yet.');
    }
    final isThai = AppLocalizations.of(context).isThai;
    return '${context.tr('Stored data covers')} '
        '${formatDisplayDate(oldest, isThai)} – '
        '${formatDisplayDate(newest, isThai)}';
  }

  Widget _buildScopeSection(BuildContext context) {
    return _Panel(
      title: context.tr('Level of detail'),
      child: Column(
        children: [
          for (final scope in EnergyScope.values) ...[
            _ScopeTile(
              scope: scope,
              selected: _scope == scope,
              onTap: () => _changeScope(scope),
            ),
            if (scope != EnergyScope.values.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomSection(BuildContext context) {
    final rooms = widget.controller.sources.rooms;
    final colors = Theme.of(context).colorScheme;

    return _Panel(
      title: context.tr('Rooms'),
      trailing: TextButton(
        onPressed: rooms.isEmpty
            ? null
            : () {
                setState(() {
                  if (_selectedRooms.isEmpty) {
                    _selectedRooms.addAll(
                      rooms.map((room) => room.roomNumber),
                    );
                  } else {
                    _selectedRooms.clear();
                  }
                  _pruneDevices();
                });
                widget.controller.clearPreview();
              },
        child: Text(
          _selectedRooms.isEmpty
              ? context.tr('Select all')
              : context.tr('Clear'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Leaving every room unticked includes all of them.'),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 10),
          if (rooms.isEmpty)
            _EmptyHint(
              icon: Icons.meeting_room_outlined,
              title: context.tr('No rooms with data yet'),
              detail: context.tr(
                'A room appears here after one of its air conditioners '
                'reports electrical data.',
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final room in rooms)
                  FilterChip(
                    label: Text(
                      '${room.roomNumber} · '
                      '${context.tr('${room.deviceCount} units')}',
                    ),
                    selected: _selectedRooms.contains(room.roomNumber),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedRooms.add(room.roomNumber);
                        } else {
                          _selectedRooms.remove(room.roomNumber);
                        }
                        _pruneDevices();
                      });
                      widget.controller.clearPreview();
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// เครื่องที่ไม่อยู่ในห้องที่เลือกแล้ว ต้องถูกถอดออกจากรายการที่ติ๊กไว้
  void _pruneDevices() {
    if (_selectedRooms.isEmpty) return;
    final allowed = widget.controller.sources
        .devicesInRooms(_selectedRooms)
        .map((device) => device.deviceId)
        .toSet();
    _selectedDevices.removeWhere((deviceId) => !allowed.contains(deviceId));
  }

  Widget _buildDeviceSection(BuildContext context) {
    final devices = widget.controller.sources.devicesInRooms(_selectedRooms);
    final colors = Theme.of(context).colorScheme;

    return _Panel(
      title: context.tr('Air conditioners'),
      trailing: TextButton(
        onPressed: devices.isEmpty
            ? null
            : () {
                setState(() {
                  if (_selectedDevices.isEmpty) {
                    _selectedDevices.addAll(
                      devices.map((device) => device.deviceId),
                    );
                  } else {
                    _selectedDevices.clear();
                  }
                });
                widget.controller.clearPreview();
              },
        child: Text(
          _selectedDevices.isEmpty
              ? context.tr('Select all')
              : context.tr('Clear'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              'Leaving every unit unticked includes all units in the '
              'selected rooms.',
            ),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 6),
          if (devices.isEmpty)
            _EmptyHint(
              icon: Icons.ac_unit_rounded,
              title: context.tr('No air conditioners with data yet'),
              detail: context.tr(
                'Pick different rooms, or wait until a unit reports in.',
              ),
            )
          else
            for (final device in devices)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _selectedDevices.contains(device.deviceId),
                title: Text(
                  device.name.isEmpty ? device.deviceId : device.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${context.tr('Room ${device.roomNumber}')}'
                  ' · ${context.tr('${device.bucketCount} hours stored')}'
                  '${device.archived ? ' · ${context.tr('removed')}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedDevices.add(device.deviceId);
                    } else {
                      _selectedDevices.remove(device.deviceId);
                    }
                  });
                  widget.controller.clearPreview();
                },
              ),
        ],
      ),
    );
  }

  Widget _buildMetricSection(BuildContext context) {
    final metrics = widget.controller.metricsFor(_scope);
    final colors = Theme.of(context).colorScheme;

    return _Panel(
      title: context.tr('Values to include'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _scope.isHighDetail
                ? context.tr(
                    'High detail mode unlocks minimum, maximum and '
                    'runtime columns as well.',
                  )
                : context.tr(
                    'Switch to a high detail level to unlock more columns.',
                  ),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in metrics)
                if (metric.key != 'cost')
                  FilterChip(
                    label: Text(metric.labelWithUnit(isThai: _isThai)),
                    selected: _selectedMetrics.contains(metric.key),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedMetrics.add(metric.key);
                        } else if (_selectedMetrics.length > 1) {
                          _selectedMetrics.remove(metric.key);
                        }
                      });
                      widget.controller.clearPreview();
                    },
                  ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _includeCost,
            title: Text(
              context.tr('Add an estimated cost column'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${context.tr('Uses the rate')} '
              '${formatDecimal(widget.appSettingsController.electricityRate, decimalPlaces: 4)}'
              ' ${context.tr('THB per kWh')}',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
            onChanged: (value) {
              setState(() => _includeCost = value);
              widget.controller.clearPreview();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final controller = widget.controller;
    final busy = controller.isPreviewLoading || controller.isExporting;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : _preview,
            icon: controller.isPreviewLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_chart_rounded, size: 18),
            label: Text(context.tr('Preview')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : _download,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            icon: controller.isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(context.tr('Download Excel')),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final controller = widget.controller;
    final result = controller.preview;
    final colors = Theme.of(context).colorScheme;
    final metrics = controller.metrics
        .where((metric) => result.metricKeys.contains(metric.key))
        .toList();

    if (result.rows.isEmpty) {
      return _EmptyHint(
        icon: Icons.search_off_rounded,
        title: context.tr('No data in the selected range'),
        detail: context.tr(
          'Try a wider date range, or pick different rooms and units.',
        ),
      );
    }

    final visibleRows = result.rows.take(50).toList();

    return _Panel(
      title: context.tr('Preview'),
      trailing: Text(
        '${result.rows.length} ${context.tr('rows')}',
        style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 40,
              columnSpacing: 20,
              columns: [
                const DataColumn(label: Text('data')),
                const DataColumn(label: Text('time')),
                if (_scope != EnergyScope.building)
                  DataColumn(label: Text(context.tr('Room'))),
                if (_scope == EnergyScope.device)
                  DataColumn(label: Text(context.tr('Air unit'))),
                for (final metric in metrics)
                  DataColumn(
                    numeric: true,
                    label: Text(metric.labelWithUnit(isThai: _isThai)),
                  ),
              ],
              rows: [
                for (final row in visibleRows)
                  DataRow(
                    cells: [
                      DataCell(Text(row.date)),
                      DataCell(Text(row.time)),
                      if (_scope != EnergyScope.building)
                        DataCell(Text(row.roomNumber ?? '')),
                      if (_scope == EnergyScope.device)
                        DataCell(Text(row.deviceName ?? '')),
                      for (final metric in metrics)
                        DataCell(
                          Text(
                            _formatValue(row.values[metric.key], metric),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          if (result.rows.length > visibleRows.length) ...[
            const SizedBox(height: 8),
            Text(
              '${context.tr('Showing the first')} ${visibleRows.length}'
              ' ${context.tr('rows. The Excel file contains all of them.')}',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ],
          if (result.totals.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final metric in metrics)
                  if (result.totals[metric.key] != null)
                    _TotalPill(
                      label: metric.label(isThai: _isThai),
                      value:
                          '${_formatValue(result.totals[metric.key], metric)}'
                          '${metric.unit.isEmpty ? '' : ' ${metric.unit}'}',
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatValue(double? value, EnergyMetric metric) {
    if (value == null) return '-';
    return formatDecimal(value, decimalPlaces: metric.decimals);
  }
}

// ------------------------------------------------------------ ชิ้นส่วนย่อย

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      // ListTile วาดพื้นหลังกับเอฟเฟกต์กดลงบน Material ที่ใกล้ที่สุด
      // ถ้าไม่ใส่ Material ไว้ในกล่องที่มีสี ตัวกล่องจะไปบังเอฟเฟกต์นั้น
      // แล้ว Flutter รุ่นใหม่จะโยน assertion ทิ้งตั้งแต่ตอน build
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(title: title, trailing: trailing),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.scope,
    required this.selected,
    required this.onTap,
  });

  final EnergyScope scope;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.10)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? Theme.of(context).colorScheme.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            scope.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        if (scope.isHighDetail) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              context.tr('High detail'),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      scope.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
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
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 17),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
      ),
    );
  }
}

class _LiveSummaryCard extends StatelessWidget {
  const _LiveSummaryCard({
    required this.snapshot,
    required this.appSettingsController,
  });

  final EnergyLiveSnapshot snapshot;
  final AppSettingsController appSettingsController;

  @override
  Widget build(BuildContext context) {
    final kilowatts = snapshot.totalPowerWatts / 1000;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Power drawn right now'),
            style: const TextStyle(color: Color(0xFFD7E3E7), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDecimal(kilowatts, decimalPlaces: 3)} kW',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '≈ '
            '${formatDecimal(appSettingsController.calculateElectricityCost(kilowatts))}'
            ' ${context.tr('THB per hour')}',
            style: const TextStyle(color: Color(0xFFCDF1D2), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SummaryStat(
                label: context.tr('Running'),
                value: '${snapshot.runningCount}',
              ),
              _SummaryStat(
                label: context.tr('Online'),
                value: '${snapshot.onlineCount}',
              ),
              _SummaryStat(
                label: context.tr('Registered'),
                value: '${snapshot.deviceCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFD7E3E7), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _LiveReadingCard extends StatelessWidget {
  const _LiveReadingCard({required this.reading});

  final EnergyLiveReading reading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = !reading.isOnline
        ? AppColors.red
        : (reading.acRunning ? AppColors.green : AppColors.orange);
    final statusLabel = !reading.isOnline
        ? context.tr('Offline')
        : (reading.acRunning ? context.tr('Running') : context.tr('Idle'));

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reading.name.isEmpty ? reading.deviceId : reading.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${context.tr('Room ${reading.roomNumber}')}'
                      ' · ${reading.deviceId}',
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          if (!reading.pzemAvailable)
            Text(
              context.tr('The PZEM-004T on this unit is not responding.'),
              style: const TextStyle(fontSize: 11, color: AppColors.orange),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 9,
              children: [
                _Reading(
                  label: context.tr('Voltage'),
                  value: reading.voltage,
                  unit: 'V',
                  decimals: 1,
                ),
                _Reading(
                  label: context.tr('Current'),
                  value: reading.current,
                  unit: 'A',
                  decimals: 3,
                ),
                _Reading(
                  label: context.tr('Power'),
                  value: reading.powerWatts,
                  unit: 'W',
                  decimals: 1,
                ),
                _Reading(
                  label: context.tr('Meter energy'),
                  value: reading.energyKwh,
                  unit: 'kWh',
                  decimals: 3,
                ),
                _Reading(
                  label: context.tr('Frequency'),
                  value: reading.frequencyHz,
                  unit: 'Hz',
                  decimals: 2,
                ),
                _Reading(
                  label: context.tr('Power factor'),
                  value: reading.powerFactor,
                  unit: '',
                  decimals: 3,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading({
    required this.label,
    required this.value,
    required this.unit,
    required this.decimals,
  });

  final String label;
  final double? value;
  final String unit;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = value == null
        ? '-'
        : formatDecimal(value!, decimalPlaces: decimals);

    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 1),
          Text(
            unit.isEmpty ? text : '$text $unit',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalPill extends StatelessWidget {
  const _TotalPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.red,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: colors.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
