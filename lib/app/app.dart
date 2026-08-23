import 'package:flutter/material.dart';

import '../features/splash/screens/splash_screen.dart';
import 'app_theme.dart';

/// Alternatif entry (tema Material 3 full). Entry aktif ada di main.dart.
class MPortApp extends StatelessWidget {
  const MPortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MPorT Go',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}
