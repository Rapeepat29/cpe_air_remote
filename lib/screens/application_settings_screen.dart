import '../localization/localized_material.dart';

import '../controllers/app_settings_controller.dart';
import '../controllers/system_settings_controller.dart';
import '../theme/app_theme.dart';
import '../utils/alert_preferences.dart';
import 'notification_settings_screen.dart';

/// หน้าตั้งค่าแอปแบบรายการเรียบ (แบบ 2.1)
///
/// พื้นทั้งหน้าเป็นสีเดียวกับการ์ด แบ่งหมวดด้วยหัวข้อสีเน้นและเส้นบาง ๆ
/// ทุกแถวเรียงเหมือนกันคือ ไอคอนเส้น ชื่อ คำอธิบายสั้น แล้วตัวควบคุมอยู่ขวา
/// ใช้สีจากธีมที่ผู้ใช้เลือก ไม่ฝังสีไว้ในหน้านี้
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(context.tr('Application Settings'))),
      body: AnimatedBuilder(
        animation: Listenable.merge([controller, systemSettingsController]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const _SectionLabel('General'),
              _FlatGroup(
                children: [
                  _LanguageRow(controller: controller),
                  _ThemeRow(controller: controller),
                  _NotificationsRow(controller: controller),
                ],
              ),
              const _SectionLabel('Text display'),
              _FlatGroup(
                children: [_TextSizeRow(controller: controller)],
              ),
              const _SectionLabel('For administrators'),
              _FlatGroup(
                children: [
                  _AutoOffRow(
                    controller: systemSettingsController,
                    isAdmin: isAdmin,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// กลุ่มของแถวตั้งค่า: เส้นบนล่าง และเส้นคั่นระหว่างแถว
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

/// ส่วนหัวของแถว: ไอคอนเส้น ชื่อ คำอธิบาย และตัวควบคุมทางขวา (ถ้ามี)
class _SettingHeader extends StatelessWidget {
  const _SettingHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 22, color: AppPalette.of(context).accent),
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
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.controller});

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: _SettingHeader(
        icon: Icons.language_rounded,
        title: context.tr('App language'),
        subtitle: context.tr('Choose the display language'),
        trailing: _MiniSegmented<AppLanguage>(
          key: const Key('language-selector'),
          options: const [
            (AppLanguage.thai, 'ภาษาไทย'),
            (AppLanguage.english, 'English'),
          ],
          selected: controller.language,
          onSelected: controller.setLanguage,
        ),
      ),
    );
  }
}

/// ปุ่มเลือกหนึ่งในสองตัวเลือกแบบกะทัดรัด ใช้ทางขวาของแถว
class _MiniSegmented<T> extends StatelessWidget {
  const _MiniSegmented({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            _segment(colors, options[i], options[i].$1 == selected),
          ],
        ],
      ),
    );
  }

  Widget _segment(ColorScheme colors, (T, String) option, bool isSelected) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? colors.surface : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? colors.primary : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: () => onSelected(option.$1),
          child: Container(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: Text(
              option.$2,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// แถวธีม: แสดงธีมที่ใช้อยู่ กดแล้วเปิดแผ่นเลือกธีมจากด้านล่าง
///
/// ธีมเก็บไว้ในเครื่องนี้ เหมือนภาษาและขนาดตัวอักษร
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.controller});

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final choice = controller.themeChoice;

    return InkWell(
      key: const Key('theme-row'),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _ThemeSheet(controller: controller),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
        child: _SettingHeader(
          icon: Icons.palette_outlined,
          title: context.tr('Theme colors'),
          subtitle: context.tr(choice.description),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(choice.label),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.of(context).accent,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet({required this.controller});

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                context.tr('Choose a theme'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final choice in AppThemeChoice.values)
              _ThemeChoiceTile(
                choice: choice,
                selected: controller.themeChoice == choice,
                onTap: () {
                  Navigator.of(context).pop();
                  controller.setTheme(choice);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChoiceTile extends StatelessWidget {
  const _ThemeChoiceTile({
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
      child: InkWell(
        key: Key('theme-option-${choice.code}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: choice == AppThemeChoice.system
                    ? Row(
                        children: [
                          Expanded(
                            child: _MiniScreen(
                              colors: AppTheme.previewColors(
                                AppThemeChoice.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: _MiniScreen(
                              colors: AppTheme.previewColors(
                                AppThemeChoice.gray,
                              ),
                            ),
                          ),
                        ],
                      )
                    : _MiniScreen(colors: AppTheme.previewColors(choice)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      choice.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      choice.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ],
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

/// แถวการแจ้งเตือน: แตะส่วนข้อความเพื่อเลือกประเภท สวิตช์ทางขวาเปิดหรือปิดทั้งหมด
///
/// ปิดสวิตช์แล้วค่าที่เลือกไว้รายประเภทยังจำไว้ เปิดกลับมาก็ได้แบบเดิม
class _NotificationsRow extends StatelessWidget {
  const _NotificationsRow({required this.controller});

  final AppSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final preferences = controller.alertPreferences;
    const kinds = AlertPreferences.configurableKinds;
    final selected = kinds.where(preferences.typeSelected).length;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              key: const Key('notification-settings-row'),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationSettingsScreen(controller: controller),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                child: _SettingHeader(
                  icon: preferences.enabled
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_off_outlined,
                  title: context.tr('Notifications'),
                  subtitle: preferences.enabled
                      ? context.tr(
                          'On for $selected of ${kinds.length} types',
                        )
                      : context.tr('All notifications are off'),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            indent: 14,
            endIndent: 14,
            color: colors.outlineVariant,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Switch(
                key: const Key('notifications-master-switch'),
                value: preferences.enabled,
                onChanged: controller.setNotificationsEnabled,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// แถวเลือกขนาดตัวอักษร พร้อมตัวอย่างให้เห็นผลก่อนเลือก
///
/// ปุ่มแต่ละขั้นเป็นตัวอักษรตัวเดียวที่โตขึ้นเรื่อย ๆ ให้เห็นความต่างได้ทันที
class _TextSizeRow extends StatelessWidget {
  const _TextSizeRow({required this.controller});

  final AppSettingsController controller;

  /// ขนาดตัวอักษรบนปุ่มของแต่ละขั้น เรียงตาม AppTextScale.values
  static const _glyphSizes = <double>[13, 16, 20, 25];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final glyph = controller.language == AppLanguage.thai ? 'ก' : 'A';
    const scales = AppTextScale.values;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingHeader(
            icon: Icons.text_fields_rounded,
            title: context.tr('Text size'),
            subtitle: context.tr(
              'Applies to every screen and follows the text size set on '
              'this device.',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            key: const Key('text-scale-selector'),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < scales.length; i++)
                _SizeStep(
                  glyph: glyph,
                  glyphSize: _glyphSizes[i],
                  label: context.tr(scales[i].label),
                  selected: controller.textScale == scales[i],
                  onTap: () => controller.setTextScale(scales[i]),
                  stepKey: Key('text-scale-${scales[i].code}'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              context.tr('Sample text: Room 16103 is using 1.20 kWh'),
              style: TextStyle(color: colors.onSurface, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeStep extends StatelessWidget {
  const _SizeStep({
    required this.glyph,
    required this.glyphSize,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.stepKey,
  });

  final String glyph;
  final double glyphSize;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Key stepKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = selected ? colors.primary : colors.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: stepKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? colors.primary.withValues(alpha: 0.10)
                      : null,
                  border: Border.all(
                    color: selected ? colors.primary : colors.outlineVariant,
                    width: 2,
                  ),
                ),
                child: Text(
                  glyph,
                  style: TextStyle(
                    fontSize: glyphSize,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// สวิตช์รวมของระบบปิดแอร์อัตโนมัติ
///
/// ค่านี้อยู่บนเซิร์ฟเวอร์ ไม่ใช่ในเครื่อง เพราะตัวที่ยิงคำสั่งปิดคือ Backend
/// สวิตช์ที่เก็บไว้ในมือถือจะหยุดระบบไม่ได้จริง เครื่องอื่นก็ยังโดนปิดอยู่ดี
class _AutoOffRow extends StatelessWidget {
  const _AutoOffRow({required this.controller, required this.isAdmin});

  final SystemSettingsController controller;
  final bool isAdmin;

  Future<void> _toggle(BuildContext context, bool enabled) async {
    // หยิบทุกอย่างที่ต้องใช้ context ออกมาก่อนรอเซิร์ฟเวอร์
    // ผู้ใช้อาจกดย้อนกลับระหว่างรอ แล้ว context ตัวนี้จะถูกทิ้งไปแล้ว
    final messenger = ScaffoldMessenger.of(context);
    final fallback = context.tr(
      'The setting could not be saved. Please try again.',
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

  Future<void> _toggleTestMode(BuildContext context, bool testMode) async {
    final messenger = ScaffoldMessenger.of(context);
    final fallback = context.tr(
      'The setting could not be saved. Please try again.',
    );

    final saved = await controller.setAutoOffTestMode(testMode);
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
    final palette = AppPalette.of(context);
    final enabled = controller.autoOffEnabled;
    final testMode = controller.autoOffTestMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('auto-off-master-switch'),
          contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          value: enabled,
          onChanged: isAdmin && !controller.isSaving
              ? (value) => _toggle(context, value)
              : null,
          secondary: Icon(
            Icons.power_settings_new_rounded,
            size: 22,
            color: enabled ? palette.accent : colors.onSurfaceVariant,
          ),
          title: Text(
            context.tr('Switch air conditioners off automatically'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            context.tr(
              'When an air conditioner runs in an empty room, the system '
              'counts down 5 minutes and then sends the off command.',
            ),
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: 56,
          color: colors.outlineVariant,
        ),
        SwitchListTile(
          key: const Key('auto-off-test-mode-switch'),
          contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          value: testMode,
          onChanged: isAdmin && enabled && !controller.isSaving
              ? (value) => _toggleTestMode(context, value)
              : null,
          secondary: Icon(
            Icons.timer_outlined,
            size: 22,
            color: enabled && testMode ? palette.warn : colors.onSurfaceVariant,
          ),
          title: Text(
            context.tr('Auto-off test mode'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            context.tr(
              'Count down 30 seconds outside class hours and 1 minute '
              'during class hours.',
            ),
            style: const TextStyle(fontSize: 12.5, height: 1.4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (controller.isLoading && !controller.hasLoaded)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else
                _AutoOffNote(
                  icon: isAdmin
                      ? Icons.info_outline_rounded
                      : Icons.lock_outline_rounded,
                  color: colors.onSurfaceVariant,
                  text: context.tr(
                    'Only administrators can change this setting because it '
                    'applies to the whole building.',
                  ),
                ),
              if (enabled && testMode)
                _AutoOffNote(
                  icon: Icons.science_outlined,
                  color: palette.warn,
                  text: context.tr(
                    'Test mode is active: empty rooms switch off after '
                    '30 seconds outside class hours or 1 minute during '
                    'class hours.',
                  ),
                ),
              if (isAdmin && controller.hasLoaded && !enabled)
                _AutoOffNote(
                  icon: Icons.warning_amber_rounded,
                  color: palette.warn,
                  text: context.tr(
                    'This applies to every room. No countdown or off command '
                    'will run until it is turned back on.',
                  ),
                ),
              if (controller.errorMessage != null)
                _AutoOffNote(
                  icon: Icons.error_outline_rounded,
                  color: palette.danger,
                  text: controller.errorMessage!,
                ),
            ],
          ),
        ),
      ],
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
