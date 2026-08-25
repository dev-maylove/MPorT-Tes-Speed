import 'package:flutter/material.dart';

import '../../features/about/screens/about_screen.dart';
import '../../features/downdetector/screens/downdetector_screen.dart';
import '../../features/privacy/screens/privacy_policy_screen.dart';
import '../../features/server/screens/server_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/speed_test/screens/main_screen.dart';
import '../theme/app_colors.dart';
import 'app_footer.dart';

/// Shared hamburger menu used on main screens.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Drawer(
      backgroundColor: p.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: p.background,
                border: Border(bottom: BorderSide(color: p.divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.speed_rounded, color: p.primary, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'MPorT Go',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Menu',
                    style: TextStyle(color: p.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _item(
                    context,
                    p,
                    icon: Icons.dns_outlined,
                    title: 'Select Server',
                    onTap: () => _go(context, const ServerScreen()),
                  ),
                  _item(
                    context,
                    p,
                    icon: Icons.report_problem_outlined,
                    title: 'Downdetector',
                    subtitle: 'Check service outages',
                    onTap: () => _go(context, const DowndetectorScreen()),
                  ),
                  _item(
                    context,
                    p,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => _go(context, const SettingsScreen()),
                  ),
                  Divider(color: p.divider),
                  _item(
                    context,
                    p,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'How we handle data',
                    onTap: () => _go(context, const PrivacyPolicyScreen()),
                  ),
                  _item(
                    context,
                    p,
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () => _go(context, const AboutScreen()),
                  ),
                ],
              ),
            ),
            const AppFooter(compact: true),
          ],
        ),
      ),
    );
  }

  static Widget _item(
    BuildContext context,
    AppPalette p, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: p.icon),
      title: Text(
        title,
        style: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(color: p.textMuted, fontSize: 12),
            ),
      onTap: onTap,
    );
  }

  static void _go(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

/// Standard hamburger button — opens the MainScreen drawer.
Widget appMenuButton(BuildContext context) {
  final p = AppPalette.of(context);
  return IconButton(
    tooltip: 'Menu',
    onPressed: () {
      final state = MainScreen.scaffoldKey.currentState;
      if (state != null) {
        state.openDrawer();
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );
    },
    icon: Icon(Icons.menu, color: p.textPrimary),
  );
}
