import 'package:flutter/material.dart';

import '../features/speed_test/screens/main_screen.dart';
import 'app_theme.dart';

/// Alternatif entry (tema Material 3 full). Entry aktif ada di main.dart.
class MPortApp extends StatelessWidget {
  const MPortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MPorT Tes Speed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const MainScreen(),
    );
  }
}
