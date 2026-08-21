import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/test_server.dart';

/// Screen that embeds an external CBN / third-party speedtest page via WebView.
class CbnSpeedtestScreen extends StatefulWidget {
  final TestServer server;

  const CbnSpeedtestScreen({super.key, required this.server});

  @override
  State<CbnSpeedtestScreen> createState() => _CbnSpeedtestScreenState();
}

class _CbnSpeedtestScreenState extends State<CbnSpeedtestScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final url = widget.server.externalUrl ??
        'https://${widget.server.host}/';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
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
