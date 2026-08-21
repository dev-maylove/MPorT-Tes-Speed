import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/server_config.dart';
import '../../../core/widgets/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const AppLogo(size: 64, showText: false),
            const SizedBox(height: 16),
            Text(
              AppConstants.appName,
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Versi ${AppConstants.appVersion} (${AppConstants.appBuild})',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(
              'Aplikasi pengujian kecepatan internet akurat.\n'
              'Menggunakan server ${ServerConfig.serverName}.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Server'),
              subtitle: Text(ServerConfig.baseUrl),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Download endpoint'),
              subtitle: Text(ServerConfig.downloadPath),
            ),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Upload endpoint'),
              subtitle: Text(ServerConfig.uploadPath),
            ),
            const Spacer(),
            Text(
              '© 2026 MPorT · MIT License',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
