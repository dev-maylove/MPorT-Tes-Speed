import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Selaras dengan tema MPorT (hijau) + aksen premium
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
          'Tentang Aplikasi',
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
              const SizedBox(height: 28),
              _buildCopyright(),
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
          'MPorT Speed Test',
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
          'Uji kecepatan internet dengan mudah,\ncepat, dan nyaman.',
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
            title: 'Tentang MPorT',
          ),
          const SizedBox(height: 14),
          const Text(
            'MPorT Speed Test adalah aplikasi untuk mengukur '
            'performa koneksi internet secara praktis. '
            'Aplikasi ini membantu mengetahui kecepatan download, '
            'upload, ping, dan kualitas koneksi internet yang sedang digunakan.',
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
            title: 'Fitur Utama',
          ),
          const SizedBox(height: 16),
          _featureItem(
            icon: Icons.download_rounded,
            title: 'Download Speed',
            description: 'Mengukur kecepatan download internet.',
          ),
          _featureItem(
            icon: Icons.upload_rounded,
            title: 'Upload Speed',
            description: 'Mengukur kecepatan upload internet.',
          ),
          _featureItem(
            icon: Icons.network_ping_rounded,
            title: 'Ping / Latency',
            description: 'Mengetahui responsivitas koneksi.',
          ),
          _featureItem(
            icon: Icons.show_chart_rounded,
            title: 'Jitter',
            description: 'Melihat kestabilan koneksi jaringan.',
          ),
          _featureItem(
            icon: Icons.dns_rounded,
            title: 'Server Test',
            description: 'Menampilkan server yang digunakan untuk pengujian.',
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
            title: 'Informasi Aplikasi',
          ),
          const SizedBox(height: 14),
          _infoRow(
            title: 'Nama Aplikasi',
            value: AppConstants.appName,
          ),
          _infoRow(
            title: 'Versi',
            value: AppConstants.appVersion,
          ),
          _infoRow(
            title: 'Platform',
            value: 'Android',
          ),
          _infoRow(
            title: 'Engine',
            value: 'Flutter',
          ),
          _infoRow(
            title: 'Kategori',
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
            title: 'Pengembang',
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
                      'MPorT',
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

  Widget _buildCopyright() {
    return Column(
      children: [
        Container(
          width: 45,
          height: 1,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        const SizedBox(height: 18),
        const Text(
          'MPorT Speed Test',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '© 2026 MPorT. All rights reserved.',
          style: TextStyle(
            color: secondaryText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Made with Flutter',
          style: TextStyle(
            color: Color(0xFF777783),
            fontSize: 11,
          ),
        ),
      ],
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
