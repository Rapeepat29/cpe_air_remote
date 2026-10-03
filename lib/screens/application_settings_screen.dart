import '../localization/localized_material.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/system_settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/alert_preferences.dart';
import 'notification_settings_screen.dart';

class ApplicationSettingsScreen extends StatelessWidget {
  const ApplicationSettingsScreen({
    required this.controller,
    required this.systemSettingsController,
    required this.isAdmin,
    super.key,
  });

  final AppSettingsController controller;
  final SystemSettingsController systemSettingsController;

  /// คนที่ไม่ใช่แอดมินยังเห็นสถานะของระบบ แต่กดสลับไม่ได้
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Application Settings'))),
      body: AnimatedBuilder(
        animation: Listenable.merge([controller, systemSettingsController]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
            children: [
              const _SectionLabel('APPEARANCE'),
              const SizedBox(height: 10),
              _ThemeCard(controller: controller),
              const SizedBox(height: 24),
              const _SectionLabel('LANGUAGE'),
              const SizedBox(height: 10),
              Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _SettingsIcon(
                            icon: Icons.translate_rounded,
                            color: AppColors.blue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('App language'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('Choose Thai or English. Your selection is saved automatically.'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<AppLanguage>(
                          key: const Key('language-selector'),
                          segments: const [
                            ButtonSegment<AppLanguage>(
                              value: AppLanguage.thai,
                              icon: Icon(Icons.language_rounded),
                              label: Text('ภาษาไทย'),
                            ),
                            ButtonSegment<AppLanguage>(
                              value: AppLanguage.english,
                              icon: Icon(Icons.translate_rounded),
                              label: Text('English'),
                            ),
                          ],
                          selected: {controller.language},
                          showSelectedIcon: true,
                          onSelectionChanged: (selection) {
                            controller.setLanguage(selection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('AUTOMATIC SHUTDOWN'),
              const SizedBox(height: 10),
              _AutoOffCard(
                controller: systemSettingsController,
                isAdmin: isAdmin,
              ),
              const SizedBox(height: 24),
              const _SectionLabel('TEXT SIZE'),
              const SizedBox(height: 10),
              _TextSizeCard(controller: controller),
              const SizedBox(height: 24),
              const _SectionLabel('NOTIFICATIONS'),
              const SizedBox(height: 10),
              _NotificationsRow(controller: controller),
            ],
          );
        },
      ),
    );
  }
}

/// การ์ดเลือกธีม: ตัวอย่างสีย่อส่วนของแต่ละธีมให้เห็นก่อนกด
///
/// ธีมเก็บไว้ในเครื่องนี้ เหมือนภาษาและขนาดตัวอักษร
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.controller});

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SettingsIcon(
                  icon: Icons.palette_rounded,
                  color: AppPalette.of(context).accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Theme colors'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'Colors come from the RMUTT Save Energy logo. '
                          'Saved on this phone.',
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                // จอกว้าง (แท็บเล็ต/คอม) วางครบห้าแบบในแถวเดียว มือถือวางแถวละสาม
                const gap = 8.0;
                final columns = constraints.maxWidth >= 520 ? 5 : 3;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final choice in AppThemeChoice.values)
                      SizedBox(
                        width: width,
                        child: _ThemeOption(
                          choice: choice,
                          selected: controller.themeChoice == choice,
                          onTap: () => controller.setTheme(choice),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(controller.themeChoice.description),
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final AppThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          key: Key('theme-option-${choice.code}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (choice == AppThemeChoice.system)
                  Row(
                    children: [
                      Expanded(
                        child: _MiniScreen(
                          colors: AppTheme.previewColors(AppThemeChoice.white),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: _MiniScreen(
                          colors: AppTheme.previewColors(AppThemeChoice.gray),
                        ),
                      ),
                    ],
                  )
                else
                  _MiniScreen(colors: AppTheme.previewColors(choice)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(choice.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// หน้าจอย่อส่วน: พื้น แถบหัว การ์ด และสีเน้นของธีมนั้น
class _MiniScreen extends StatelessWidget {
  const _MiniScreen({required this.colors});

  /// ลำดับตาม AppTheme.previewColors: พื้น แถบหัว การ์ด สีเน้น
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final accent = colors[3];

    return Container(
      height: 50,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors[0],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x55808080)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 12, color: colors[1]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: colors[2],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        width: 22,
                        height: 5,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        width: 14,
                        height: 5,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// สวิตช์รวมของระบบปิดแอร์อัตโนมัติ
///
/// ค่านี้อยู่บนเซิร์ฟเวอร์ ไม่ใช่ในเครื่อง เพราะตัวที่ยิงคำสั่งปิดคือ Backend
/// สวิตช์ที่เก็บไว้ในมือถือจะหยุดระบบไม่ได้จริง เครื่องอื่นก็ยังโดนปิดอยู่ดี
class _AutoOffCard extends StatelessWidget {
  const _AutoOffCard({required this.controller, required this.isAdmin});

  final SystemSettingsController controller;
  final bool isAdmin;

  Future<void> _toggle(BuildContext context, bool enabled) async {
    // หยิบทุกอย่างที่ต้องใช้ context ออกมาก่อนรอเซิร์ฟเวอร์
    // ผู้ใช้อาจกดย้อนกลับระหว่างรอ แล้ว context ตัวนี้จะถูกทิ้งไปแล้ว
    final messenger = ScaffoldMessenger.of(context);
    final fallback = context.tr(
      'Could not save the setting. Please try again.',
    );

    final saved = await controller.setAutoOffEnabled(enabled);
    if (saved) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(controller.errorMessage ?? fallback),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = controller.autoOffEnabled;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const Key('auto-off-master-switch'),
              contentPadding: EdgeInsets.zero,
              value: enabled,
              onChanged: isAdmin && !controller.isSaving
                  ? (value) => _toggle(context, value)
                  : null,
              secondary: _SettingsIcon(
                icon: enabled
                    ? Icons.motion_photos_auto_rounded
                    : Icons.do_not_disturb_on_rounded,
                color: enabled ? AppColors.primary : AppColors.textSecondary,
              ),
              title: Text(
                context.tr('Switch air conditioners off automatically'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                context.tr(
                  'Counts down 5 minutes when a room is empty with the air '
                  'conditioner running, then sends the off signal.',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (controller.isLoading && !controller.hasLoaded)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (!isAdmin)
              _AutoOffNote(
                icon: Icons.lock_outline_rounded,
                color: AppColors.textSecondary,
                text: context.tr(
                  'Only an admin can change this. It applies to the whole '
                  'building.',
                ),
              )
            else if (!enabled)
              _AutoOffNote(
                icon: Icons.warning_amber_rounded,
                color: AppColors.orange,
                text: context.tr(
                  'Every room is affected. No countdown runs and nothing is '
                  'switched off until this is turned back on.',
                ),
              ),
            if (controller.errorMessage != null)
              _AutoOffNote(
                icon: Icons.error_outline_rounded,
                color: AppColors.red,
                text: controller.errorMessage!,
              ),
          ],
        ),
      ),
    );
  }
}

class _AutoOffNote extends StatelessWidget {
  const _AutoOffNote({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// การ์ดเลือกขนาดตัวอักษร พร้อมตัวอย่างให้เห็นผลก่อนเลือก
class _TextSizeCard extends StatelessWidget {
  const _TextSizeCard({required this.controller});

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _SettingsIcon(
                  icon: Icons.format_size_rounded,
                  color: AppColors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Text size'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(
                          'Applies to every screen. It is combined with the '
                          'size set on your phone.',
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<AppTextScale>(
                key: const Key('text-scale-selector'),
                showSelectedIcon: false,
                segments: [
                  for (final scale in AppTextScale.values)
                    ButtonSegment<AppTextScale>(
                      value: scale,
                      label: Text(context.tr(scale.label)),
                    ),
                ],
                selected: {controller.textScale},
                onSelectionChanged: (selection) {
                  controller.setTextScale(selection.first);
                },
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.tr('Sample: room 16103 is using 1.20 kWh right now'),
                style: TextStyle(color: colors.onSurface, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// สวิตช์ของการแจ้งเตือนหนึ่งชนิด
/// แถวเดียวในหน้าตั้งค่าหลัก กดแล้วเข้าไปหน้าย่อย
///
/// การ์ดสามใบเดิมกินพื้นที่กว่า 500px และซ้ำรูปแบบกันหมด
/// หน้าตั้งค่าหลักควรกวาดตาผ่านได้เร็ว รายละเอียดจึงย้ายไปอยู่หน้าของมันเอง
class _NotificationsRow extends StatelessWidget {
  const _NotificationsRow({required this.controller});

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final preferences = controller.alertPreferences;
    const kinds = AlertPreferences.configurableKinds;
    final inApp = kinds.where(preferences.showsInApp).length;
    final push = kinds.where(preferences.pushesToPhone).length;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const Key('notification-settings-row'),
        leading: const _SettingsIcon(
          icon: Icons.notifications_active_rounded,
          color: AppColors.blue,
        ),
        title: Text(
          context.tr('Alerts by type'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        // บอกจำนวนที่เปิดอยู่ไว้ตรงนี้ จะได้รู้สถานะโดยไม่ต้องกดเข้าไปดู
        subtitle: Text(
          '${context.tr('In the app')} $inApp/${kinds.length}'
          '  ·  ${context.tr('On this phone')} $push/${kinds.length}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => NotificationSettingsScreen(controller: controller),
          ),
        ),
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
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({
    required this.icon,
    required this.color,
  });

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
