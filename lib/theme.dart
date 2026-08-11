import 'package:flutter/material.dart';

/// Arul brand red.
const Color kArulRed = Color(0xFFE1131D);
const Color kInk = Color(0xFF15171A);
const Color kSurface = Color(0xFF1E2126);

const String kAppVersion = '1.1';

ThemeData buildArulTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Inter'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Inter'),
    colorScheme: ColorScheme.fromSeed(
      seedColor: kArulRed,
      brightness: Brightness.dark,
    ).copyWith(primary: kArulRed, surface: kSurface),
    scaffoldBackgroundColor: kInk,
    appBarTheme: const AppBarTheme(
      backgroundColor: kInk,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: Colors.white,
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Colors.white70),
    dividerTheme: const DividerThemeData(color: Colors.white12, space: 1),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kSurface,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
