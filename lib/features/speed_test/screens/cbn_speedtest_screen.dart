import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/security/security_config.dart';
import '../models/test_server.dart';

/// Screen that embeds an external CBN / third-party speedtest page via WebView.
/// Navigation is restricted to the selected server's host (and subdomains).
class CbnSpeedtestScreen extends StatefulWidget {
  final TestServer server;

  const CbnSpeedtestScreen({super.key, required this.server});

  @override
  State<CbnSpeedtestScreen> createState() => _CbnSpeedtestScreenState();
}

class _CbnSpeedtestScreenState extends State<CbnSpeedtestScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  String get _allowedHost {
    final h = widget.server.host
        .toLowerCase()
        .replaceFirst(RegExp(r'^https?://'), '')
        .split(':')
        .first
        .split('/')
        .first;
    return h;
  }

  bool _isAllowed(String? url) {
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('about:') || url.startsWith('data:')) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return true;
    final allowed = _allowedHost;
    return host == allowed || host.endsWith('.$allowed');
  }

  @override
  void initState() {
    super.initState();
    final raw = widget.server.externalUrl ??
        'https://${widget.server.host}/';
    final url = SecurityConfig.preferHttps(raw);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_isAllowed(request.url)) {
              return NavigationDecision.navigate;
            }
            SecurityConfig.log('CBN WebView blocked: ${request.url}');
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Text(
          widget.server.name,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00E5A0),
              ),
            ),
        ],
      ),
    );
  }
}
