import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DtColors {
  const DtColors._();
  static const brand = Color(0xFF6A4DFF);
  static const brandDeep = Color(0xFF5235DB);
  static const violet = Color(0xFF8E72EA);
  static const mint = Color(0xFF32A99A);
  static const coral = Color(0xFFD95E58);
  static const rose = Color(0xFFE590AA);
  static const ink = Color(0xFF17181B);
  static const mist = Color(0xFFF6F7F9);
  static const canvas = Color(0xFFF6F7F9);
  static const canvasSoft = Color(0xFFF9FAFC);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF1F2F5);
  static const line = Color(0xFFE8E9EE);
  static const textSecondary = Color(0xFF747780);
  static const textTertiary = Color(0xFF9699A2);
  static const darkBg = Color(0xFF101113);
  static const darkSurface = Color(0xFF191B1F);
  static const darkElevated = Color(0xFF24262C);
  static const darkLine = Color(0xFF303239);
}

class DtRadii {
  const DtRadii._();
  static const card = 12.0;
  static const cardLarge = 18.0;
  static const control = 10.0;
  static const bubble = 14.0;
  static const pill = 999.0;
}

class DtMotionTokens {
  const DtMotionTokens._();
  static const page = Duration(milliseconds: 180);
  static const fast = Duration(milliseconds: 120);
  static const slow = Duration(milliseconds: 200);
  static const press = Duration(milliseconds: 90);
  static const staggerStep = Duration.zero;
  static const pageOffset = 0.0;
  static const listOffset = 0.0;
  static const ease = Curves.easeOutCubic;
}

class DtShadows {
  const DtShadows._();
  static List<BoxShadow> soft(bool dark) => const [];
  static List<BoxShadow> floating(bool dark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.16 : 0.035),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> primary(bool dark) => const [];
}

class DtTheme {
  const DtTheme._();
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF1F2F5) : DtColors.ink;
    final background = dark ? DtColors.darkBg : DtColors.canvas;
    final surface = dark ? DtColors.darkSurface : DtColors.surface;
    final scheme = ColorScheme.fromSeed(
      seedColor: DtColors.brand,
      brightness: brightness,
      surface: surface,
      primary: dark ? const Color(0xFFAA99FF) : DtColors.brand,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: kIsWeb ? 'SillyTavernWebCJK' : null,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: foreground,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(fontSize: 15, color: foreground, height: 1.45),
        bodyLarge: TextStyle(fontSize: 16, color: foreground),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DtRadii.card),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? DtColors.darkLine : DtColors.line,
        thickness: 0.5,
        space: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? DtColors.darkElevated : DtColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DtRadii.control),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DtRadii.control),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DtRadii.control),
          borderSide: const BorderSide(color: DtColors.brand, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
