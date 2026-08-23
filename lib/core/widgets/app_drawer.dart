import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../features/about/screens/about_screen.dart';
import '../../features/downdetector/screens/downdetector_screen.dart';
import '../../features/server/screens/server_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/speed_test/screens/main_screen.dart';

/// Menu hamburger bersama — dipakai di semua halaman utama.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1A2030)),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.speed_rounded, color: AppColors.green, size: 36),
                  SizedBox(height: 12),
                  Text(
                    'MPorT Go',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Menu',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
                    icon: Icons.dns_outlined,
                    title: 'Pilih Server',
                    onTap: () => _go(context, const ServerScreen()),
                  ),
                  _item(
                    context,
                    icon: Icons.report_problem_outlined,
                    title: 'Downdetector',
                    subtitle: 'Cek gangguan layanan',
                    onTap: () => _go(context, const DowndetectorScreen()),
                  ),
                  _item(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Pengaturan',
                    onTap: () => _go(context, const SettingsScreen()),
                  ),
                  const Divider(color: Color(0xFF1A2030)),
                  _item(
                    context,
                    icon: Icons.info_outline,
                    title: 'Tentang Aplikasi',
                    onTap: () => _go(context, const AboutScreen()),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '© 2026 MPorT',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.greenLight),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      onTap: onTap,
    );
  }

  static void _go(BuildContext context, Widget page) {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

/// Tombol hamburger standar — membuka drawer MainScreen.
Widget appMenuButton(BuildContext context) {
  return IconButton(
    tooltip: 'Menu',
    onPressed: () {
      final state = MainScreen.scaffoldKey.currentState;
      if (state != null) {
        state.openDrawer();
        return;
      }
      // Fallback jika tidak di dalam MainScreen
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    },
    icon: const Icon(Icons.menu, color: AppColors.textPrimary),
  );
}
