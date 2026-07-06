import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_theme.dart';

class OceanBabyMaterialApp extends StatelessWidget {
  const OceanBabyMaterialApp({
    super.key,
    required this.home,
    this.oceanTheme = OceanTheme.tiffanyBlue,
  });

  final Widget home;
  final OceanTheme oceanTheme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ocean Baby',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: OceanBabyTheme.build(oceanTheme),
      home: home,
    );
  }
}
