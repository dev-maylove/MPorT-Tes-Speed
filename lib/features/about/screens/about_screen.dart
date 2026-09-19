import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_footer.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const Color primaryColor = Color(0xFF00E5A0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final on = cs.onSurface;
    final muted = cs.onSurfaceVariant;
    final card = theme.cardColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        foregroundColor: on,
        title: Text(
          'About',
          style: TextStyle(
            color: on,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: on),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            children: [
              _Header(on: on, muted: muted),
              const SizedBox(height: 20),
              _Card(
                color: card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(title: 'About MPorT', on: on),
                    const SizedBox(height: 10),
                    Text(
                      'MPorT Go is an app for measuring internet '
                      'connection performance in a practical way. '
                      'It helps you check download speed, upload speed, '
                      'ping, and the overall quality of the connection '
                      'you are using.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Card(
                color: card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(title: 'Main Features', on: on),
                    const SizedBox(height: 12),
                    _Feature(
                      icon: Icons.download_rounded,
                      title: 'Download Speed',
                      description: 'Measure your internet download speed.',
                      on: on,
                      muted: muted,
                    ),
                    _Feature(
                      icon: Icons.upload_rounded,
                      title: 'Upload Speed',
                      description: 'Measure your internet upload speed.',
                      on: on,
                      muted: muted,
                    ),
                    _Feature(
                      icon: Icons.network_ping,
                      title: 'Ping / Latency',
                      description: 'Check connection responsiveness.',
                      on: on,
                      muted: muted,
                    ),
                    _Feature(
                      icon: Icons.dns_rounded,
                      title: 'Server Selection',
                      description: 'Shows the server used for the test.',
                      on: on,
                      muted: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Card(
                color: card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(title: 'App Information', on: on),
                    const SizedBox(height: 12),
                    _InfoRow(title: 'App name', value: AppConstants.appName, on: on, muted: muted),
                    _InfoRow(title: 'Version', value: AppConstants.appVersion, on: on, muted: muted),
                    _InfoRow(
                      title: 'Build',
                      value: AppConstants.appBuild,
                      on: on,
                      muted: muted,
                    ),
                    _InfoRow(
                      title: 'Platform',
                      value: 'Android',
                      on: on,
                      muted: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Card(
                color: card,
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.12),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: primaryColor,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DeV_MaYLoVe',
                            style: TextStyle(
                              color: on,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Developer & Technology',
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Color on;
  final Color muted;
  const _Header({required this.on, required this.muted});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/mport_logo.png',
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AboutScreen.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.speed, color: AboutScreen.primaryColor, size: 40),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'MPorT Go',
          style: TextStyle(
            color: on,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Internet Speed Test',
          style: TextStyle(
            color: AboutScreen.primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Measure your internet speed easily,\nquickly, and comfortably.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Card({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color on;
  const _SectionTitle({required this.title, required this.on});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: on,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color on;
  final Color muted;

  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
    required this.on,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AboutScreen.primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: on,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;
  final Color on;
  final Color muted;

  const _InfoRow({
    required this.title,
    required this.value,
    required this.on,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: TextStyle(color: muted, fontSize: 13)),
          ),
          Text(
            value,
            style: TextStyle(
              color: on,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
