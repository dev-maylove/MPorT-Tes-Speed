import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/speed_test_state.dart';
import '../services/history_service.dart';
import '../services/speed_test_service.dart';
import '../models/test_server.dart';
import 'cbn_speedtest_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../server/screens/server_screen.dart';
import '../../server/services/server_service.dart';
import '../../../core/constants/server_config.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  static const gold = Color(0xFF00E5A0);
  static const goldLight = Color(0xFF5CFFC9);
  static const background = Color(0xFF080808);
  static const cardColor = Color(0xFF111111);

  final SpeedTestService _service = SpeedTestService();
  final HistoryService _historyService = HistoryService();
  final ServerService _serverService = ServerService.instance;
  bool _selectingServer = false;

  SpeedTestPhase phase = SpeedTestPhase.idle;
  double currentSpeed = 0;
  double? ping;
  double? jitter;
  double? download;
  double? upload;
  bool running = false;

  @override
  void initState() {
    super.initState();
    _serverService.addListener(_onServerChanged);
    _autoSelectServer();
  }

  @override
  void dispose() {
    _serverService.removeListener(_onServerChanged);
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

    if (_serverService.selected.engine == TestEngine.cbnSpeedtestCustom) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CbnSpeedtestScreen(server: _serverService.selected),
        ),
      );
      return;
    }

    setState(() {
      running = true;
      phase = SpeedTestPhase.ping;
      currentSpeed = 0;
      ping = null;
      jitter = null;
      download = null;
      upload = null;
    });

    try {
      final result = await _service.start(
        onProgress: (newPhase, value) {
          if (!mounted) return;

          setState(() {
            phase = newPhase;

            // Gauge hanya menampilkan Mbps (download/upload), bukan latency ping
            if (newPhase == SpeedTestPhase.ping) {
              ping = value;
              currentSpeed = 0;
            } else if (newPhase == SpeedTestPhase.download) {
              download = value;
              currentSpeed = value;
            } else if (newPhase == SpeedTestPhase.upload) {
              upload = value;
              currentSpeed = value;
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
                    const SizedBox(height: 15),
                    _serverCard(),
                    const SizedBox(height: 28),
                    _speedGauge(),
                    const SizedBox(height: 25),
                    _resultCards(),
                    const SizedBox(height: 30),
                    _testButton(),
                    const SizedBox(height: 25),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                colors: [goldLight, gold],
              ),
            ),
            child: const Icon(
              Icons.speed_rounded,
              color: Colors.black,
              size: 25,
            ),
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
                    fontSize: 22,
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
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white70,
              size: 22,
            ),
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
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ServerScreen()),
        );
        if (result != null && mounted) setState(() {});
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gold.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.dns_outlined,
                color: gold,
                size: 20,
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
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _serverService.selected.host.isNotEmpty
                        ? _serverService.selected.host
                        : ServerConfig.baseUrl
                            .replaceFirst('https://', '')
                            .replaceFirst('http://', ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _serverService.selected.engine == TestEngine.cbnSpeedtestCustom
                        ? '${_serverService.selected.name} · CBN'
                        : _serverService.selected.name,
                    style: TextStyle(
                      color: gold.withValues(alpha: 0.8),
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
            const SizedBox(width: 7),
            Text(
              _selectingServer || _serverService.isProbing
                  ? 'AUTO...'
                  : (_serverService.selected.engine == TestEngine.cbnSpeedtestCustom
                      ? 'CBN'
                      : 'AUTO'),
              style: TextStyle(
                color: _selectingServer || _serverService.isProbing
                    ? Colors.amber
                    : const Color(0xFF81C784),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _speedGauge() {
    return SizedBox(
      width: 270,
      height: 270,
      child: CustomPaint(
        painter: _GaugePainter(
          progress: _gaugeProgress,
          gold: gold,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                currentSpeed.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 47,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                ),
              ),
              const Text(
                'Mbps',
                style: TextStyle(
                  color: goldLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _gaugeProgress {
    if (currentSpeed <= 0) return 0;
    return math.min(currentSpeed / 100, 1);
  }

  Widget _resultCards() {
    return Row(
      children: [
        Expanded(
          child: _resultCard(
            icon: Icons.network_ping_rounded,
            title: 'PING',
            value: ping,
            unit: 'ms',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _resultCard(
            icon: Icons.download_rounded,
            title: 'DOWNLOAD',
            value: download,
            unit: 'Mbps',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _resultCard(
            icon: Icons.upload_rounded,
            title: 'UPLOAD',
            value: upload,
            unit: 'Mbps',
          ),
        ),
      ],
    );
  }

  Widget _resultCard({
    required IconData icon,
    required String title,
    required double? value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: gold, size: 19),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value == null ? '--' : value.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _testButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: running
                ? const [Color(0xFF333333), Color(0xFF444444)]
                : [goldLight, gold],
          ),
          boxShadow: running
              ? null
              : [
                  BoxShadow(
                    color: gold.withValues(alpha: 0.20),
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
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Text(
            running
                ? 'SEDANG MENGUJI...'
                : (_serverService.selected.engine == TestEngine.cbnSpeedtestCustom
                    ? 'BUKA MESIN CBN'
                    : 'MULAI TES'),
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

  _GaugePainter({
    required this.progress,
    required this.gold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.07);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = gold;

    const startAngle = 2.35;
    const sweepAngle = 4.72;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
