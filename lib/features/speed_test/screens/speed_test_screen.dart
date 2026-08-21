import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/speed_test_state.dart';
import '../services/history_service.dart';
import '../services/realtime_service.dart';
import '../services/speed_test_service.dart';
import '../../settings/screens/settings_screen.dart';
import '../../server/screens/server_screen.dart';
import '../../server/services/server_service.dart';
import '../../../core/constants/server_config.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with TickerProviderStateMixin {
  static const gold = Color(0xFF00E5A0);
  static const goldLight = Color(0xFF5CFFC9);
  static const background = Color(0xFF080808);
  static const cardColor = Color(0xFF111111);

  final SpeedTestService _service = SpeedTestService();
  final HistoryService _historyService = HistoryService();
  final ServerService _serverService = ServerService.instance;
  final RealtimeService _realtime = RealtimeService.instance;
  bool _selectingServer = false;

  SpeedTestPhase phase = SpeedTestPhase.idle;
  double currentSpeed = 0;
  double? ping;
  double? jitter;
  double? download;
  double? upload;
  bool running = false;

  late final AnimationController _gaugeCtrl;
  late final AnimationController _pulseCtrl;
  double _animSpeed = 0;
  double _animProgress = 0;

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..addListener(() {
        setState(() {
          _animSpeed = _speedTween.value;
          _animProgress = _progressTween.value;
        });
      });
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _speedTween = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic),
    );
    _progressTween = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic),
    );

    _serverService.addListener(_onServerChanged);
    _realtime.addListener(_onServerChanged);
    _autoSelectServer();
    _realtime.connect();
  }

  late Animation<double> _speedTween;
  late Animation<double> _progressTween;

  void _animateGaugeTo(double speedMbps) {
    final targetProgress = _speedToProgress(speedMbps);
    _speedTween = Tween<double>(begin: _animSpeed, end: speedMbps).animate(
      CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic),
    );
    _progressTween =
        Tween<double>(begin: _animProgress, end: targetProgress).animate(
      CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic),
    );
    _gaugeCtrl
      ..duration = Duration(
        milliseconds: (220 + (speedMbps - _animSpeed).abs().clamp(0, 80) * 4)
            .round()
            .clamp(220, 600),
      )
      ..forward(from: 0);
  }

  double _speedToProgress(double s) {
    if (s <= 0) return 0;
    if (s < 50) return (s / 50) * 0.35;
    if (s < 200) return 0.35 + ((s - 50) / 150) * 0.35;
    if (s < 500) return 0.70 + ((s - 200) / 300) * 0.20;
    return math.min(0.90 + ((s - 500) / 500) * 0.10, 1.0);
  }

  @override
  void dispose() {
    _serverService.removeListener(_onServerChanged);
    _realtime.removeListener(_onServerChanged);
    _gaugeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onServerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _autoSelectServer() async {
    setState(() => _selectingServer = true);
    try {
      await _serverService.selectNearest();
    } finally {
      if (mounted) setState(() => _selectingServer = false);
    }
  }

  Future<void> startTest() async {
    if (running) return;

    setState(() {
      running = true;
      phase = SpeedTestPhase.ping;
      currentSpeed = 0;
      ping = null;
      jitter = null;
      download = null;
      upload = null;
    });
    _animateGaugeTo(0);

    try {
      final result = await _service.start(
        onProgress: (newPhase, value) {
          if (!mounted) return;
          setState(() {
            phase = newPhase;
            if (newPhase == SpeedTestPhase.ping) {
              ping = value;
              currentSpeed = 0;
              _animateGaugeTo(0);
            } else if (newPhase == SpeedTestPhase.download) {
              download = value;
              currentSpeed = value;
              _animateGaugeTo(value);
            } else if (newPhase == SpeedTestPhase.upload) {
              upload = value;
              currentSpeed = value;
              _animateGaugeTo(value);
            }
          });
        },
      );

      if (!mounted) return;

      setState(() {
        ping = result.ping;
        jitter = result.jitter;
        download = result.download;
        upload = result.upload;
        currentSpeed = result.download;
        phase = SpeedTestPhase.completed;
        running = false;
      });
      _animateGaugeTo(result.download);

      await _historyService.addResult(
        ping: result.ping,
        jitter: result.jitter,
        download: result.download,
        upload: result.upload,
        server: result.server,
        timestamp: result.timestamp,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        phase = SpeedTestPhase.error;
        running = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tes gagal: $e')),
      );
    }
  }

  String get statusText {
    switch (phase) {
      case SpeedTestPhase.ping:
        return 'MENGUKUR PING';
      case SpeedTestPhase.download:
        return 'MENGUKUR DOWNLOAD';
      case SpeedTestPhase.upload:
        return 'MENGUKUR UPLOAD';
      case SpeedTestPhase.completed:
        return 'TES SELESAI';
      case SpeedTestPhase.error:
        return 'TES GAGAL';
      case SpeedTestPhase.idle:
        return 'SIAP MELAKUKAN TES';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _serverCard(),
                    const SizedBox(height: 10),
                    _realtimeBadge(),
                    const SizedBox(height: 8),
                    _speedGauge(),
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _metricsLayout(),
                    const SizedBox(height: 22),
                    _connectionInfo(),
                    const SizedBox(height: 28),
                    _testButton(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [goldLight, gold]),
            ),
            child: const Icon(Icons.speed_rounded, color: Colors.black, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MPorT',
                  style: TextStyle(
                    color: goldLight,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'TES SPEED',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _serverCard() {
    final selected = _serverService.selected;
    final host = selected.host.isNotEmpty
        ? selected.host
        : ServerConfig.baseUrl
            .replaceFirst('https://', '')
            .replaceFirst('http://', '');

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ServerScreen()),
        );
        if (result != null && mounted) setState(() {});
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            // Ikon server peta
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    gold.withValues(alpha: 0.25),
                    gold.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: gold.withValues(alpha: 0.35)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.map_rounded,
                      color: gold.withValues(alpha: 0.35), size: 22),
                  const Icon(Icons.location_on_rounded, color: gold, size: 18),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SERVER',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${selected.name} · ${selected.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: gold.withValues(alpha: 0.85),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectingServer || _serverService.isProbing
                    ? Colors.amber
                    : const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _selectingServer || _serverService.isProbing ? 'CEK...' : 'LIVE',
              style: TextStyle(
                color: _selectingServer || _serverService.isProbing
                    ? Colors.amber
                    : const Color(0xFF81C784),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _realtimeBadge() {
    final st = _realtime.status;
    Color color;
    String label;
    switch (st) {
      case RealtimeStatus.connected:
        color = gold;
        final rtt = _realtime.rttMs;
        label = rtt != null
            ? 'WS · ${rtt.toStringAsFixed(0)} ms'
            : 'WS · TERHUBUNG';
      case RealtimeStatus.connecting:
        color = Colors.amber;
        label = 'WS · MENGHUBUNGKAN...';
      case RealtimeStatus.error:
        color = Colors.orangeAccent;
        label = 'WS · OFFLINE (HTTP)';
      case RealtimeStatus.disconnected:
        color = Colors.white38;
        label = 'WS · PUTUS';
    }

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final pulse = st == RealtimeStatus.connected
            ? 0.45 + _pulseCtrl.value * 0.55
            : 1.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: pulse,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: st == RealtimeStatus.connected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _speedGauge() {
    return SizedBox(
      width: 280,
      height: 280,
      child: CustomPaint(
        painter: _GaugePainter(
          progress: _animProgress,
          gold: gold,
          goldLight: goldLight,
          pulse: running ? _pulseCtrl.value : 0,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _animSpeed.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mbps',
                style: TextStyle(
                  color: goldLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricsLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _metricTile(
                icon: Icons.timer_outlined,
                title: 'PING',
                value: ping ?? _realtime.rttMs,
                unit: 'ms',
                decimals: 0,
              ),
              const SizedBox(height: 18),
              _metricTile(
                icon: Icons.waves_rounded,
                title: 'JITTER',
                value: jitter,
                unit: 'ms',
                decimals: 0,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _speedStatCard(
                icon: Icons.download_rounded,
                title: 'DOWNLOAD',
                value: download,
                highlight: phase == SpeedTestPhase.download ||
                    phase == SpeedTestPhase.completed,
              ),
              const SizedBox(height: 12),
              _speedStatCard(
                icon: Icons.upload_rounded,
                title: 'UPLOAD',
                value: upload,
                highlight: phase == SpeedTestPhase.upload,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String title,
    required double? value,
    required String unit,
    int decimals = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: gold, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value == null ? '--' : value.toStringAsFixed(decimals),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unit,
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _speedStatCard({
    required IconData icon,
    required String title,
    required double? value,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? gold.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.06),
        ),
        boxShadow: highlight
            ? [BoxShadow(color: gold.withValues(alpha: 0.12), blurRadius: 16)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: gold, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value == null ? '--' : value.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  'Mbps',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
          if (value != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: math.min(value / 200, 1),
                minHeight: 3,
                backgroundColor: Colors.white10,
                color: gold.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _connectionInfo() {
    final selected = _serverService.selected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          _infoRow(
            icon: Icons.wifi_rounded,
            title: selected.network,
            subtitle: _realtime.isConnected
                ? 'Realtime WebSocket aktif'
                : 'MPorT Engine (HTTP)',
          ),
          const Divider(height: 18, color: Colors.white10),
          _infoRow(
            icon: Icons.map_rounded,
            title: selected.name,
            subtitle: selected.location.isNotEmpty
                ? '${selected.location}'
                    '${selected.latitude != null ? ' · ${selected.latitude!.toStringAsFixed(2)}, ${selected.longitude!.toStringAsFixed(2)}' : ''}'
                : selected.host,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: gold.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: gold, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _testButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: running
                ? const [Color(0xFF333333), Color(0xFF444444)]
                : [goldLight, gold],
          ),
          boxShadow: running
              ? null
              : [
                  BoxShadow(
                    color: gold.withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: running ? null : startTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Text(
            running ? 'SEDANG MENGUJI...' : 'MULAI TES',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: running ? Colors.white54 : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color gold;
  final Color goldLight;
  final double pulse;

  _GaugePainter({
    required this.progress,
    required this.gold,
    required this.goldLight,
    this.pulse = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18 + pulse * 6
      ..strokeCap = StrokeCap.round
      ..color = gold.withValues(alpha: 0.12 + pulse * 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 2.35,
        endAngle: 2.35 + 4.72,
        colors: [gold, goldLight, gold],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    const start = 2.35;
    const sweep = 4.72;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * progress,
        false,
        glow,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep * progress,
        false,
        arc,
      );
    }

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.5;
    for (var i = 0; i <= 10; i++) {
      final a = start + sweep * (i / 10);
      final outer = Offset(
        center.dx + (radius + 6) * math.cos(a),
        center.dy + (radius + 6) * math.sin(a),
      );
      final inner = Offset(
        center.dx + (radius - 4) * math.cos(a),
        center.dy + (radius - 4) * math.sin(a),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pulse != pulse;
  }
}
