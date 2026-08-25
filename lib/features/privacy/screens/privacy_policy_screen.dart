import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_footer.dart';

/// Full in-app Privacy Policy for MPorT Go (English).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _bg = Color(0xFF0B0B0F);
  static const _card = Color(0xFF15151C);
  static const _green = Color(0xFF00E5A0);
  static const _muted = Color(0xFF9A9AA6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? _bg : theme.scaffoldBackgroundColor;
    final card = isDark ? _card : theme.cardColor;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final bodyColor = isDark ? _muted : theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: titleColor,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: titleColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(card, bodyColor),
              const SizedBox(height: 20),
              _section(
                card,
                titleColor,
                bodyColor,
                '1. Introduction',
                'MPorT Go (“App”, “we”, “us”) is an internet speed testing application '
                'designed to measure latency (ping), download, and upload performance '
                'on your device.\n\n'
                'This Privacy Policy explains what data we process, for what purposes, '
                'how data is stored, and your rights as a user. By installing and using '
                'MPorT Go, you acknowledge the practices described in this policy.\n\n'
                'Last updated: August 25, 2026\n'
                'App version: ${AppConstants.appVersion}+${AppConstants.appBuild}',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '2. Data We Process',
                'MPorT Go is built with data minimization in mind. We do not require a '
                'user account or login.\n\n'
                '2.1 Data processed on your device (local only)\n'
                '• Speed test results: ping, jitter, download, upload, packet loss, '
                'test time, and selected server.\n'
                '• App preferences: speed unit, gauge scale, multi-connection mode, '
                'theme (light / dark / system).\n'
                '• Test history: stored in local device storage (SharedPreferences), '
                'limited to about 100 entries.\n\n'
                '2.2 Technical network data (required to run tests)\n'
                '• Your public IP address may be visible to the test server when HTTP '
                'connections are made (normal internet behavior).\n'
                '• Wi‑Fi network name (SSID) may be read on the device if location or '
                'Nearby Wi‑Fi Devices permission is granted, solely to show a connection '
                'label on the test screen. SSID is not sent to MPorT servers for marketing.\n'
                '• Connection type (Wi‑Fi / mobile / ethernet) is detected via system APIs.\n\n'
                '2.3 Device data\n'
                '• Device model (e.g. from device_info) may be shown in the UI and stored '
                'in local history.\n\n'
                '2.4 Data we do NOT collect\n'
                '• We do not collect your name, email, phone number, or other personal '
                'identity details.\n'
                '• We do not sell user data.\n'
                '• We do not show third-party ads in the core test flow.\n'
                '• We do not record precise GPS location for movement tracking.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '3. Permissions We Request',
                '3.1 Internet & network state\n'
                'Required to send and receive speed-test traffic to the test server.\n\n'
                '3.2 Location (while in use) / Nearby Wi‑Fi Devices\n'
                'On Android, reading the Wi‑Fi SSID requires location permission or '
                'NEARBY_WIFI_DEVICES (depending on OS version). This permission is used '
                'only to display the network name in the UI. You may deny it; the app '
                'still works, but the Wi‑Fi label may fall back to a generic “Wi‑Fi” text.\n\n'
                '3.3 Notifications\n'
                'Optional. If granted, the app may show a local notification when a test '
                'finishes, including a short summary of results (download, upload, ping). '
                'Notifications are generated on-device and do not require a cloud account.\n\n'
                '3.4 Wake lock (technical)\n'
                'Used temporarily during a test so measurement is less likely to be '
                'interrupted when the screen dims on some devices.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '4. How Tests Work & Third Parties',
                'When you run a test, your device sends network requests to the test '
                'server configured in the app (download / upload / ping endpoints).\n\n'
                'Test servers and intermediate networks (your ISP, CDNs, etc.) may '
                'technically observe connection metadata such as IP address, timing, and '
                'data volume — the same as when you open any website.\n\n'
                'If ISP/ASN lookup is enabled, the app may call a public geo-IP/ASN '
                'service to display your ISP name. Responses may be cached locally on '
                'the device to reduce repeated calls.\n\n'
                'We do not control the privacy policies of third-party servers or '
                'services outside the developer’s control. Use networks you trust.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '5. Storage & Security',
                '• History and preferences are stored locally on your device.\n'
                '• Local data may be lost if you uninstall the app or clear app data '
                'from system settings.\n'
                '• We apply reasonable client-side practices (timeouts, error handling), '
                'but no internet transmission is 100% risk-free.\n'
                '• Keep your OS and the app updated when possible.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '6. Data Retention',
                '• Test history is kept until you delete it in the History tab, or clear '
                'app data / uninstall the app.\n'
                '• Entry count is capped (about 100) to keep storage light.\n'
                '• Local ISP/ASN cache is temporary and may refresh when the network '
                'changes.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '7. Your Rights',
                'You may:\n'
                '• Deny or revoke location and notification permissions at any time via '
                'your device system settings.\n'
                '• Delete test history inside the app.\n'
                '• Clear all app data via Android/iOS system settings.\n'
                '• Stop using the app by uninstalling it.\n\n'
                'Because we do not operate a centralized user account system, “delete my '
                'cloud account” requests do not apply; primary control remains on your '
                'device.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '8. Children',
                'The app is not directed at children under 13 (or the minimum age required '
                'in your jurisdiction). We do not knowingly collect personal data from '
                'children. If you are a parent or guardian and believe a child has used '
                'the app in a way that concerns you, stop use and clear app data on the '
                'device.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '9. Changes to This Policy',
                'We may update this Privacy Policy from time to time, for example when '
                'features change or legal requirements evolve. The latest version will be '
                'shown on this page inside the app. Continued use after changes means you '
                'understand the updated policy.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '10. Contact',
                'For privacy questions about MPorT Go, contact the developer through the '
                'official channels listed on the About page in the app, or via the '
                'store/distribution channel where you downloaded the app.\n\n'
                'Developer: DeV_MaYLoVe\n'
                'Application: ${AppConstants.appName}\n'
                'Version: ${AppConstants.appVersion}+${AppConstants.appBuild}',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '11. Short Summary',
                '• Speed tests require an internet connection.\n'
                '• Results and preferences are stored on your device.\n'
                '• Location permission is only for showing Wi‑Fi SSID (optional).\n'
                '• Result notifications are local and optional.\n'
                '• We do not sell your personal data.',
              ),
              const SizedBox(height: 16),
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Color card, Color bodyColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.privacy_tip_outlined, color: _green, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'MPorT Go Privacy Policy',
                  style: TextStyle(
                    color: _green,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Transparency about data, permissions, and how this internet speed test app works.',
            style: TextStyle(color: bodyColor, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _section(
    Color card,
    Color titleColor,
    Color bodyColor,
    String title,
    String body,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: bodyColor,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
