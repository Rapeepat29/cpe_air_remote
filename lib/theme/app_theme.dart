import 'package:flutter/material.dart';

/// สีหลักของแบรนด์ (ค่าคงที่ ไม่เปลี่ยนตามธีม)
///
/// สีทั้งหมดมาจากโลโก้: เทาถ่าน #2F3438 กับเขียวใบไม้ #2EB872
/// [primary] คือเขียวเข้มสำหรับตัวหนังสือและปุ่มบนพื้นสว่าง (#0F7D45
/// เข้มกว่า #128C4E ของโลโก้นิดเดียว เพราะ #128C4E บนพื้นขาวได้แค่ 4.3:1)
///
/// ที่ไหนที่สีต้องเปลี่ยนตามธีม (แถบหัวจอ ตัวเลขใหญ่ สีเน้นบนพื้นเข้ม)
/// ให้ใช้ [AppPalette.of] แทน
abstract final class AppColors {
  static const charcoal = Color(0xFF2F3438);
  static const leaf = Color(0xFF2EB872);
  static const leafDeep = Color(0xFF128C4E);
  static const leafLight = Color(0xFF5FD394);

  static const primary = Color(0xFF0F7D45);
  static const primaryDark = Color(0xFF0B5E34);
  static const primaryLight = Color(0xFF5FD394);
  static const background = Color(0xFFF3F5F6);
  static const surfaceSoft = Color(0xFFECEFF1);
  static const textPrimary = Color(0xFF1E2427);
  static const textSecondary = Color(0xFF5E6A70);
  static const green = Color(0xFF1A8550);
  static const greenSoft = Color(0xFFDFF1E7);
  static const orange = Color(0xFFB26A00);
  static const orangeSoft = Color(0xFFFFF0DC);
  static const blue = Color(0xFF2F6DB3);
  static const blueSoft = Color(0xFFE8F0F9);
  static const red = Color(0xFFC0392B);
  static const redSoft = Color(0xFFFBE7E5);
  static const border = Color(0xFFD8DDE0);
}

/// ฟอนต์หัวข้อและตัวเลขใหญ่ ตัวเดียวกับตัวหนังสือในโลโก้ (มีอักษรไทย)
/// ไฟล์อยู่ใน assets/fonts และประกาศไว้ใน pubspec.yaml
const kDisplayFont = 'ChakraPetch';

/// ธีมที่ผู้ใช้เลือกได้ในหน้าตั้งค่า
enum AppThemeChoice {
  white('white'),
  gray('gray'),
  black('black'),
  green('green'),
  system('system');

  const AppThemeChoice(this.code);

  final String code;

  /// ป้ายภาษาอังกฤษ ให้ตัวแปลของแอปแปลต่ออีกที
  String get label => switch (this) {
    AppThemeChoice.white => 'White',
    AppThemeChoice.gray => 'Gray',
    AppThemeChoice.black => 'Black',
    AppThemeChoice.green => 'Green',
    AppThemeChoice.system => 'Match phone',
  };

  String get description => switch (this) {
    AppThemeChoice.white => 'Bright and easy to read in sunny rooms',
    AppThemeChoice.gray => 'The logo charcoal, gentle on the eyes',
    AppThemeChoice.black => 'Fully dark for screens left on at night',
    AppThemeChoice.green => 'Deep green header with light content',
    AppThemeChoice.system => 'White in light mode, Gray in dark mode',
  };

  static AppThemeChoice? fromCode(String? code) {
    for (final choice in AppThemeChoice.values) {
      if (choice.code == code) return choice;
    }
    return null;
  }
}

/// สีที่เปลี่ยนตามธีม ซึ่ง ColorScheme ของ Material ไม่มีช่องให้ใส่
///
/// เรียกด้วย `AppPalette.of(context)` ถ้าหาไม่เจอ (เช่นในเทสต์ที่ไม่ได้ใช้
/// AppTheme) จะได้ชุดสีของธีมขาว
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bar,
    required this.onBar,
    required this.barLogoGreen,
    required this.accent,
    required this.accentSoft,
    required this.fill,
    required this.fillSoft,
    required this.warn,
    required this.warnSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.mutedText,
  });

  /// แถบหัวจอของทุกหน้า
  final Color bar;
  final Color onBar;

  /// สีตัว R และคำว่า Energy ในชื่อแอปบนแถบหัวจอ
  final Color barLogoGreen;

  /// สีเน้นที่อ่านออกบนพื้นการ์ดของธีมนั้น (ตัวเลขใหญ่ ลิงก์ ไอคอนสำคัญ)
  final Color accent;
  final Color accentSoft;

  /// สีเส้นกราฟและแท่งพลังงาน
  final Color fill;
  final Color fillSoft;

  final Color warn;
  final Color warnSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;

  /// ตัวหนังสือรองบนพื้นของกราฟ
  final Color mutedText;

  static AppPalette of(BuildContext context) {
    return Theme.of(context).extension<AppPalette>() ?? _white;
  }

  static const _white = AppPalette(
    bar: Color(0xFFFFFFFF),
    onBar: Color(0xFF1E2427),
    barLogoGreen: Color(0xFF128C4E),
    accent: Color(0xFF0F7D45),
    accentSoft: Color(0x1A0F7D45),
    fill: Color(0xFF2EB872),
    fillSoft: Color(0x292EB872),
    warn: Color(0xFFA35F00),
    warnSoft: Color(0x24D68C14),
    danger: Color(0xFFC0392B),
    dangerSoft: Color(0x1AC0392B),
    info: Color(0xFF2563A8),
    mutedText: Color(0xFF5E6A70),
  );

  static const _gray = AppPalette(
    bar: Color(0xFF23272B),
    onBar: Color(0xFFF1F3F4),
    barLogoGreen: Color(0xFF5FD394),
    accent: Color(0xFF6EDB9F),
    accentSoft: Color(0x246EDB9F),
    fill: Color(0xFF2EB872),
    fillSoft: Color(0x2E2EB872),
    warn: Color(0xFFF2B35A),
    warnSoft: Color(0x29F2B35A),
    danger: Color(0xFFF79289),
    dangerSoft: Color(0x29F79289),
    info: Color(0xFF8CC0F2),
    mutedText: Color(0xFFB0B9BE),
  );

  static const _black = AppPalette(
    bar: Color(0xFF0B0D0E),
    onBar: Color(0xFFEDEFF0),
    barLogoGreen: Color(0xFF5FD394),
    accent: Color(0xFF5FD394),
    accentSoft: Color(0x1F5FD394),
    fill: Color(0xFF2EB872),
    fillSoft: Color(0x242EB872),
    warn: Color(0xFFF0A84A),
    warnSoft: Color(0x24F0A84A),
    danger: Color(0xFFF2867D),
    dangerSoft: Color(0x24F2867D),
    info: Color(0xFF7DB6F0),
    mutedText: Color(0xFF8E979C),
  );

  static const _green = AppPalette(
    bar: Color(0xFF0E5A34),
    onBar: Color(0xFFFFFFFF),
    barLogoGreen: Color(0xFF7FE0A8),
    accent: Color(0xFF0F7D45),
    accentSoft: Color(0x1A0F7D45),
    fill: Color(0xFF2EB872),
    fillSoft: Color(0x292EB872),
    warn: Color(0xFFA35F00),
    warnSoft: Color(0x24D68C14),
    danger: Color(0xFFC0392B),
    dangerSoft: Color(0x1AC0392B),
    info: Color(0xFF2563A8),
    mutedText: Color(0xFF57695F),
  );

  @override
  AppPalette copyWith({
    Color? bar,
    Color? onBar,
    Color? barLogoGreen,
    Color? accent,
    Color? accentSoft,
    Color? fill,
    Color? fillSoft,
    Color? warn,
    Color? warnSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? mutedText,
  }) {
    return AppPalette(
      bar: bar ?? this.bar,
      onBar: onBar ?? this.onBar,
      barLogoGreen: barLogoGreen ?? this.barLogoGreen,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      fill: fill ?? this.fill,
      fillSoft: fillSoft ?? this.fillSoft,
      warn: warn ?? this.warn,
      warnSoft: warnSoft ?? this.warnSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      mutedText: mutedText ?? this.mutedText,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bar: mix(bar, other.bar),
      onBar: mix(onBar, other.onBar),
      barLogoGreen: mix(barLogoGreen, other.barLogoGreen),
      accent: mix(accent, other.accent),
      accentSoft: mix(accentSoft, other.accentSoft),
      fill: mix(fill, other.fill),
      fillSoft: mix(fillSoft, other.fillSoft),
      warn: mix(warn, other.warn),
      warnSoft: mix(warnSoft, other.warnSoft),
      danger: mix(danger, other.danger),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      info: mix(info, other.info),
      mutedText: mix(mutedText, other.mutedText),
    );
  }
}

/// ค่าสีพื้นฐานของแต่ละธีม ใช้ประกอบเป็น ThemeData
class _ThemeSpec {
  const _ThemeSpec({
    required this.brightness,
    required this.palette,
    required this.scaffold,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.containerLow,
    required this.container,
    required this.containerHigh,
    required this.containerHighest,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.navBackground,
    required this.navMuted,
    required this.snackBackground,
    required this.snackText,
  });

  final Brightness brightness;
  final AppPalette palette;
  final Color scaffold;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color containerLow;
  final Color container;
  final Color containerHigh;
  final Color containerHighest;
  final Color outline;
  final Color outlineVariant;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color navBackground;
  final Color navMuted;
  final Color snackBackground;
  final Color snackText;
}

const _whiteSpec = _ThemeSpec(
  brightness: Brightness.light,
  palette: AppPalette._white,
  scaffold: Color(0xFFF3F5F6),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF1E2427),
  onSurfaceVariant: Color(0xFF4A555B),
  containerLow: Color(0xFFF3F5F6),
  container: Color(0xFFEEF1F2),
  containerHigh: Color(0xFFECEFF1),
  containerHighest: Color(0xFFE3E7EA),
  outline: Color(0xFFC9D0D4),
  outlineVariant: Color(0xFFD8DDE0),
  primary: Color(0xFF0F7D45),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFDFF1E7),
  onPrimaryContainer: Color(0xFF0B5E34),
  navBackground: Color(0xFFFFFFFF),
  navMuted: Color(0xFF5E6A70),
  snackBackground: Color(0xFF2F3438),
  snackText: Color(0xFFFFFFFF),
);

const _graySpec = _ThemeSpec(
  brightness: Brightness.dark,
  palette: AppPalette._gray,
  scaffold: Color(0xFF2A2F33),
  surface: Color(0xFF33393E),
  onSurface: Color(0xFFF1F3F4),
  onSurfaceVariant: Color(0xFFC6CDD1),
  containerLow: Color(0xFF2E3337),
  container: Color(0xFF383E43),
  containerHigh: Color(0xFF3D4449),
  containerHighest: Color(0xFF474E53),
  outline: Color(0xFF5A6369),
  outlineVariant: Color(0xFF4A5257),
  primary: Color(0xFF6EDB9F),
  onPrimary: Color(0xFF0B1A12),
  primaryContainer: Color(0xFF2D5A42),
  onPrimaryContainer: Color(0xFFC9F2DA),
  navBackground: Color(0xFF23272B),
  navMuted: Color(0xFFB0B9BE),
  snackBackground: Color(0xFFF1F3F4),
  snackText: Color(0xFF1E2427),
);

const _blackSpec = _ThemeSpec(
  brightness: Brightness.dark,
  palette: AppPalette._black,
  scaffold: Color(0xFF0B0D0E),
  surface: Color(0xFF151819),
  onSurface: Color(0xFFEDEFF0),
  onSurfaceVariant: Color(0xFFB3BABE),
  containerLow: Color(0xFF101213),
  container: Color(0xFF191C1E),
  containerHigh: Color(0xFF1E2123),
  containerHighest: Color(0xFF26292C),
  outline: Color(0xFF3A4044),
  outlineVariant: Color(0xFF2A2F32),
  primary: Color(0xFF5FD394),
  onPrimary: Color(0xFF0B1A12),
  primaryContainer: Color(0xFF1A4430),
  onPrimaryContainer: Color(0xFFBDF0D2),
  navBackground: Color(0xFF0B0D0E),
  navMuted: Color(0xFF8E979C),
  snackBackground: Color(0xFFEDEFF0),
  snackText: Color(0xFF151819),
);

const _greenSpec = _ThemeSpec(
  brightness: Brightness.light,
  palette: AppPalette._green,
  scaffold: Color(0xFFEDF5F0),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF14271D),
  onSurfaceVariant: Color(0xFF43584C),
  containerLow: Color(0xFFEDF5F0),
  container: Color(0xFFE8F1EC),
  containerHigh: Color(0xFFE2EEE7),
  containerHighest: Color(0xFFD7E7DD),
  outline: Color(0xFFBFD3C7),
  outlineVariant: Color(0xFFCFE0D6),
  primary: Color(0xFF0F7D45),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFDFF1E7),
  onPrimaryContainer: Color(0xFF0B5E34),
  navBackground: Color(0xFFFFFFFF),
  navMuted: Color(0xFF57695F),
  snackBackground: Color(0xFF0E5A34),
  snackText: Color(0xFFFFFFFF),
);

abstract final class AppTheme {
  /// ธีมขาว (ค่าเริ่มต้นของแอป)
  static ThemeData get light => forChoice(AppThemeChoice.white);

  /// ธีมเทา ใช้เป็นธีมมืดเมื่อเลือก "ตามเครื่อง"
  static ThemeData get dark => forChoice(AppThemeChoice.gray);

  static ThemeData forChoice(AppThemeChoice choice) {
    return switch (choice) {
      AppThemeChoice.white || AppThemeChoice.system => _build(_whiteSpec),
      AppThemeChoice.gray => _build(_graySpec),
      AppThemeChoice.black => _build(_blackSpec),
      AppThemeChoice.green => _build(_greenSpec),
    };
  }

  /// สีตัวอย่างของแต่ละธีมสำหรับการ์ดเลือกธีม: พื้น แถบหัว การ์ด สีเน้น
  static List<Color> previewColors(AppThemeChoice choice) {
    final spec = switch (choice) {
      AppThemeChoice.white || AppThemeChoice.system => _whiteSpec,
      AppThemeChoice.gray => _graySpec,
      AppThemeChoice.black => _blackSpec,
      AppThemeChoice.green => _greenSpec,
    };
    return [spec.scaffold, spec.palette.bar, spec.surface, spec.primary];
  }

  static ThemeData _build(_ThemeSpec spec) {
    final palette = spec.palette;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.leaf,
      brightness: spec.brightness,
      primary: spec.primary,
      surface: spec.surface,
      error: palette.danger,
    ).copyWith(
      onPrimary: spec.onPrimary,
      primaryContainer: spec.primaryContainer,
      onPrimaryContainer: spec.onPrimaryContainer,
      secondary: spec.onSurfaceVariant,
      secondaryContainer: spec.containerHigh,
      onSecondaryContainer: spec.onSurface,
      onSurface: spec.onSurface,
      onSurfaceVariant: spec.onSurfaceVariant,
      surfaceContainerLowest: spec.surface,
      surfaceContainerLow: spec.containerLow,
      surfaceContainer: spec.container,
      surfaceContainerHigh: spec.containerHigh,
      surfaceContainerHighest: spec.containerHighest,
      outline: spec.outline,
      outlineVariant: spec.outlineVariant,
    );

    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: spec.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: spec.scaffold,
      fontFamily: 'sans-serif',
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: palette.bar,
        foregroundColor: palette.onBar,
        surfaceTintColor: Colors.transparent,
        shape: spec.brightness == Brightness.light &&
                palette.bar == spec.surface
            ? Border(bottom: BorderSide(color: spec.outlineVariant))
            : null,
        titleTextStyle: TextStyle(
          color: palette.onBar,
          fontFamily: kDisplayFont,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: spec.surface,
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: spec.navBackground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? palette.accent : spec.navMuted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? palette.accent : spec.navMuted,
            size: 23,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: spec.snackBackground,
        contentTextStyle: TextStyle(color: spec.snackText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: spec.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: border(spec.outline),
        enabledBorder: border(spec.outline),
        focusedBorder: border(spec.primary, 1.5),
        errorBorder: border(palette.danger),
        focusedErrorBorder: border(palette.danger, 1.5),
      ),
      dividerColor: spec.outlineVariant,
      dialogTheme: DialogThemeData(backgroundColor: spec.surface),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: spec.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
