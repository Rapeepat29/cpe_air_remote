import '../localization/localized_material.dart';

import '../controllers/app_settings_controller.dart';
import '../models/system_alert.dart';
import '../theme/app_theme.dart';
import '../utils/alert_preferences.dart';

/// หน้าตั้งค่าการแจ้งเตือน
///
/// หน้าตาแบบเดียวกับหน้าตั้งค่าแอป (รายการเรียบ) สวิตช์หลักอยู่บนสุด
/// แล้วตามด้วยสวิตช์รายประเภท ปิดสวิตช์หลักแล้วรายประเภทจะจางลงและกดไม่ได้
/// แต่ค่าที่เลือกไว้ยังจำไว้ ในแอปแสดงรายการแจ้งเตือนครบทุกประเภทเสมอ
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({
    required this.controller,
    super.key,
  });

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text(context.tr('Notification settings'))),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final preferences = controller.alertPreferences;

          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const SizedBox(height: 12),
              _FlatGroup(
                children: [
                  _SwitchRow(
                    switchKey: const Key('notifications-master-switch-page'),
                    icon: preferences.enabled
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_off_outlined,
                    iconColor: AppPalette.of(context).accent,
                    title: context.tr('Allow notifications'),
                    subtitle: context.tr(
                      'Receive notifications on this device for the types '
                      'selected below.',
                    ),
                    value: preferences.enabled,
                    onChanged: controller.setNotificationsEnabled,
                  ),
                ],
              ),
              const _SectionLabel('Notification types'),
              _FlatGroup(
                children: [
                  for (final kind in AlertPreferences.configurableKinds)
                    _AlertKindRow(
                      controller: controller,
                      kind: kind,
                      masterEnabled: preferences.enabled,
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  context.tr('All notifications remain available in the app.'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AlertKindRow extends StatelessWidget {
  const _AlertKindRow({
    required this.controller,
    required this.kind,
    required this.masterEnabled,
  });

  final AppSettingsController controller;
  final SystemAlertKind kind;
  final bool masterEnabled;

  ({String title, IconData icon}) get _look => switch (kind) {
    SystemAlertKind.outsideScheduleOccupied => (
      title: 'Running outside class hours',
      icon: Icons.schedule_rounded,
    ),
    SystemAlertKind.autoOffSucceeded => (
      title: 'Air conditioner switched off',
      icon: Icons.power_settings_new_rounded,
    ),
    SystemAlertKind.autoOffFailed => (
      title: 'Automatic shutdown failed',
      icon: Icons.error_outline_rounded,
    ),
    SystemAlertKind.unknown => (
      title: 'System event',
      icon: Icons.notifications_none_rounded,
    ),
  };

  Color _iconColor(AppPalette palette) => switch (kind) {
    SystemAlertKind.outsideScheduleOccupied => palette.warn,
    SystemAlertKind.autoOffSucceeded => palette.accent,
    SystemAlertKind.autoOffFailed => palette.danger,
    SystemAlertKind.unknown => palette.info,
  };

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final channels = controller.alertPreferences.channelsFor(kind);

    return Opacity(
      // สวิตช์หลักปิดอยู่ ให้รายประเภทจางลง จะได้เห็นว่าตอนนี้ไม่มีผล
      opacity: masterEnabled ? 1 : 0.5,
      child: _SwitchRow(
        switchKey: Key('alert-${kind.name}-push'),
        icon: look.icon,
        iconColor: _iconColor(AppPalette.of(context)),
        title: context.tr(look.title),
        subtitle: context.tr(kind.message),
        value: channels.push,
        onChanged: masterEnabled
            ? (value) => controller.setAlertChannels(
                kind,
                channels.copyWith(push: value),
              )
            : null,
      ),
    );
  }
}

/// แถวมาตรฐานของหน้านี้: ไอคอนเส้น ชื่อ คำอธิบาย และสวิตช์ทางขวา
///
/// แตะที่ไหนของแถวก็สลับสวิตช์ได้ ไม่ต้องเล็งที่ตัวสวิตช์
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.switchKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(key: switchKey, value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// กลุ่มของแถว: เส้นบนล่าง และเส้นคั่นระหว่างแถว (แบบเดียวกับหน้าตั้งค่าแอป)
class _FlatGroup extends StatelessWidget {
  const _FlatGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final line = BorderSide(color: colors.outlineVariant);

    return Material(
      color: colors.surface,
      shape: Border(top: line, bottom: line),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: line.color),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Text(
        context.tr(label),
        style: TextStyle(
          color: AppPalette.of(context).accent,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
