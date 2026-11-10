import 'package:flutter/cupertino.dart' show CupertinoPicker;

import '../localization/localized_material.dart';

import '../models/air_conditioner.dart';
import '../theme/app_theme.dart';
import 'air_control_badge.dart';

Future<AirConditioner?> showFullRemoteSheet(
  BuildContext context,
  AirConditioner air,
) {
  return showModalBottomSheet<AirConditioner>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (_) => FullRemoteSheet(air: air.editableCopy()),
  );
}

class FullRemoteSheet extends StatefulWidget {
  const FullRemoteSheet({required this.air, super.key});

  final AirConditioner air;

  @override
  State<FullRemoteSheet> createState() => _FullRemoteSheetState();
}

class _FullRemoteSheetState extends State<FullRemoteSheet> {
  AirConditioner get air => widget.air;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.65,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${context.tr('Full Remote')} · ${air.name}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                AirControlBadge(protocol: air.protocol),
              ],
            ),
            if (air.isWired) ...[
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'This unit is controlled through its cable, so only the functions of the Daikin wall remote are available.',
                ),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            _RemoteDisplay(
              air: air,
              onPower: () => setState(() => air.isOn = !air.isOn),
              onDecrease: () => setState(() {
                air.temperature =
                    (air.temperature - 1)
                        .clamp(
                          air.minimumTemperature,
                          air.maximumTemperature,
                        )
                        .toInt();
              }),
              onIncrease: () => setState(() {
                air.temperature =
                    (air.temperature + 1)
                        .clamp(
                          air.minimumTemperature,
                          air.maximumTemperature,
                        )
                        .toInt();
              }),
            ),
            const SizedBox(height: 14),
            _Section(
              title: context.tr('Operating mode'),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: air.supportedModes
                    .map(
                      (mode) => ChoiceChip(
                        label: Text(context.tr(mode.label)),
                        selected: air.mode == mode,
                        onSelected: air.supportedModes.length > 1
                            ? (_) => setState(() {
                                air.mode = mode;
                                if (air.isWired) air.normalizeForProtocol();
                              })
                            : null,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: context.tr('Fan speed'),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: air.supportedFanSpeeds
                    .map(
                      (speed) => ChoiceChip(
                        label: Text(context.tr(air.fanSpeedLabel(speed))),
                        selected: air.fanSpeed == speed,
                        onSelected: (_) {
                          setState(() => air.fanSpeed = speed);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: context.tr('Vertical swing'),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: air.supportedSwingModes
                    .map(
                      (swing) => ChoiceChip(
                        label: Text(context.tr(swing.label)),
                        selected: air.verticalSwing == swing,
                        onSelected: (_) {
                          setState(() => air.verticalSwing = swing);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            if (air.supportsHorizontalSwing ||
                air.supportsEco ||
                air.supportsTurbo ||
                air.supportsSleep ||
                air.supportsQuiet ||
                air.supportsDisplayLight ||
                air.supportsClean) ...[
              const SizedBox(height: 12),
              _Section(
                title: context.tr('Additional functions'),
                child: Column(
                  children: [
                    if (air.supportsHorizontalSwing)
                      _FeatureSwitch(
                        title: context.tr('Horizontal Swing'),
                        value: air.horizontalSwing,
                        onChanged: (value) {
                          setState(() => air.horizontalSwing = value);
                        },
                      ),
                    if (air.supportsEco)
                      _FeatureSwitch(
                        title: context.tr('Eco'),
                        value: air.eco,
                        onChanged: (value) => setState(() => air.eco = value),
                      ),
                    if (air.supportsTurbo)
                      _FeatureSwitch(
                        title: context.tr('Turbo'),
                        value: air.turbo,
                        onChanged: (value) => setState(() => air.turbo = value),
                      ),
                    if (air.supportsSleep)
                      _FeatureSwitch(
                        title: context.tr('Sleep'),
                        value: air.sleep,
                        onChanged: (value) => setState(() => air.sleep = value),
                      ),
                    if (air.supportsQuiet)
                      _FeatureSwitch(
                        title: context.tr('Quiet'),
                        value: air.quiet,
                        onChanged: (value) => setState(() => air.quiet = value),
                      ),
                    if (air.supportsDisplayLight)
                      _FeatureSwitch(
                        title: context.tr('Display Light'),
                        value: air.displayLight,
                        onChanged: (value) {
                          setState(() => air.displayLight = value);
                        },
                      ),
                    if (air.supportsClean)
                      _FeatureSwitch(
                        title: context.tr('Clean'),
                        value: air.clean,
                        onChanged: (value) => setState(() => air.clean = value),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _Section(
              title: context.tr('Timer'),
              child: Column(
                children: [
                  _TimerTile(
                    label: context.tr('Turn on in'),
                    minutes: air.timerOnMinutes,
                    onTap: () => _pickTimer(isOn: true),
                  ),
                  _TimerTile(
                    label: context.tr('Turn off in'),
                    minutes: air.timerOffMinutes,
                    onTap: () => _pickTimer(isOn: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('send-mqtt-command-button'),
              onPressed: () => Navigator.of(context).pop(air),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.send_rounded),
              label: Text(context.tr('Send command via MQTT')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTimer({required bool isOn}) async {
    final selected = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (context) => _TimerPickerSheet(
        title: context.tr(isOn ? 'Set Auto-On Timer' : 'Set Auto-Off Timer'),
        initialMinutes: isOn ? air.timerOnMinutes : air.timerOffMinutes,
      ),
    );
    if (selected == null) return;
    setState(() {
      final value = selected == -1 ? null : selected;
      if (isOn) {
        air.timerOnMinutes = value;
      } else {
        air.timerOffMinutes = value;
      }
    });
  }
}

class _RemoteDisplay extends StatelessWidget {
  const _RemoteDisplay({
    required this.air,
    required this.onPower,
    required this.onDecrease,
    required this.onIncrease,
  });

  final AirConditioner air;
  final VoidCallback onPower;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: air.isOn ? AppColors.primary : const Color(0xFF8F9BA0),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                air.isOn ? context.tr('ON') : context.tr('OFF'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              IconButton.filled(
                onPressed: onPower,
                icon: const Icon(Icons.power_settings_new_rounded),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: air.isOn &&
                        air.temperature > air.minimumTemperature
                    ? onDecrease
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 24),
              Text(
                '${air.temperature}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(width: 24),
              IconButton.filledTonal(
                onPressed: air.isOn &&
                        air.temperature < air.maximumTemperature
                    ? onIncrease
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _FeatureSwitch extends StatelessWidget {
  const _FeatureSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr(title)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _TimerTile extends StatelessWidget {
  const _TimerTile({
    required this.label,
    required this.minutes,
    required this.onTap,
  });

  final String label;
  final int? minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        minutes == null ? context.tr('Not set') : _timerText(context, minutes!),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// แผ่นเลือกเวลาตั้งเวลาเปิด/ปิด: หมุนเลือกชั่วโมงกับนาทีเองได้ (1 นาที ถึง 23 ชม. 59 นาที)
/// คืนค่าเป็นจำนวนนาที, -1 = ล้างการตั้งเวลา, null = ปิดแผ่นโดยไม่เปลี่ยน
class _TimerPickerSheet extends StatefulWidget {
  const _TimerPickerSheet({required this.title, this.initialMinutes});

  final String title;
  final int? initialMinutes;

  @override
  State<_TimerPickerSheet> createState() => _TimerPickerSheetState();
}

class _TimerPickerSheetState extends State<_TimerPickerSheet> {
  static const _quickOptions = <int>[30, 60, 120, 240, 360, 480];
  static const _maxMinutes = 23 * 60 + 59;

  late int _hours;
  late int _minutes;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  int get _total => _hours * 60 + _minutes;

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialMinutes ?? 30).clamp(1, _maxMinutes).toInt();
    _hours = initial ~/ 60;
    _minutes = initial % 60;
    _hourController = FixedExtentScrollController(initialItem: _hours);
    _minuteController = FixedExtentScrollController(initialItem: _minutes);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _jumpTo(int totalMinutes) {
    const duration = Duration(milliseconds: 250);
    _hourController.animateToItem(
      totalMinutes ~/ 60,
      duration: duration,
      curve: Curves.easeOut,
    );
    _minuteController.animateToItem(
      totalMinutes % 60,
      duration: duration,
      curve: Curves.easeOut,
    );
  }

  Widget _wheel({
    required Key key,
    required FixedExtentScrollController controller,
    required int count,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 160,
            child: CupertinoPicker(
              key: key,
              scrollController: controller,
              itemExtent: 40,
              onSelectedItemChanged: onChanged,
              children: List<Widget>.generate(
                count,
                (index) => Center(
                  child: Text(
                    '$index',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(unit, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _wheel(
                  key: const Key('timer-hours-wheel'),
                  controller: _hourController,
                  count: 24,
                  unit: context.tr('hours'),
                  onChanged: (value) => setState(() => _hours = value),
                ),
                _wheel(
                  key: const Key('timer-minutes-wheel'),
                  controller: _minuteController,
                  count: 60,
                  unit: context.tr('minutes'),
                  onChanged: (value) => setState(() => _minutes = value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickOptions
                  .map(
                    (minutes) => ActionChip(
                      label: Text(_timerText(context, minutes)),
                      onPressed: () => _jumpTo(minutes),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: const Key('timer-confirm-button'),
              onPressed: _total < 1
                  ? null
                  : () => Navigator.of(context).pop(_total),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                _total < 1
                    ? context.tr('Choose a time')
                    : '${context.tr('Set Timer')} ${_timerText(context, _total)}',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(-1),
              child: Text(context.tr('Clear Timer')),
            ),
          ],
        ),
      ),
    );
  }
}

String _timerText(BuildContext context, int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '$remainder ${context.tr('min')}';
  if (remainder == 0) return '$hours ${context.tr('hr')}';
  return '$hours ${context.tr('hr')} $remainder ${context.tr('min')}';
}
