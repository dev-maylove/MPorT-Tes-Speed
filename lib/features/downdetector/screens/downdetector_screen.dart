import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_footer.dart';

/// Halaman Downdetector — daftar + sparkline realtime (probe latency).
class DowndetectorScreen extends StatefulWidget {
  const DowndetectorScreen({super.key});

  @override
  State<DowndetectorScreen> createState() => _DowndetectorScreenState();
}

class _ServiceItem {
  final String name;
  final String slug;
  /// Host for realtime probe (optional).
  final String? probeHost;
  final List<double> series; // 0..1
  bool warning;
  bool starred;
  double? lastMs;

  _ServiceItem({
    required this.name,
    required this.slug,
    this.probeHost,
    required this.series,
    this.starred = false,
  })  : warning = false,
        lastMs = null;
}

class _DowndetectorScreenState extends State<DowndetectorScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  late List<_ServiceItem> _services;
  Timer? _timer;
  bool _probing = false;
  DateTime? _lastUpdate;
  int _probeIndex = 0;

  String? _activeSlug;
  String? _activeName;
  WebViewController? _web;
  bool _loadingWeb = false;

  static const _maxPoints = 30;
  static const _probeTimeout = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _services = _buildServices();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
    // Probe awal + interval realtime
    WidgetsBinding.instance.addPostFrameCallback((_) => _tickProbe());
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _tickProbe());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_ServiceItem> _buildServices() {
    List<double> seed() =>
        List.filled(_maxPoints, 0.15, growable: true);

    return [
      _ServiceItem(
        name: 'Telkom',
        slug: 'telkom-indonesia',
        probeHost: 'www.telkom.co.id',
        series: seed(),
        starred: true,
      ),
      _ServiceItem(
        name: 'Biznet',
        slug: 'biznet',
        probeHost: 'www.biznetnetworks.com',
        series: seed(),
        starred: true,
      ),
      _ServiceItem(
        name: 'XL',
        slug: 'xl',
        probeHost: 'www.xl.co.id',
        series: seed(),
        starred: true,
      ),
      _ServiceItem(
        name: 'Roblox',
        slug: 'roblox',
        probeHost: 'www.roblox.com',
        series: seed(),
        starred: true,
      ),
      _ServiceItem(
        name: 'Indosat Ooredoo',
        slug: 'indosat',
        probeHost: 'www.indosatooredoo.com',
        series: seed(),
        starred: true,
      ),
      _ServiceItem(
        name: 'TikTok',
        slug: 'tiktok',
        probeHost: 'www.tiktok.com',
        series: seed(),
        starred: true,
      ),
      _ServiceItem(
        name: 'Telkomsel',
        slug: 'telkomsel',
        probeHost: 'www.telkomsel.com',
        series: seed(),
        starred: true,
      ),
      _ServiceItem(
        name: 'MyRepublic',
        slug: 'myrepublic',
        probeHost: 'myrepublic.co.id',
        series: seed(),
        starred: true,
      ),
      _ServiceItem(
        name: 'Tri (3)',
        slug: '3',
        probeHost: 'www.tri.co.id',
        series: seed(),
        starred: true,
      ),
      _ServiceItem(
        name: 'WhatsApp',
        slug: 'whatsapp',
        probeHost: 'web.whatsapp.com',
        series: seed(),
      ),
      _ServiceItem(
        name: 'Instagram',
        slug: 'instagram',
        probeHost: 'www.instagram.com',
        series: seed(),
      ),
      _ServiceItem(
        name: 'YouTube',
        slug: 'youtube',
        probeHost: 'www.youtube.com',
        series: seed(),
      ),
      _ServiceItem(
        name: 'Facebook',
        slug: 'facebook',
        probeHost: 'www.facebook.com',
        series: seed(),
      ),
      _ServiceItem(
        name: 'Google',
        slug: 'google',
        probeHost: 'www.google.com',
        series: seed(),
      ),
      _ServiceItem(
        name: 'Gojek',
        slug: 'gojek',
        probeHost: 'www.gojek.com',
        series: seed(),
      ),
      _ServiceItem(
        name: 'Shopee',
        slug: 'shopee',
        probeHost: 'shopee.co.id',
        series: seed(),
      ),
    ];
  }

  List<_ServiceItem> get _filtered {
    if (_query.isEmpty) return _services;
    return _services
        .where((s) => s.name.toLowerCase().contains(_query))
        .toList();
  }

  /// Probe 2–3 services per tick so the network is not overloaded.
  Future<void> _tickProbe() async {
    if (_probing || !mounted || _activeSlug != null) return;
    _probing = true;
    try {
      final batch = <_ServiceItem>[];
      for (var i = 0; i < 3 && i < _services.length; i++) {
        final idx = (_probeIndex + i) % _services.length;
        batch.add(_services[idx]);
      }
      _probeIndex = (_probeIndex + batch.length) % _services.length;

      await Future.wait(batch.map(_probeOne));

      if (mounted) {
        setState(() => _lastUpdate = DateTime.now());
      }
    } finally {
      _probing = false;
    }
  }

  Future<void> _probeOne(_ServiceItem s) async {
    final host = s.probeHost;
    if (host == null) return;

    double sample; // 0..1 (tinggi = lebih lambat / bermasalah)
    double? ms;

    try {
      final uri = Uri.parse('https://$host/');
      final sw = Stopwatch()..start();
      final res = await http
          .head(uri, headers: {'Connection': 'close'})
          .timeout(_probeTimeout);
      sw.stop();
      ms = sw.elapsedMilliseconds.toDouble();
      // Normalisasi: 0–200ms → rendah, 200–2000ms → naik, timeout/error → tinggi
      if (res.statusCode >= 500) {
        sample = 0.85 + math.Random().nextDouble() * 0.1;
        s.warning = true;
      } else {
        sample = (ms / 2000.0).clamp(0.05, 0.95);
        s.warning = ms > 1500;
      }
    } catch (_) {
      // Timeout / connection failure → high point on chart
      ms = null;
      sample = 0.9 + math.Random().nextDouble() * 0.08;
      s.warning = true;
    }

    s.lastMs = ms;
    s.series.add(sample);
    while (s.series.length > _maxPoints) {
      s.series.removeAt(0);
    }
  }

  Future<void> _refreshAll() async {
    // Paksa probe beberapa putaran
    for (var i = 0; i < 4; i++) {
      await _tickProbe();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _openDetail(_ServiceItem s) async {
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

  String get _liveLabel {
    if (_lastUpdate == null) return 'Menghubungkan…';
    final s = DateTime.now().difference(_lastUpdate!).inSeconds;
    if (s < 5) return 'Live · baru saja';
    return 'Live · ${s}s lalu';
  }

  @override
  Widget build(BuildContext context) {
    final showingWeb = _activeSlug != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
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
        centerTitle: true,
        title: Text(
          showingWeb ? (_activeName ?? 'Downdetector') : 'Downdetector',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          if (!showingWeb)
            IconButton(
              tooltip: 'Refresh',
              onPressed: _probing ? null : _refreshAll,
              icon: _probing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.green,
                      ),
                    )
                  : const Icon(Icons.refresh, color: AppColors.greenLight),
            ),
        ],
      ),
      body: showingWeb ? _buildWeb() : _buildList(),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Center(
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                children: [
                  TextSpan(text: 'Powered by '),
                  TextSpan(
                    text: 'Down',
                    style: TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: 'detector',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Live indicator
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _probing ? AppColors.green : const Color(0xFF4FC3F7),
                  boxShadow: [
                    BoxShadow(
                      color: (_probing ? AppColors.green : const Color(0xFF4FC3F7))
                          .withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _liveLabel,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            cursorColor: AppColors.green,
            decoration: InputDecoration(
              hintText: 'Search services…',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(
                  color: AppColors.green.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide:
                    const BorderSide(color: AppColors.green, width: 1.2),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.green,
            onRefresh: _refreshAll,
            child: items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(
                        child: Text(
                          'No results',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                      indent: 56,
                    ),
                    itemBuilder: (context, i) {
                      if (i == items.length) {
                        return const AppFooter();
                      }
                      final s = items[i];
                      final chartColor = s.warning
                          ? const Color(0xFFFFB300)
                          : const Color(0xFF4FC3F7);
                      return InkWell(
                        onTap: () => _openDetail(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() => s.starred = !s.starred);
                                },
                                child: Icon(
                                  s.starred ? Icons.star : Icons.star_border,
                                  color: s.starred
                                      ? const Color(0xFF4FC3F7)
                                      : AppColors.textMuted,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (s.lastMs != null)
                                      Text(
                                        '${s.lastMs!.toStringAsFixed(0)} ms',
                                        style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (s.warning) ...[
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFFFB300),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                              ],
                              SizedBox(
                                width: 88,
                                height: 32,
                                child: CustomPaint(
                                  painter: _SparklinePainter(
                                    points: List<double>.from(s.series),
                                    color: chartColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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

class _SparklinePainter extends CustomPainter {
  final List<double> points;
  final Color color;

  _SparklinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final n = points.length;
    for (var i = 0; i < n; i++) {
      final x = n == 1 ? 0.0 : size.width * i / (n - 1);
      final y = size.height * (1.0 - points[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.points != points || old.color != color;
}
