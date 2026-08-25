import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/permissions/app_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_footer.dart';
import '../../about/screens/about_screen.dart';
import '../../downdetector/screens/downdetector_screen.dart';
import '../widgets/settings_tile.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _speedUnit = 'Mbps';
  ThemeMode _themeMode = ThemeMode.system;
  bool _locGranted = false;
  bool _notifGranted = false;
  bool _permLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
  }

  Future<void> _refreshPermissionStatus() async {
    final loc = await AppPermissions.isLocationGranted;
    final notif = await AppPermissions.isNotificationGranted;
    if (!mounted) return;
    setState(() {
      _locGranted = loc;
      _notifGranted = notif;
      _permLoading = false;
    });
  }

  Future<void> _requestPermissions() async {
    setState(() => _permLoading = true);
    await AppPermissions.requestAll();
    await _refreshPermissionStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _locGranted
              ? 'Permissions updated'
              : 'Some permissions still denied — open system settings if needed',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary))),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const _SectionHeader(title: 'General'),
          SettingsTile(
            icon: Icons.speed_rounded,
            title: 'Speed Unit',
            subtitle: _speedUnit,
            trailing: DropdownButton<String>(
              value: _speedUnit,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'Mbps', child: Text('Mbps')),
                DropdownMenuItem(value: 'Mb/s', child: Text('Mb/s')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _speedUnit = v);
              },
            ),
          ),
          SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: _themeLabel(_themeMode),
            trailing: DropdownButton<ThemeMode>(
              value: _themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _themeMode = v);
              },
            ),
          ),
          const Divider(),
          const _SectionHeader(title: 'Permissions'),
          SettingsTile(
            icon: Icons.location_on_outlined,
            title: 'Location',
            subtitle: _permLoading
                ? 'Checking…'
                : (_locGranted
                    ? 'Granted — needed for Wi-Fi SSID'
                    : 'Denied — Wi-Fi name may show as “Wi-Fi” only'),
            onTap: _requestPermissions,
          ),
          SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: _permLoading
                ? 'Checking…'
                : (_notifGranted ? 'Granted' : 'Denied — enable for test alerts'),
            onTap: _requestPermissions,
          ),
          SettingsTile(
            icon: Icons.settings_applications_outlined,
            title: 'Open system settings',
            subtitle: 'Enable permissions manually if dialog was dismissed',
            onTap: () => AppPermissions.openSettings(),
          ),
          const Divider(),
          const _SectionHeader(title: 'Network'),
          SettingsTile(
            icon: Icons.report_problem_outlined,
            title: 'Downdetector',
            subtitle: 'Check service outages',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DowndetectorScreen()),
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: 'Other'),
          SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'Version ${AppConstants.appVersion}',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          const AppFooter(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow system';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
