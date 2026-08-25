import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_theme.dart';
import 'core/notifications/test_notification_service.dart';
import 'core/theme/theme_controller.dart';
import 'features/splash/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeController.instance.load();
  await TestNotificationService.instance.init();

  runApp(const MPortApp());
}

class MPortApp extends StatelessWidget {
  const MPortApp({super.key});

  bool _isDark(ThemeMode mode) {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final mode = ThemeController.instance.mode;
        final dark = _isDark(mode);
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor:
                dark ? const Color(0xFF06080F) : const Color(0xFFF4F7FA),
            systemNavigationBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          title: 'MPorT Go',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
