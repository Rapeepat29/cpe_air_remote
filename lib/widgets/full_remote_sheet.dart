import '../localization/localized_material.dart';

import '../models/air_conditioner.dart';
import '../theme/app_theme.dart';

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
                            ? (_) => setState(() => air.mode = mode)
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
            if (air.supportsAdditionalFunctions) ...[
              const SizedBox(height: 12),
              _Section(
                title: context.tr('Additional functions'),
                child: Column(
                  children: [
                    _FeatureSwitch(
                      title: context.tr('Horizontal Swing'),
                      value: air.horizontalSwing,
                      onChanged: (value) {
                        setState(() => air.horizontalSwing = value);
                      },
                    ),
                    _FeatureSwitch(
                      title: context.tr('Eco'),
                      value: air.eco,
                      onChanged: (value) => setState(() => air.eco = value),
                    ),
                    _FeatureSwitch(
                      title: context.tr('Turbo'),
                      value: air.turbo,
                      onChanged: (value) => setState(() => air.turbo = value),
                    ),
                    _FeatureSwitch(
                      title: context.tr('Sleep'),
                      value: air.sleep,
                      onChanged: (value) => setState(() => air.sleep = value),
                    ),
                    _FeatureSwitch(
                      title: context.tr('Quiet'),
                      value: air.quiet,
                      onChanged: (value) => setState(() => air.quiet = value),
                    ),
                    _FeatureSwitch(
                      title: context.tr('Display Light'),
                      value: air.displayLight,
                      onChanged: (value) {
                        setState(() => air.displayLight = value);
                      },
                    ),
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
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (context) {
        const options = <int>[30, 60, 120, 240, 360, 480];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options
                      .map(
                        (minutes) => ActionChip(
                          label: Text(_timerText(context, minutes)),
                          onPressed: () {
                            Navigator.of(context).pop(minutes);
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(-1),
                  child: Text(context.tr('Clear Timer')),
                ),
              ],
            ),
          ),
        );
      },
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

String _timerText(BuildContext context, int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '$remainder ${context.tr('min')}';
  if (remainder == 0) return '$hours ${context.tr('hr')}';
  return '$hours ${context.tr('hr')} $remainder ${context.tr('min')}';
}
