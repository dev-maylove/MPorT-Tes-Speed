import 'package:flutter/material.dart';

import '../core/theme/theme_controller.dart';
import '../features/splash/screens/splash_screen.dart';
import 'app_theme.dart';

/// Alternate entry — prefer [main.dart].
class MPortAppAlt extends StatelessWidget {
  const MPortAppAlt({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'MPorT Go',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
