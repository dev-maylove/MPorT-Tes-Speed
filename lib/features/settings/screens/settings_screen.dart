import 'package:flutter/material.dart';
import '../../../app/app_router.dart';
import '../../../core/constants/app_constants.dart';
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
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _SectionHeader(title: 'Umum'),
          SettingsTile(
            icon: Icons.speed_rounded,
            title: 'Satuan Kecepatan',
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
            title: 'Tema',
            subtitle: _themeLabel(_themeMode),
            trailing: DropdownButton<ThemeMode>(
              value: _themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('Sistem')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Terang')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Gelap')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _themeMode = v);
              },
            ),
          ),
          const Divider(),
          _SectionHeader(title: 'Lainnya'),
          SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Tentang Aplikasi',
            subtitle: 'Versi ${AppConstants.appVersion}',
            onTap: () => Navigator.pushNamed(context, AppRouter.about),
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
        return 'Ikuti sistem';
      case ThemeMode.light:
        return 'Terang';
      case ThemeMode.dark:
        return 'Gelap';
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
