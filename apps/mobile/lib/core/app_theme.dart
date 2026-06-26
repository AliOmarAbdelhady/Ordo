import 'package:flutter/material.dart';

/// Design tokens — spacing, radius (section 7 of the plan).
class OrdoSpacing {
  const OrdoSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double field = 14;
}

class OrdoRadius {
  const OrdoRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

class OrdoColors {
  const OrdoColors._();
  static const Color success = Color(0xFF16A34A);
  static const Color successDark = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerDark = Color(0xFFF87171);
}

/// An accent theme — the app's primary color follows the user's (or group's) accent.
class OrdoAccent {
  final String name;
  final Color light;
  final Color dark;
  final Color softLight;
  final Color softDark;
  const OrdoAccent(
    this.name, {
    required this.light,
    required this.dark,
    required this.softLight,
    required this.softDark,
  });

  Color primary(bool isDark) => isDark ? dark : light;
  Color soft(bool isDark) => isDark ? softDark : softLight;

  static const blue = OrdoAccent('blue',
      light: Color(0xFF2563EB), dark: Color(0xFF60A5FA), softLight: Color(0xFFDBEAFE), softDark: Color(0xFF1E3A8A));
  static const rose = OrdoAccent('rose',
      light: Color(0xFFE11D48), dark: Color(0xFFFB7185), softLight: Color(0xFFFCE7EF), softDark: Color(0xFF4C0519));
  static const emerald = OrdoAccent('emerald',
      light: Color(0xFF059669), dark: Color(0xFF34D399), softLight: Color(0xFFD1FAE5), softDark: Color(0xFF022C22));
  static const violet = OrdoAccent('violet',
      light: Color(0xFF7C3AED), dark: Color(0xFFA78BFA), softLight: Color(0xFFEDE9FE), softDark: Color(0xFF2E1065));
  static const amber = OrdoAccent('amber',
      light: Color(0xFFD97706), dark: Color(0xFFFBBF24), softLight: Color(0xFFFEF3C7), softDark: Color(0xFF451A03));
  static const orange = OrdoAccent('orange',
      light: Color(0xFFEA580C), dark: Color(0xFFFB923C), softLight: Color(0xFFFFEDD5), softDark: Color(0xFF431407));
  static const cyan = OrdoAccent('cyan',
      light: Color(0xFF0891B2), dark: Color(0xFF22D3EE), softLight: Color(0xFFCFFAFE), softDark: Color(0xFF083344));
  static const slate = OrdoAccent('slate',
      light: Color(0xFF475569), dark: Color(0xFF94A3B8), softLight: Color(0xFFE2E8F0), softDark: Color(0xFF1E293B));

  static const all = [blue, rose, emerald, violet, amber, orange, cyan, slate];

  static OrdoAccent byName(String? name) {
    if (name == null) return blue;
    return all.firstWhere((a) => a.name == name, orElse: () => blue);
  }
}

class _Neutrals {
  final Color background, onBackground, surface, onSurface, outline, outlineVariant, muted, onMuted;
  const _Neutrals(this.background, this.onBackground, this.surface, this.onSurface,
      this.outline, this.outlineVariant, this.muted, this.onMuted);
}

const _lightNeutrals = _Neutrals(
  Color(0xFFF8FAFC), Color(0xFF0F172A), // bg / onBg
  Color(0xFFFFFFFF), Color(0xFF0F172A), // surface / onSurface
  Color(0xFFE2E8F0), Color(0xFFCBD5E1), // outline / outlineVariant
  Color(0xFFF1F5F9), Color(0xFF64748B), // muted / onMuted
);

const _darkNeutrals = _Neutrals(
  Color(0xFF020617), Color(0xFFF8FAFC),
  Color(0xFF0F172A), Color(0xFFF8FAFC),
  Color(0xFF1E293B), Color(0xFF334155),
  Color(0xFF111827), Color(0xFF94A3B8),
);

ThemeData ordoTheme(OrdoAccent accent, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final n = isDark ? _darkNeutrals : _lightNeutrals;

  final base = ColorScheme.fromSeed(seedColor: accent.primary(isDark), brightness: brightness);
  final scheme = base.copyWith(
    primary: accent.primary(isDark),
    onPrimary: accent.name == 'amber' ? const Color(0xFF1A1206) : Colors.white,
    primaryContainer: accent.soft(isDark),
    onPrimaryContainer: accent.primary(isDark),
    secondary: n.muted,
    onSecondary: n.onMuted,
    surface: n.surface,
    onSurface: n.onSurface,
    surfaceContainerHighest: n.muted,
    surfaceContainerLow: n.surface,
    surfaceContainer: isDark ? const Color(0xFF0B1424) : const Color(0xFFF1F5F9),
    error: isDark ? OrdoColors.dangerDark : OrdoColors.danger,
    outline: n.outline,
    outlineVariant: n.outlineVariant,
    shadow: isDark ? Colors.black : const Color(0x14000000),
  );

  final textTheme = _buildTextTheme(n.onSurface);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: n.background,
    canvasColor: n.background,
    dividerColor: n.outline,
    textTheme: textTheme,
    fontFamily: null,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    cardTheme: CardThemeData(
      color: n.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OrdoRadius.lg),
        side: BorderSide(color: n.outline, width: 1),
      ),
    ),
    inputDecorationTheme: _inputTheme(scheme, n),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrdoRadius.md)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrdoRadius.md)),
        side: BorderSide(color: n.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrdoRadius.md))),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: n.muted,
      labelStyle: TextStyle(color: n.onMuted, fontSize: 13, fontWeight: FontWeight.w500),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrdoRadius.pill)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: n.background,
      foregroundColor: n.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: n.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    dividerTheme: DividerThemeData(color: n.outline, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: n.surface,
      indicatorColor: accent.soft(isDark),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: n.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: n.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      modalBarrierColor: Colors.black54,
      showDragHandle: true,
      dragHandleColor: n.outlineVariant,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: n.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrdoRadius.lg)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: n.onSurface,
      contentTextStyle: TextStyle(color: n.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(OrdoRadius.md)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent.primary(isDark)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accent.primary(isDark),
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

InputDecorationTheme _inputTheme(ColorScheme scheme, _Neutrals n) {
  return InputDecorationTheme(
    filled: true,
    fillColor: n.muted,
    contentPadding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.lg, vertical: 14),
    hintStyle: TextStyle(color: n.onMuted, fontWeight: FontWeight.w400),
    labelStyle: TextStyle(color: n.onMuted, fontWeight: FontWeight.w500),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OrdoRadius.md),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OrdoRadius.md),
      borderSide: BorderSide(color: n.outline, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OrdoRadius.md),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OrdoRadius.md),
      borderSide: BorderSide(color: scheme.error, width: 1),
    ),
  );
}

TextTheme _buildTextTheme(Color onSurface) {
  const base = TextStyle(color: null, decoration: TextDecoration.none);
  TextStyle t(double size, FontWeight w, [double h = 1.3]) =>
      base.copyWith(fontSize: size, fontWeight: w, height: h, letterSpacing: -0.2);
  return TextTheme(
    displayLarge: t(34, FontWeight.w700, 1.1),
    displayMedium: t(28, FontWeight.w700, 1.15),
    displaySmall: t(24, FontWeight.w700, 1.2),
    headlineMedium: t(22, FontWeight.w600, 1.25),
    headlineSmall: t(20, FontWeight.w600, 1.3),
    titleLarge: t(18, FontWeight.w600, 1.3),
    titleMedium: t(16, FontWeight.w600, 1.35),
    titleSmall: t(14, FontWeight.w600, 1.35),
    bodyLarge: t(16, FontWeight.w400, 1.45),
    bodyMedium: t(14, FontWeight.w400, 1.45),
    bodySmall: t(13, FontWeight.w400, 1.4),
    labelLarge: t(14, FontWeight.w600, 1.2),
    labelMedium: t(13, FontWeight.w500, 1.2),
    labelSmall: t(11, FontWeight.w500, 1.2),
  ).apply(
    displayColor: onSurface,
    bodyColor: onSurface,
  );
}
