import '../localization/localized_material.dart';

import '../models/air_conditioner.dart';
import '../theme/app_theme.dart';
import 'full_remote_sheet.dart';

class AirControlCard extends StatefulWidget {
  const AirControlCard({
    required this.air,
    required this.isAdmin,
    required this.onCommand,
    required this.onRename,
    required this.onReconfigure,
    required this.onDelete,
    super.key,
  });

  final AirConditioner air;
  final bool isAdmin;
  final Future<void> Function(AirConditioner air) onCommand;
  final Future<void> Function(String name) onRename;
  final VoidCallback onReconfigure;
  final VoidCallback onDelete;

  @override
  State<AirControlCard> createState() => _AirControlCardState();
}

class _AirControlCardState extends State<AirControlCard> {
  bool _busy = false;

  AirConditioner get air => widget.air;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onlineColor = air.isOnline ? AppColors.green : AppColors.red;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.ac_unit_rounded,
                color: AppColors.primary,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      air.name,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      air.isProvisioned
                          ? context.tr(air.isOnline ? 'Online' : 'Offline')
                          : context.tr('Waiting for MQTT activation'),
                      style: TextStyle(
                        color: air.isProvisioned
                            ? onlineColor
                            : AppColors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isAdmin)
                PopupMenuButton<String>(
                  tooltip: context.tr('Options'),
                  onSelected: (value) {
                    if (value == 'rename') {
                      _showRenameDialog();
                    } else if (value == 'reconfigure') {
                      widget.onReconfigure();
                    } else if (value == 'delete') {
                      widget.onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(context.tr('Rename')),
                    ),
                    PopupMenuItem(
                      value: 'reconfigure',
                      child: Text(context.tr('Reconfigure via Bluetooth')),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        context.tr('Remove Unit'),
                        style: const TextStyle(color: AppColors.red),
                      ),
                    ),
                  ],
                ),
              Switch(
                value: air.isOn,
                activeThumbColor: AppColors.green,
                onChanged: _canControl
                    ? (value) => _change((draft) => draft.isOn = value)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 9),
          _MeasuredStatus(air: air),
          Divider(color: colors.outlineVariant, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _canControl &&
                        air.temperature > air.minimumTemperature
                    ? () => _change((draft) => draft.temperature -= 1)
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 22),
              Text(
                '${air.temperature}°C',
                style: const TextStyle(
                  fontSize: 33,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 22),
              IconButton.filledTonal(
                onPressed: _canControl &&
                        air.temperature < air.maximumTemperature
                    ? () => _change((draft) => draft.temperature += 1)
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickControl(
                  title: context.tr('MODE'),
                  value: air.mode.label,
                  icon: Icons.mode_fan_off_rounded,
                  enabled: _canControl && air.supportedModes.length > 1,
                  onTap: () => _change((draft) {
                    final modes = draft.supportedModes;
                    final index = modes.indexOf(draft.mode);
                    draft.mode =
                        modes[(index + 1) % modes.length];
                  }),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _QuickControl(
                  title: context.tr('FAN'),
                  value: air.fanSpeedLabel(air.fanSpeed),
                  icon: Icons.air_rounded,
                  enabled: _canControl,
                  onTap: () => _change((draft) {
                    final speeds = draft.supportedFanSpeeds;
                    final index = speeds.indexOf(draft.fanSpeed);
                    draft.fanSpeed =
                        speeds[(index + 1) % speeds.length];
                  }),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _QuickControl(
                  title: context.tr('SWING'),
                  value: air.verticalSwing.label,
                  icon: Icons.swap_vert_rounded,
                  enabled: _canControl,
                  onTap: () => _change((draft) {
                    final swings = draft.supportedSwingModes;
                    final index = swings.indexOf(
                      draft.verticalSwing,
                    );
                    draft.verticalSwing =
                        swings[(index + 1) % swings.length];
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                _EnergyValue(
                  value: air.pzemAvailable
                      ? air.voltage.toStringAsFixed(0)
                      : '--',
                  unit: 'V',
                  label: context.tr('Voltage'),
                ),
                _EnergyValue(
                  value: air.pzemAvailable
                      ? air.current.toStringAsFixed(2)
                      : '--',
                  unit: 'A',
                  label: context.tr('Current'),
                ),
                _EnergyValue(
                  value: air.pzemAvailable
                      ? air.power.toStringAsFixed(0)
                      : '--',
                  unit: 'W',
                  label: context.tr('Power'),
                ),
              ],
            ),
          ),
          if (air.pzemAvailable) ...[
            const SizedBox(height: 7),
            Text(
              '${context.tr('Energy')} ${air.energyKwh.toStringAsFixed(3)} kWh'
              '  •  ${air.frequencyHz.toStringAsFixed(1)} Hz'
              '  •  PF ${air.powerFactor.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 11),
          OutlinedButton.icon(
            onPressed: _canControl ? _openRemote : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(43),
            ),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.settings_remote_rounded),
            label: Text(context.tr('Open Full Remote')),
          ),
        ],
      ),
    );
  }

  bool get _canControl => !_busy && air.canControl;

  Future<void> _change(void Function(AirConditioner draft) mutation) async {
    final draft = air.editableCopy();
    mutation(draft);
    await _sendDraft(draft);
  }

  Future<void> _openRemote() async {
    final draft = await showFullRemoteSheet(context, air);
    if (draft != null) await _sendDraft(draft);
  }

  Future<void> _sendDraft(AirConditioner draft) async {
    draft.normalizeForProtocol();
    setState(() => _busy = true);
    try {
      await widget.onCommand(draft);
      if (!mounted) return;
      setState(() => air.copyStateFrom(draft));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.tr('MQTT command sent successfully')),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRenameDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initialName: air.name),
    );
    if (name == null || !mounted) return;
    try {
      await widget.onRename(name);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _MeasuredStatus extends StatelessWidget {
  const _MeasuredStatus({required this.air});

  final AirConditioner air;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, label, color) = !air.pzemAvailable
        ? (
            Icons.electrical_services_rounded,
            'PZEM meter unavailable',
            colors.onSurfaceVariant,
          )
        : air.outsideSchedule
        ? (
            Icons.warning_amber_rounded,
            'Air conditioner running outside schedule',
            AppColors.red,
          )
        : air.isRunning
        ? (
            Icons.check_circle_rounded,
            'Air conditioner is running',
            AppColors.green,
          )
        : (
            Icons.pause_circle_outline_rounded,
            'Air conditioner is stopped',
            colors.onSurfaceVariant,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr(label),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickControl extends StatelessWidget {
  const _QuickControl({
    required this.title,
    required this.value,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              Text(
                title,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnergyValue extends StatelessWidget {
  const _EnergyValue({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value $unit',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}


/// Dialog เปลี่ยนชื่อที่เป็นเจ้าของ TextEditingController ของตัวเอง
///
/// ของเดิมสร้าง controller ไว้นอก dialog แล้วสั่ง dispose ทันทีที่ showDialog
/// คืนค่ากลับมา แต่ตอนนั้น dialog ยังเล่นอนิเมชันปิดอยู่ TextField จึงยังผูกกับ
/// controller ที่ถูกคืนหน่วยความจำไปแล้ว Flutter เลยโยน assertion
/// `_dependents.isEmpty` ให้ State ของ dialog เป็นเจ้าของแทน controller จะถูก
/// ปล่อยตอน dispose ของตัวเองซึ่งเกิดหลัง dialog หายไปจากจอจริง ๆ
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Rename Air Conditioner')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: context.tr('Air Conditioner Name'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.tr('Save')),
        ),
      ],
    );
  }
}
