import 'package:flutter/material.dart';

import '../features/speed_test/screens/main_screen.dart';
import 'app_router.dart';

class MporTApp extends StatelessWidget {
  const MporTApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFD4AF37);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MPorT Tes Speed',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF080808),
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: Color(0xFFF1D77A),
          surface: Color(0xFF111111),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF080808),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.generateRoute,
      // Keep a direct home fallback for embedders that don't use routes.
      home: const MainScreen(),
    );
  }
}
