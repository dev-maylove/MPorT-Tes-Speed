import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/test_server.dart';

/// CBN uses the official Speedtest Custom web engine.
///
/// Important: the server card is the server discovered from CBN's API. The
/// Speedtest Custom page itself is responsible for selecting/using its
/// configured test server. We deliberately do not fake a server selection by
/// injecting undocumented query parameters.
class CbnSpeedtestScreen extends StatefulWidget {
  final TestServer server;

  const CbnSpeedtestScreen({super.key, required this.server});

  @override
  State<CbnSpeedtestScreen> createState() => _CbnSpeedtestScreenState();
}

class _CbnSpeedtestScreenState extends State<CbnSpeedtestScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _error = null);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            // isForMainFrame bertipe bool? — jangan pakai !value sebagai kondisi
            final isMainFrame = error.isForMainFrame;
            if (isMainFrame == false) return;
            if (!mounted) return;
            setState(() {
              _error = error.description.isEmpty
                  ? 'Gagal memuat mesin CBN.'
                  : error.description;
            });
          },
        ),
      )
      ..loadRequest(
        Uri.parse(
          widget.server.externalUrl ?? 'https://cbn.speedtestcustom.com',
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.server.name),
            Text(
              '${widget.server.host} · ${widget.server.country}',
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang mesin CBN',
            onPressed: () => _controller.reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_progress < 100)
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                value: _progress / 100,
                minHeight: 2,
              ),
            ),
          if (_error != null)
            Center(
              child: Card(
                color: const Color(0xFF171717),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.orangeAccent,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Mesin CBN gagal dimuat',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 280,
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() => _error = null);
                          _controller.reload();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
