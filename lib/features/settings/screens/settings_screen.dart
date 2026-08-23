import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
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
          Center(
            child: Text(
              '© 2026 MPorT',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
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
