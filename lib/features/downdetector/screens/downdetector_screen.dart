import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';

/// Halaman cek gangguan layanan (gaya Downdetector / Ookla Outage Map).
class DowndetectorScreen extends StatefulWidget {
  const DowndetectorScreen({super.key});

  @override
  State<DowndetectorScreen> createState() => _DowndetectorScreenState();
}

class _ServiceItem {
  final String name;
  final String slug;
  final IconData icon;
  final Color color;

  const _ServiceItem(this.name, this.slug, this.icon, this.color);
}

class _DowndetectorScreenState extends State<DowndetectorScreen> {
  static const _services = <_ServiceItem>[
    _ServiceItem('WhatsApp', 'whatsapp', Icons.chat, Color(0xFF25D366)),
    _ServiceItem('Instagram', 'instagram', Icons.camera_alt, Color(0xFFE1306C)),
    _ServiceItem('Facebook', 'facebook', Icons.facebook, Color(0xFF1877F2)),
    _ServiceItem('YouTube', 'youtube', Icons.play_circle_fill, Color(0xFFFF0000)),
    _ServiceItem('TikTok', 'tiktok', Icons.music_note, Color(0xFF69C9D0)),
    _ServiceItem('Twitter / X', 'twitter', Icons.alternate_email, Color(0xFF1DA1F2)),
    _ServiceItem('Gmail', 'gmail', Icons.email, Color(0xFFEA4335)),
    _ServiceItem('Google', 'google', Icons.search, Color(0xFF4285F4)),
    _ServiceItem('Shopee', 'shopee', Icons.shopping_bag, Color(0xFFEE4D2D)),
    _ServiceItem('Tokopedia', 'tokopedia', Icons.storefront, Color(0xFF42B549)),
    _ServiceItem('GoJek', 'gojek', Icons.motorcycle, Color(0xFF00AA13)),
    _ServiceItem('Telkomsel', 'telkomsel', Icons.signal_cellular_alt, Color(0xFFED1C24)),
    _ServiceItem('XL Axiata', 'xl', Icons.signal_cellular_alt, Color(0xFF1D8A4A)),
    _ServiceItem('Indosat', 'indosat', Icons.signal_cellular_alt, Color(0xFFFFD100)),
    _ServiceItem('PLN', 'pln', Icons.bolt, Color(0xFFF7C600)),
    _ServiceItem('Bank BCA', 'bca', Icons.account_balance, Color(0xFF005CAF)),
  ];

  String? _activeSlug;
  String? _activeName;
  WebViewController? _web;
  bool _loadingWeb = false;

  Future<void> _openService(_ServiceItem s) async {
    setState(() {
      _activeSlug = s.slug;
      _activeName = s.name;
      _loadingWeb = true;
      _web = null;
    });

    final url = 'https://downdetector.id/gangguan/${s.slug}/';
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loadingWeb = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loadingWeb = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() => _web = c);
  }

  void _backToList() {
    setState(() {
      _activeSlug = null;
      _activeName = null;
      _web = null;
      _loadingWeb = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showingWeb = _activeSlug != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: Icon(
            showingWeb ? Icons.arrow_back : Icons.close,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (showingWeb) {
              _backToList();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          showingWeb ? (_activeName ?? 'Downdetector') : 'Downdetector',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (showingWeb)
            IconButton(
              tooltip: 'Buka di browser',
              icon: const Icon(Icons.open_in_browser, color: AppColors.greenLight),
              onPressed: () {
                // WebView already shows the page; user can long-press links
              },
            ),
        ],
      ),
      body: showingWeb ? _buildWeb() : _buildList(),
    );
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.report_problem_outlined, color: AppColors.green, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cek Gangguan Layanan',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Pilih layanan untuk melihat laporan gangguan terkini (data dari Downdetector).',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemCount: _services.length,
            itemBuilder: (context, i) {
              final s = _services[i];
              return Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openService(s),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(s.icon, color: s.color, size: 28),
                        const Spacer(),
                        Text(
                          s.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Cek status →',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeb() {
    return Stack(
      children: [
        if (_web != null) WebViewWidget(controller: _web!),
        if (_loadingWeb)
          const Center(
            child: CircularProgressIndicator(color: AppColors.green),
          ),
      ],
    );
  }
}
