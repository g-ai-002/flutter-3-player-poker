import 'package:flutter/material.dart';

import '../utils/system_ui.dart';

const Color kFeltDark = Color(0xFF0A2318);
const Color kGold = Color(0xFFD8B56A);
const Color kGoldSoft = Color(0xFFEBD6A4);
const Color kOnGold = Color(0xFF2C1D04);

/// 金色主按钮：主页「开始对局」、牌桌出牌与浮层确认共用同一套配色。
ButtonStyle goldButtonStyle({
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 15),
  double fontSize = 13,
  OutlinedBorder? shape,
}) {
  return FilledButton.styleFrom(
    backgroundColor: kGold,
    foregroundColor: kOnGold,
    disabledBackgroundColor: kGold.withValues(alpha: 0.22),
    disabledForegroundColor: kOnGold.withValues(alpha: 0.5),
    padding: padding,
    textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
    shape: shape,
  );
}

/// 深色牌桌上的次要按钮：细描边、低饱和文字。
ButtonStyle tableGhostButtonStyle({
  bool enabled = true,
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 14),
  double fontSize = 13,
  Color foreground = const Color(0xB3FFFFFF),
}) {
  return OutlinedButton.styleFrom(
    foregroundColor: foreground,
    disabledForegroundColor: Colors.white.withValues(alpha: 0.25),
    side: BorderSide(
      color: Colors.white.withValues(alpha: enabled ? 0.3 : 0.12),
    ),
    padding: padding,
    textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
    shape: const StadiumBorder(),
  );
}

/// 浅色内容卡片的统一描边：设置、统计、牌谱与玩法页共用。
BoxDecoration surfacePanel(ColorScheme scheme, {double radius = 16}) =>
    BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: scheme.outline),
    );

ThemeData buildLightTheme({String? fontFamily}) {
  const scheme = ColorScheme.light(
    primary: Color(0xFF1F6B46),
    primaryContainer: Color(0xFFDCEEDF),
    onPrimaryContainer: Color(0xFF10351F),
    secondary: Color(0xFFA87C2A),
    onSecondary: Colors.white,
    surface: Color(0xFFFBF7EC),
    onSurface: Color(0xFF1E2A23),
    surfaceContainerHighest: Color(0xFFEFE7D5),
    onSurfaceVariant: Color(0xFF6A7468),
    error: Color(0xFFB3392E),
    outline: Color(0xFFE1D9C6),
    surfaceTint: Colors.transparent,
  );
  return _base(
    scheme: scheme,
    scaffold: const Color(0xFFF7F2E6),
    fontFamily: fontFamily,
  );
}

ThemeData buildDarkTheme({String? fontFamily}) {
  const scheme = ColorScheme.dark(
    primary: Color(0xFF7ACB9B),
    onPrimary: Color(0xFF06301B),
    primaryContainer: Color(0xFF1D5A3A),
    onPrimaryContainer: Color(0xFFE7F6E9),
    secondary: Color(0xFFE2C07A),
    onSecondary: Color(0xFF3A2A08),
    surface: Color(0xFF12261C),
    onSurface: Color(0xFFEDE7D8),
    surfaceContainerHighest: Color(0xFF1B3527),
    onSurfaceVariant: Color(0xFFA8B5A9),
    error: Color(0xFFE57368),
    onError: Color(0xFF2A0B08),
    outline: Color(0xFF2C4636),
    surfaceTint: Colors.transparent,
  );
  return _base(
    scheme: scheme,
    scaffold: const Color(0xFF0C1B13),
    fontFamily: fontFamily,
  );
}

ThemeData _base({
  required ColorScheme scheme,
  required Color scaffold,
  String? fontFamily,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    fontFamily: fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: systemOverlayStyleFor(scaffold),
      toolbarHeight: 52,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
        fontFamily: fontFamily,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 20),
        textStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: fontFamily,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outline,
      thickness: 0.6,
      space: 0.6,
    ),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: 14, color: scheme.onSurface),
      bodySmall: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
    ).apply(fontFamily: fontFamily),
  );
}
