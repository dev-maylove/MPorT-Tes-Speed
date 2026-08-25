import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/permissions/app_permissions.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_footer.dart';
import '../../about/screens/about_screen.dart';
import '../../privacy/screens/privacy_policy_screen.dart';
import '../../downdetector/screens/downdetector_screen.dart';
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
              ? 'Izin lokasi aktif'
              : 'Buka pengaturan HP → aktifkan Lokasi untuk MPorT Go',
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
              ? 'Izin notifikasi aktif'
              : 'Buka pengaturan HP → aktifkan Notifikasi untuk MPorT Go',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ThemeController.instance.mode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
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
              dropdownColor: theme.cardColor,
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
          SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: _themeLabel(themeMode),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
              dropdownColor: theme.cardColor,
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
          // Quick light / dark toggle chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _ThemeChip(
                    label: 'Light',
                    icon: Icons.light_mode_rounded,
                    selected: themeMode == ThemeMode.light,
                    onTap: () => _setTheme(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ThemeChip(
                    label: 'Dark',
                    icon: Icons.dark_mode_rounded,
                    selected: themeMode == ThemeMode.dark,
                    onTap: () => _setTheme(ThemeMode.dark),
                  ),
                ),
              ],
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
                    ? 'Aktif — dibutuhkan untuk nama Wi-Fi (SSID)'
                    : 'Nonaktif — ketuk untuk buka pengaturan lokasi HP'),
            onTap: _onLocationTap,
          ),
          SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: _permLoading
                ? 'Checking…'
                : (_notifGranted
                    ? 'Aktif — notifikasi hasil tes'
                    : 'Nonaktif — ketuk untuk buka pengaturan notifikasi HP'),
            onTap: _onNotificationTap,
          ),
          SettingsTile(
            icon: Icons.settings_applications_outlined,
            title: 'Open app settings',
            subtitle: 'Semua izin aplikasi di sistem',
            onTap: () async {
              await AppPermissions.openSettings();
              await _refreshPermissionStatus();
            },
          ),
          const Divider(),
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
                    builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
          SettingsTile(
            icon: Icons.network_check_rounded,
            title: 'Down Detector',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const DowndetectorScreen()),
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

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Material(
      color: selected
          ? primary.withValues(alpha: 0.15)
          : theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? primary
                  : theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? primary
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
