import '../localization/localized_material.dart';

import '../controllers/app_settings_controller.dart';
import '../models/system_alert.dart';
import '../theme/app_theme.dart';
import '../utils/alert_preferences.dart';

/// หน้าตั้งค่าการแจ้งเตือนแยกตามชนิด
///
/// แยกออกมาจากหน้าตั้งค่าหลักเพราะการ์ดสามใบกินพื้นที่กว่า 500px
/// หน้าตั้งค่าหลักควรกวาดตาผ่านได้เร็ว ส่วนหน้านี้มีที่ให้อธิบายเต็ม ๆ
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
      appBar: AppBar(title: Text(context.tr('Alerts by type'))),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              Text(
                context.tr(
                  'Choose what appears in the app and what alerts this '
                  'phone.',
                ),
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              for (final kind in AlertPreferences.configurableKinds) ...[
                _AlertKindCard(controller: controller, kind: kind),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              _FootNote(
                text: context.tr(
                  'Turning off the in-app list also stops the alert from '
                  'reaching this phone, because there would be nothing to '
                  'open.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FootNote extends StatelessWidget {
  const _FootNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _AlertKindCard extends StatelessWidget {
  const _AlertKindCard({required this.controller, required this.kind});

  final AppSettingsController controller;
  final SystemAlertKind kind;

  ({String title, IconData icon, Color color}) get _look => switch (kind) {
    SystemAlertKind.outsideScheduleOccupied => (
      title: 'Running outside class hours',
      icon: Icons.schedule_rounded,
      color: AppColors.orange,
    ),
    SystemAlertKind.autoOffSucceeded => (
      title: 'Air conditioner switched off',
      icon: Icons.power_settings_new_rounded,
      color: AppColors.green,
    ),
    SystemAlertKind.autoOffFailed => (
      title: 'Automatic shutdown failed',
      icon: Icons.error_outline_rounded,
      color: AppColors.red,
    ),
    SystemAlertKind.unknown => (
      title: 'System event',
      icon: Icons.notifications_rounded,
      color: AppColors.blue,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final look = _look;
    final channels = controller.alertPreferences.channelsFor(kind);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SettingsIcon(icon: look.icon, color: look.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(look.title),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(kind.message),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: Key('alert-${kind.name}-in-app'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: channels.inApp,
              onChanged: (value) => controller.setAlertChannels(
                kind,
                channels.copyWith(inApp: value),
              ),
              title: Text(
                context.tr('Show in the app'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            SwitchListTile(
              key: Key('alert-${kind.name}-push'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              // ปิดรายการในแอปแล้วก็ไม่ควรเด้ง เพราะจะกดดูต่อไม่ได้
              value: channels.inApp && channels.push,
              onChanged: channels.inApp
                  ? (value) => controller.setAlertChannels(
                      kind,
                      channels.copyWith(push: value),
                    )
                  : null,
              title: Text(
                context.tr('Alert me on this phone'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
