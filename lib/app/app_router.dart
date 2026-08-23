import 'package:flutter/material.dart';

import '../features/speed_test/screens/history_screen.dart';
import '../features/speed_test/screens/main_screen.dart';
import '../features/server/screens/server_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/about/screens/about_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String history = '/history';
  static const String server = '/server';
  static const String settings = '/settings';
  static const String about = '/about';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case history:
        return MaterialPageRoute(builder: (_) => const HistoryScreen());
      case server:
        return MaterialPageRoute(builder: (_) => const ServerScreen());
      case AppRouter.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case about:
        return MaterialPageRoute(builder: (_) => const AboutScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
