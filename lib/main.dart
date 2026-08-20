import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/speed_test/screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MporTApp());
}

class MporTApp extends StatelessWidget {
  const MporTApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MPorT Tes Speed',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF080808),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
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
      home: const MainScreen(),
    );
  }
}
