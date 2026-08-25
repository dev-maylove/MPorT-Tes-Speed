import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/permissions/app_permissions.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_footer.dart';
import '../../about/screens/about_screen.dart';
import '../../downdetector/screens/downdetector_screen.dart';
import '../../privacy/screens/privacy_policy_screen.dart';
import '../widgets/settings_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _speedUnit = 'Mbps';
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

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  Future<void> _setTheme(ThemeMode mode) async {
    await ThemeController.instance.setMode(mode);
    if (mounted) setState(() {});
  }

  Future<void> _onLocationTap() async {
    setState(() => _permLoading = true);
    await AppPermissions.openLocationSettingsFlow();
    await _refreshPermissionStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _locGranted
              ? 'Location permission is on'
              : 'Open phone settings → enable Location for MPorT Go',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onNotificationTap() async {
    setState(() => _permLoading = true);
    await AppPermissions.openNotificationSettingsFlow();
    await _refreshPermissionStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _notifGranted
              ? 'Notification permission is on'
              : 'Open phone settings → enable Notifications for MPorT Go',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ThemeController.instance.mode;
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: cs.onSurface,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const _SectionHeader(title: 'General'),
          SettingsTile(
            icon: Icons.speed_rounded,
            title: 'Speed Unit',
            subtitle: _speedUnit,
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _speedUnit,
                dropdownColor: theme.cardColor,
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                items: const [
                  DropdownMenuItem(value: 'Mbps', child: Text('Mbps')),
                  DropdownMenuItem(value: 'MB/s', child: Text('MB/s')),
                  DropdownMenuItem(value: 'kB/s', child: Text('kB/s')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _speedUnit = v);
                },
              ),
            ),
          ),
          // Theme: dropdown only (no duplicate Light/Dark chips)
          SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: _themeLabel(themeMode),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<ThemeMode>(
                value: themeMode,
                dropdownColor: theme.cardColor,
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) _setTheme(v);
                },
              ),
            ),
          ),
          Divider(color: theme.dividerColor),
          const _SectionHeader(title: 'Permissions'),
          SettingsTile(
            icon: Icons.location_on_outlined,
            title: 'Location',
            subtitle: _permLoading
                ? 'Checking…'
                : (_locGranted
                    ? 'On — required for Wi-Fi name (SSID)'
                    : 'Off — tap to open location settings'),
            onTap: _onLocationTap,
          ),
          SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: _permLoading
                ? 'Checking…'
                : (_notifGranted
                    ? 'On — test result notifications'
                    : 'Off — tap to open notification settings'),
            onTap: _onNotificationTap,
          ),
          SettingsTile(
            icon: Icons.settings_applications_outlined,
            title: 'Open app settings',
            subtitle: 'All app permissions in system settings',
            onTap: () => AppPermissions.openSettings(),
          ),
          Divider(color: theme.dividerColor),
          const _SectionHeader(title: 'About'),
          SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About MPorT Go',
            subtitle: 'v${AppConstants.appVersion}+${AppConstants.appBuild}',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              );
            },
          ),
          SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          SettingsTile(
            icon: Icons.network_check_rounded,
            title: 'Down Detector',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DowndetectorScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const AppFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: cs.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
