import 'dart:async';

import '../localization/localized_material.dart';

import '../models/air_conditioner.dart';
import '../theme/app_theme.dart';
import 'auto_off_countdown.dart' show formatCountdown;
import 'full_remote_sheet.dart';

/// การ์ดแอร์หนึ่งเครื่องในหน้าห้อง
///
/// มีสามหน้าตาตามสถานะ
/// - เชื่อมต่อแล้วและเปิดอยู่: แถบอุณหภูมิมีสีเน้น ปุ่มแรกคือ "ปิดเครื่อง"
/// - เชื่อมต่อแล้วแต่ปิดอยู่: เมนูเหมือนกันทุกอย่างแต่จางลง ปุ่ม "เปิดเครื่อง" เด่นปุ่มเดียว
/// - ยังไม่เชื่อมต่อ MQTT: ไม่แสดงปุ่มสั่งงาน บอกสาเหตุ และมีทางแก้ให้กด
///
/// ระหว่างนับถอยหลังปิดอัตโนมัติ จะมีป้ายเวลาเล็ก ๆ แทนสถานะที่มุมขวาบน
class AirControlCard extends StatefulWidget {
  const AirControlCard({
    required this.air,
    required this.isAdmin,
    required this.onCommand,
    required this.onRename,
    required this.onReconfigure,
    required this.onDelete,
    this.onRetry,
    this.roomAutoOffDeadline,
    this.roomAutoOffAttempts = 0,
    super.key,
  });

  final AirConditioner air;
  final bool isAdmin;
  final Future<void> Function(AirConditioner air) onCommand;
  final Future<void> Function(String name) onRename;
  final VoidCallback onReconfigure;
  final VoidCallback onDelete;

  /// ดึงสถานะใหม่ ใช้กับปุ่ม "ลองอีกครั้ง" ตอนเครื่องยังไม่เชื่อมต่อ
  final VoidCallback? onRetry;

  /// นาฬิกาปิดอัตโนมัติของทั้งห้อง ใช้เมื่อเครื่องนี้ไม่มีนาฬิกาของตัวเอง
  final DateTime? roomAutoOffDeadline;
  final int roomAutoOffAttempts;

  @override
  State<AirControlCard> createState() => _AirControlCardState();
}

class _AirControlCardState extends State<AirControlCard> {
  bool _busy = false;

  AirConditioner get air => widget.air;

  bool get _canControl => !_busy && air.canControl;

  /// นาฬิกาปิดอัตโนมัติที่ใช้กับเครื่องนี้ (ของเครื่องก่อน แล้วค่อยของห้อง)
  DateTime? get _deadline {
    if (!air.isOn) return null;
    return air.autoOffDeadlineAt ?? widget.roomAutoOffDeadline;
  }

  int get _attempts => air.autoOffDeadlineAt != null
      ? air.autoOffAttempts
      : widget.roomAutoOffAttempts;

  @override
  Widget build(BuildContext context) {
    if (!air.canControl) return _buildDisconnected(context);

    final colors = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final on = air.isOn;
    final deadline = _deadline;
    final sending = deadline != null && _attempts > 0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ชื่อ สถานะ อุณหภูมิ
          Container(
            color: on ? palette.accentSoft : null,
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        air.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (deadline != null && !sending)
                      _CountdownChip(deadline: deadline)
                    else
                      Text(
                        '● ${context.tr(on ? 'Running now' : 'Switched off')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: on ? palette.accent : colors.onSurfaceVariant,
                        ),
                      ),
                    if (widget.isAdmin)
                      _OptionsMenu(
                        onRename: _showRenameDialog,
                        onReconfigure: widget.onReconfigure,
                        onDelete: widget.onDelete,
                      )
                    else
                      const SizedBox(width: 12),
                  ],
                ),
                Opacity(
                  opacity: on ? 1 : 0.55,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundButton(
                        tooltip: context.tr('Lower temperature'),
                        icon: Icons.remove_rounded,
                        onPressed:
                            _canControl &&
                                air.temperature > air.minimumTemperature
                            ? () => _change((d) => d.temperature -= 1)
                            : null,
                      ),
                      const SizedBox(width: 22),
                      Column(
                        children: [
                          Text(
                            '${air.temperature}°',
                            style: const TextStyle(
                              fontSize: 44,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${context.tr(air.mode.label)} · '
                            '${context.tr('Fan')} '
                            '${context.tr(air.fanSpeedLabel(air.fanSpeed))}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 22),
                      _RoundButton(
                        tooltip: context.tr('Raise temperature'),
                        icon: Icons.add_rounded,
                        onPressed:
                            _canControl &&
                                air.temperature < air.maximumTemperature
                            ? () => _change((d) => d.temperature += 1)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ระบบกำลังยิงคำสั่งปิดอัตโนมัติ (หลังนับถอยหลังครบ)
          if (sending)
            _InfoLine(
              icon: Icons.send_rounded,
              color: palette.danger,
              text: context.tr('Sending the off command'),
              trailing: '$_attempts/5',
            ),

          // กำลังไฟ
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Power now'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (air.pzemAvailable)
                        Text(
                          '${air.voltage.toStringAsFixed(0)} V · '
                          '${air.current.toStringAsFixed(2)} A · '
                          '${context.tr('Accumulated')} '
                          '${air.energyKwh.toStringAsFixed(3)} kWh',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: air.pzemAvailable
                            ? air.power.toStringAsFixed(0)
                            : '–',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: on ? colors.onSurface : colors.onSurfaceVariant,
                        ),
                      ),
                      TextSpan(
                        text: ' W',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // แถวปุ่มคำสั่ง
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.outlineVariant)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ActionButton(
                    key: Key('air-${air.id}-power'),
                    icon: Icons.power_settings_new_rounded,
                    label: context.tr(on ? 'Turn off' : 'Turn on'),
                    highlighted: !on,
                    accent: on,
                    busy: _busy,
                    onPressed: _canControl
                        ? () => _change((d) => d.isOn = !on)
                        : null,
                  ),
                  _ActionButton(
                    icon: Icons.ac_unit_rounded,
                    label: context.tr('Mode'),
                    onPressed: _canControl && air.supportedModes.length > 1
                        ? () => _change((d) {
                            final list = d.supportedModes;
                            d.mode =
                                list[(list.indexOf(d.mode) + 1) % list.length];
                          })
                        : null,
                  ),
                  _ActionButton(
                    icon: Icons.air_rounded,
                    label: context.tr('Fan'),
                    onPressed: _canControl
                        ? () => _change((d) {
                            final list = d.supportedFanSpeeds;
                            d.fanSpeed = list[
                                (list.indexOf(d.fanSpeed) + 1) % list.length];
                          })
                        : null,
                  ),
                  _ActionButton(
                    icon: Icons.swap_vert_rounded,
                    label: context.tr('Swing'),
                    onPressed: _canControl
                        ? () => _change((d) {
                            final list = d.supportedSwingModes;
                            d.verticalSwing = list[
                                (list.indexOf(d.verticalSwing) + 1) %
                                    list.length];
                          })
                        : null,
                  ),
                  _ActionButton(
                    key: Key('air-${air.id}-full-remote'),
                    icon: Icons.more_horiz_rounded,
                    label: context.tr('More'),
                    divider: false,
                    onPressed: _canControl ? _openRemote : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// เครื่องที่ยังสั่งงานไม่ได้: ไม่มีปุ่มคำสั่ง บอกสาเหตุ และทางแก้
  Widget _buildDisconnected(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final waiting = !air.isProvisioned;

    return CustomPaint(
      painter: _DashedBorderPainter(color: colors.outline, radius: 16),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    air.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: palette.warn.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    context.tr(waiting ? 'Awaiting confirmation' : 'Offline'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.warn,
                    ),
                  ),
                ),
                if (widget.isAdmin)
                  _OptionsMenu(
                    onRename: _showRenameDialog,
                    onReconfigure: widget.onReconfigure,
                    onDelete: widget.onDelete,
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    waiting
                        ? Icons.hourglass_empty_rounded
                        : Icons.wifi_off_rounded,
                    size: 26,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            waiting
                                ? 'Waiting for MQTT activation'
                                : 'Not connected to MQTT',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr(
                            'Commands and power readings are unavailable. '
                            'Check the ESP32 power supply and Wi-Fi signal.',
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  if (widget.isAdmin) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onReconfigure,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: palette.accent,
                          side: BorderSide(color: palette.accent),
                        ),
                        child: Text(context.tr('Set up again via Bluetooth')),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton(
                    onPressed: widget.onRetry,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(context.tr('Try again')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

/// ป้ายนับถอยหลังปิดอัตโนมัติ: มีแค่ไอคอนนาฬิกากับเวลา เดินเองทุกวินาที
class _CountdownChip extends StatefulWidget {
  const _CountdownChip({required this.deadline});

  final DateTime deadline;

  @override
  State<_CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<_CountdownChip> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warn = AppPalette.of(context).warn;
    final seconds = widget.deadline.difference(DateTime.now()).inSeconds;
    final time = formatCountdown(seconds);

    return Semantics(
      label: '${context.tr('Empty room · switching off in')} $time',
      excludeSemantics: true,
      child: Container(
        key: const Key('air-auto-off-countdown'),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: warn.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 14, color: warn),
            const SizedBox(width: 5),
            Text(
              time,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: warn,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.color,
    required this.text,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 24,
      style: IconButton.styleFrom(
        fixedSize: const Size(52, 52),
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.outline),
      ),
      icon: Icon(icon),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
    this.accent = false,
    this.busy = false,
    this.divider = true,
    super.key,
  });

  /// เส้นคั่นทางขวา ปุ่มสุดท้ายไม่ต้องมี
  final bool divider;

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// พื้นสีเต็ม ใช้กับปุ่ม "เปิดเครื่อง" ตอนเครื่องปิดอยู่
  final bool highlighted;

  /// ตัวหนังสือสีเน้น ใช้กับปุ่ม "ปิดเครื่อง" ตอนเครื่องเปิดอยู่
  final bool accent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final enabled = onPressed != null;
    final ink = highlighted
        ? colors.onPrimary
        : accent
        ? palette.accent
        : colors.onSurface;

    return Expanded(
      child: Material(
        color: highlighted ? colors.primary : Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Opacity(
            opacity: enabled || highlighted ? 1 : 0.45,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                border: divider
                    ? Border(right: BorderSide(color: colors.outlineVariant))
                    : null,
              ),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ink,
                      ),
                    )
                  else
                    Icon(icon, size: 20, color: ink),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: highlighted || accent
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionsMenu extends StatelessWidget {
  const _OptionsMenu({
    required this.onRename,
    required this.onReconfigure,
    required this.onDelete,
  });

  final VoidCallback onRename;
  final VoidCallback onReconfigure;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: context.tr('Options'),
      onSelected: (value) {
        if (value == 'rename') onRename();
        if (value == 'reconfigure') onReconfigure();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: Text(context.tr('Rename'))),
        PopupMenuItem(
          value: 'reconfigure',
          child: Text(context.tr('Set up again via Bluetooth')),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            context.tr('Remove Unit'),
            style: TextStyle(color: AppPalette.of(context).danger),
          ),
        ),
      ],
    );
  }
}

/// เส้นประรอบการ์ด ใช้กับเครื่องที่ยังไม่เชื่อมต่อ ให้ต่างจากการ์ดที่ใช้งานได้
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.5),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
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
