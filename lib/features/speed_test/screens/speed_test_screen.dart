import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:http/http.dart' as http;

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
  // MPorT palette (dipertahankan)
  static const gold = Color(0xFF00E5A0);
  static const goldLight = Color(0xFF5CFFC9);
  static const background = Color(0xFF06080F);
  static const sheetColor = Color(0xFF0F1420);
  static const cardColor = Color(0xFF151B2B);

  final SpeedTestService _service = SpeedTestService();
  final HistoryService _historyService = HistoryService();
  final ServerService _serverService = ServerService.instance;
  final RealtimeService _realtime = RealtimeService.instance;

  SpeedTestPhase phase = SpeedTestPhase.idle;
  double currentSpeed = 0;
  double? ping;
  double? jitter;
  double? download;
  double? upload;
  bool running = false;
  String? _ispName;
  String? _serverDisplay;

  // Bottom sheet
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  double _sheetSize = 0.14;

  // Settings in sheet
  String _unit = 'Mbps';
  int _scale = 1000;
  bool _multiConnection = true;

  late final AnimationController _gaugeCtrl;
  late final AnimationController _pulseCtrl;
  double _animSpeed = 0;
  double _animProgress = 0;

  late Animation<double> _speedTween;
  late Animation<double> _progressTween;

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
    _fetchMeta();
  }

  void _animateGaugeTo(double speedMbps) {
    final targetProgress = _speedToProgress(speedMbps);
    _speedTween = Tween<double>(begin: _animSpeed, end: speedMbps).animate(
      CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic),
    );
    _progressTween = Tween<double>(begin: _animProgress, end: targetProgress)
        .animate(CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic));
    _gaugeCtrl
      ..duration = Duration(
        milliseconds: (220 + (speedMbps - _animSpeed).abs().clamp(0, 80) * 4)
            .round()
            .clamp(220, 600),
      )
      ..forward(from: 0);
  }

  double _speedToProgress(double s) {
    final maxScale = _scale.toDouble();
    if (s <= 0) return 0;
    return math.min(s / maxScale, 1.0);
  }

  @override
  void dispose() {
    _serverService.removeListener(_onServerChanged);
    _realtime.removeListener(_onServerChanged);
    _gaugeCtrl.dispose();
    _pulseCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  void _onServerChanged() {
    if (mounted) {
      setState(() {});
      _fetchMeta();
    }
  }

  Future<void> _autoSelectServer() async {
    try {
      await _serverService.selectNearest();
    } catch (_) {}
  }

  Future<void> _fetchMeta() async {
    try {
      final r = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200 && mounted) {
        final body = r.body;
        String isp = '';
        final ispMatch = RegExp(r'"isp"\s*:\s*"([^"]*)"').firstMatch(body);
        final orgMatch = RegExp(r'"org"\s*:\s*"([^"]*)"').firstMatch(body);
        if (ispMatch != null) isp = ispMatch.group(1) ?? '';
        if (isp.isEmpty && orgMatch != null) isp = orgMatch.group(1) ?? '';
        isp = _normalizeIspName(isp);
        if (isp.isNotEmpty) setState(() => _ispName = isp);
      }
    } catch (_) {}

    final selected = _serverService.selected;
    final name = selected.name.isNotEmpty
        ? selected.name
        : (ServerConfig.serverName.isNotEmpty ? ServerConfig.serverName : 'HaaNSirO');
    if (mounted) setState(() => _serverDisplay = name);
  }

  String _normalizeIspName(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final lower = s.toLowerCase();
    if (lower.contains('telkom') || lower.contains('indihome') || lower.contains('tlkm')) {
      return 'Telkom / IndiHome';
    }
    if (lower.contains('xl') || lower.contains('axis')) return 'XL Axiata';
    if (lower.contains('indosat') || lower.contains('im3') || lower.contains('tri ')) {
      return 'Indosat Ooredoo';
    }
    if (lower.contains('smartfren')) return 'Smartfren';
    if (lower.contains('by.u') || lower.contains('byu')) return 'by.U';
    if (lower.contains('biznet')) return 'Biznet';
    if (lower.contains('first media') || lower.contains('fastnet')) return 'First Media';
    if (lower.contains('myrepublic')) return 'MyRepublic';
    if (lower.contains('cbn')) return 'CBN';
    if (lower.contains('icon')) return 'Icon+';
    if (lower.contains('oxygen')) return 'Oxygen.id';
    if (lower.contains('mnc')) return 'MNC Play';
    return s.length > 28 ? '${s.substring(0, 26)}…' : s;
  }

  Future<void> startTest() async {
    if (running) return;

    // Collapse sheet when starting
    try {
      _sheetCtrl.animateTo(0.14,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } catch (_) {}

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

      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && phase == SpeedTestPhase.completed) {
          _animateGaugeTo(0);
        }
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

  void _cancelTest() {
    setState(() {
      running = false;
      phase = SpeedTestPhase.idle;
      currentSpeed = 0;
    });
    _animateGaugeTo(0);
  }

  String get _ispLabel {
    return _ispName ?? 'Jaringan';
  }

  String get _ispCode {
    final selected = _serverService.selected;
    if (selected.host.isNotEmpty) {
      final parts = selected.host.replaceAll('speed2.', '').split('.');
      return parts.isNotEmpty ? parts.first.toUpperCase() : 'Z2465N';
    }
    return 'Z2465N';
  }

  @override
  Widget build(BuildContext context) {
    final showTestUi = running ||
        phase == SpeedTestPhase.completed ||
        phase == SpeedTestPhase.error;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: showTestUi ? _buildTestingView() : _buildStandbyView(),
      ),
    );
  }

  // ─── STANDBY (Gambar 1 + sheet geser Gambar 2) ─────────────────
  Widget _buildStandbyView() {
    return Stack(
      children: [
        Column(
          children: [
            _topBar(showClose: false),
            Expanded(
              child: Center(
                child: _goButton(),
              ),
            ),
            // Spacer for collapsed sheet
            const SizedBox(height: 100),
          ],
        ),
        // Bottom draggable sheet
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (n) {
            setState(() => _sheetSize = n.extent);
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.14,
            minChildSize: 0.14,
            maxChildSize: 0.52,
            snap: true,
            snapSizes: const [0.14, 0.52],
            builder: (context, scrollController) {
              final expanded = _sheetSize > 0.28;
              return Container(
                decoration: const BoxDecoration(
                  color: sheetColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppColors.greenDim,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // ISP row (always visible)
                    _sheetIspRow(),
                    if (expanded) ...[
                      const SizedBox(height: 16),
                      _sheetServerRow(),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ServerScreen()),
                          );
                          if (mounted) setState(() {});
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(left: 44, bottom: 8),
                          child: Text(
                            'Change Test Server',
                            style: TextStyle(
                              color: Color(0xFF4DA3FF),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const Divider(color: AppColors.green.withValues(alpha: 0.12), height: 28),
                      _settingRow(
                        label: 'Units',
                        options: const ['Mbps', 'MB/s', 'kB/s'],
                        selected: _unit,
                        onSelect: (v) => setState(() => _unit = v),
                      ),
                      const SizedBox(height: 14),
                      _settingRow(
                        label: 'Scale',
                        options: const ['100', '500', '1000'],
                        selected: '$_scale',
                        onSelect: (v) =>
                            setState(() => _scale = int.tryParse(v) ?? 1000),
                      ),
                      const SizedBox(height: 14),
                      _settingRow(
                        label: 'Connection Type',
                        options: const ['Multi', 'Single'],
                        selected: _multiConnection ? 'Multi' : 'Single',
                        onSelect: (v) =>
                            setState(() => _multiConnection = v == 'Multi'),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sheetIspRow() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.greenDim),
          ),
          child: const Icon(Icons.wifi_rounded, color: AppColors.textPrimary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _ispLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _ispCode,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sheetServerRow() {
    final selected = _serverService.selected;
    final loc = selected.location.isNotEmpty ? selected.location : 'Indonesia';
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.greenDim),
          ),
          child: const Icon(Icons.dns_rounded, color: AppColors.textPrimary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _serverDisplay ?? 'HaaNSirO Network',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                loc,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingRow({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: options.map((o) {
              final active = o == selected;
              return GestureDetector(
                onTap: () => onSelect(o),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    children: [
                      Text(
                        o,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white38,
                          fontSize: 14,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 28,
                        height: 2,
                        color: active ? gold : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _goButton() {
    return GestureDetector(
      onTap: startTest,
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Logo samar di belakang tombol GO
            Opacity(
              opacity: 0.18,
              child: Image.asset(
                'assets/images/mport_logo.png',
                width: 260,
                height: 260,
                fit: BoxFit.contain,
              ),
            ),
            // Soft glow
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    gold.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Ring GO
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: gold, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: gold.withValues(alpha: 0.2),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'GO',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TESTING VIEW (Gambar 3) ───────────────────────────────────
  Widget _buildTestingView() {
    return Column(
      children: [
        _topBar(showClose: true),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Download / Upload cards
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        icon: Icons.download_rounded,
                        title: 'Download',
                        value: download,
                        highlight: phase == SpeedTestPhase.download ||
                            phase == SpeedTestPhase.completed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metricCard(
                        icon: Icons.upload_rounded,
                        title: 'Upload',
                        value: upload,
                        highlight: phase == SpeedTestPhase.upload,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Ping / Jitter row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _smallStat('Ping ms', ping, Icons.speed),
                    const SizedBox(width: 8),
                    _dotStat(Icons.wifi_tethering, null),
                    const SizedBox(width: 8),
                    _dotStat(Icons.cell_tower, null),
                    const SizedBox(width: 8),
                    _smallStat('Jitter ms', jitter, Icons.waves),
                  ],
                ),
                const SizedBox(height: 16),
                // Quality icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _qualityIcon(Icons.web, _qualityDots(download)),
                    _qualityIcon(Icons.sports_esports, _qualityDots(download)),
                    _qualityIcon(Icons.play_circle_outline, _qualityDots(download)),
                    _qualityIcon(Icons.videocam_outlined, _qualityDots(upload)),
                  ],
                ),
                // Gauge
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: CustomPaint(
                        painter: _ArcGaugePainter(
                          progress: _animProgress,
                          gold: gold,
                          goldLight: goldLight,
                          pulse: running ? _pulseCtrl.value : 0,
                        ),
                        child: Center(
                          child: running
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _animSpeed.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        height: 1,
                                      ),
                                    ),
                                    Text(
                                      _unit,
                                      style: const TextStyle(
                                        color: goldLight,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : phase == SpeedTestPhase.completed
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          (download ?? 0).toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 40,
                                            fontWeight: FontWeight.w800,
                                            height: 1,
                                          ),
                                        ),
                                        Text(
                                          _unit,
                                          style: const TextStyle(
                                            color: goldLight,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom ISP + Server
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _ispLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.wifi, color: AppColors.textMuted, size: 14),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.dns, color: AppColors.textMuted, size: 14),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${_serverDisplay ?? 'HaaNSirO'} · ${_serverService.selected.location.isNotEmpty ? _serverService.selected.location : 'Pati'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String title,
    required double? value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? gold.withValues(alpha: 0.4) : AppColors.green.withValues(alpha: 0.12),
        ),
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
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value == null ? '—' : value.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const Spacer(),
              Text(
                _unit,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallStat(String label, double? value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(width: 4),
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 2),
        Text(
          value == null ? '—' : value.toStringAsFixed(0),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _dotStat(IconData icon, double? value) {
    return Icon(icon, size: 14, color: AppColors.greenDim);
  }

  int _qualityDots(double? mbps) {
    if (mbps == null) return 0;
    if (mbps >= 100) return 5;
    if (mbps >= 50) return 4;
    if (mbps >= 25) return 3;
    if (mbps >= 10) return 2;
    if (mbps > 0) return 1;
    return 0;
  }

  Widget _qualityIcon(IconData icon, int dots) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 22),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            return Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < dots ? gold : AppColors.green.withValues(alpha: 0.12),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _topBar({required bool showClose}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          if (showClose)
            IconButton(
              onPressed: _cancelTest,
              icon: const Icon(Icons.close, color: AppColors.textPrimary),
            )
          else
            const SizedBox(width: 48),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speed_rounded, color: gold, size: 20),
                SizedBox(width: 6),
                Text(
                  'MPorT',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Arc gauge (Gambar 3 style)
class _ArcGaugePainter extends CustomPainter {
  final double progress;
  final Color gold;
  final Color goldLight;
  final double pulse;

  _ArcGaugePainter({
    required this.progress,
    required this.gold,
    required this.goldLight,
    this.pulse = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi * 0.75,
        endAngle: math.pi * 0.75,
        colors: [gold, goldLight, gold],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    const start = -math.pi * 0.75;
    const sweep = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );

    if (progress > 0) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22 + pulse * 4
        ..strokeCap = StrokeCap.round
        ..color = gold.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

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
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.progress != progress || old.pulse != pulse;
}
