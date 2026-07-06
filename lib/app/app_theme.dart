import 'package:flutter/material.dart';

enum OceanTheme {
  burgundy('勃艮第红', Color(0xFF7B2330), Color(0xFFF0DEE2)),
  tiffanyBlue('蒂芙尼蓝', Color(0xFF0ABAB5), Color(0xFFDDF8F7)),
  shenlunYellow('申伦布黄', Color(0xFFD9A441), Color(0xFFFAECCA)),
  graphite('石墨灰', Color(0xFF3B3F45), Color(0xFFE4E6E8)),
  pineGreen('松针绿', Color(0xFF2F5D50), Color(0xFFDDEBE5));

  const OceanTheme(this.label, this.seedColor, this.backgroundColor);

  final String label;
  final Color seedColor;
  final Color backgroundColor;
}

class OceanBabyTheme {
  const OceanBabyTheme._();

  static ThemeData build(OceanTheme theme) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: theme.seedColor,
          brightness: Brightness.light,
        ).copyWith(
          surface: theme.backgroundColor,
          surfaceContainerLowest: const Color(0xFFFFFFFF),
          surfaceContainerLow: theme.backgroundColor,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: theme.backgroundColor,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: theme.backgroundColor,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: theme.backgroundColor,
        indicatorColor: colorScheme.primaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: theme.backgroundColor,
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }
}
