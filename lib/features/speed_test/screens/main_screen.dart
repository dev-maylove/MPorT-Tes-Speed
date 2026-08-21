import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../maps/screens/maps_screen.dart';
import 'history_screen.dart';
import 'speed_test_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  /// Dibuka dari tombol hamburger di tab anak.
  static final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  final _historyKey = GlobalKey<HistoryScreenState>();
  DateTime? _lastBackPress;

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ketuk sekali lagi untuk keluar'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
    // Keluar aplikasi
    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        key: MainScreen.scaffoldKey,
        backgroundColor: AppColors.background,
        drawer: const AppDrawer(),
        body: IndexedStack(
          index: currentIndex,
          children: [
            const SpeedTestScreen(),
            HistoryScreen(key: _historyKey),
            const MapsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppColors.background,
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            setState(() => currentIndex = index);
            if (index == 1) {
              _historyKey.currentState?.reload();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed),
              label: 'Tes Speed',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Riwayat',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Maps',
            ),
          ],
        ),
      ),
    );
  }
}
