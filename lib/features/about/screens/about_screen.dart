import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_footer.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Aligned with MPorT theme (green) + premium accent
  static const Color primaryColor = Color(0xFF00E5A0);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color darkBackground = Color(0xFF0B0B0F);
  static const Color cardColor = Color(0xFF15151C);
  static const Color secondaryText = Color(0xFF9A9AA6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'About',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildDescription(),
              const SizedBox(height: 20),
              _buildFeatures(),
              const SizedBox(height: 20),
              _buildAppInfo(),
              const SizedBox(height: 20),
              _buildDeveloperCard(),
              const SizedBox(height: 12),
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 3,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/images/mport_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'MPorT Go',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Internet Speed Test',
          style: TextStyle(
            color: primaryColor.withValues(alpha: 0.95),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Measure your internet speed easily,\nquickly, and comfortably.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: secondaryText,
            height: 1.5,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.info_outline_rounded,
            title: 'About MPorT',
          ),
          const SizedBox(height: 14),
          const Text(
            'MPorT Go is an app for measuring internet '
            'connection performance in a practical way. '
            'It helps you check download speed, upload speed, '
            'ping, and the overall quality of the connection '
            'you are using.',
            style: TextStyle(
              color: Color(0xFFB8B8C2),
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.auto_awesome_rounded,
            title: 'Main Features',
          ),
          const SizedBox(height: 16),
          _featureItem(
            icon: Icons.download_rounded,
            title: 'Download Speed',
            description: 'Measure your internet download speed.',
          ),
          _featureItem(
            icon: Icons.upload_rounded,
            title: 'Upload Speed',
            description: 'Measure your internet upload speed.',
          ),
          _featureItem(
            icon: Icons.network_ping_rounded,
            title: 'Ping / Latency',
            description: 'Check connection responsiveness.',
          ),
          _featureItem(
            icon: Icons.show_chart_rounded,
            title: 'Jitter',
            description: 'See how stable your network connection is.',
          ),
          _featureItem(
            icon: Icons.dns_rounded,
            title: 'Server Test',
            description: 'Shows the server used for the test.',
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.phone_android_rounded,
            title: 'App Information',
          ),
          const SizedBox(height: 14),
          _infoRow(
            title: 'App Name',
            value: AppConstants.appName,
          ),
          _infoRow(
            title: 'Version',
            value: AppConstants.appVersion,
          ),
          _infoRow(
            title: 'Platform',
            value: 'Android',
          ),
          _infoRow(
            title: 'Category',
            value: 'Internet / Speed Test',
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.code_rounded,
            title: 'Developer',
          ),
          const SizedBox(height: 16),
          Row(
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DeV_MaYLoVe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Developer & Technology',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: child,
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _featureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: secondaryText,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
