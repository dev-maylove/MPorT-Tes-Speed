import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../maps/screens/maps_screen.dart';
import 'history_screen.dart';
import 'speed_test_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  /// Opened from the hamburger button in child tabs.
  static final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Switch bottom-nav tab from child screens (0=Speed, 1=History, 2=Maps).
  static void Function(int index)? switchTab;

  /// Jump to History and refresh the list (e.g. after a completed test).
  static void openHistory() {
    switchTab?.call(1);
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  final _historyKey = GlobalKey<HistoryScreenState>();
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    MainScreen.switchTab = _goToTab;
  }

  @override
  void dispose() {
    if (identical(MainScreen.switchTab, _goToTab)) {
      MainScreen.switchTab = null;
    }
    super.dispose();
  }

  void _goToTab(int index) {
    if (!mounted) return;
    setState(() => currentIndex = index.clamp(0, 2));
    if (index == 1) {
      _historyKey.currentState?.reload();
    }
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        key: MainScreen.scaffoldKey,
        backgroundColor: p.background,
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
          backgroundColor: p.background,
          selectedIndex: currentIndex,
          onDestinationSelected: _goToTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed),
              label: 'Speed Test',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
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
