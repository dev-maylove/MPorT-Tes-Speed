import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

import '../../../core/constants/server_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../server/screens/server_screen.dart';
import '../../server/services/server_service.dart';
import '../models/speed_test_state.dart';
import '../services/history_service.dart';
import '../services/realtime_service.dart';
import '../services/speed_test_service.dart';


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
  double? avgPing;
  double? maxPing;
  double? packetLoss;
  double? download;
  double? upload;
  bool running = false;
  String? _ispName;
  String? _deviceNetworkName; // Wi-Fi SSID or mobile network label
  String? _serverDisplay;
  String _deviceModel = '—';
  String? _testId;
  String? _serverStatus; // Online / Offline / latency

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
    _loadDeviceModel();
    _loadDeviceNetworkName();
  }

  /// Loads a human-readable device model via device_info_plus (^13.2.0).
  Future<void> _loadDeviceModel() async {
    try {
      final plugin = DeviceInfoPlugin();
      String model = '—';

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final a = await plugin.androidInfo;
          // Prefer marketing model; fall back to device codename.
          final base = (a.model.isNotEmpty ? a.model : a.device).trim();
          final brand = a.brand.trim();
          if (brand.isNotEmpty &&
              !base.toLowerCase().startsWith(brand.toLowerCase())) {
            model = '$brand $base'.trim();
          } else {
            model = base;
          }
          break;
        case TargetPlatform.iOS:
          final i = await plugin.iosInfo;
          // utsname.machine = hardware id (e.g. iPhone15,2); name/model as fallback.
          model = i.utsname.machine.isNotEmpty
              ? i.utsname.machine
              : (i.name.isNotEmpty ? i.name : i.model);
          break;
        case TargetPlatform.macOS:
          final m = await plugin.macOsInfo;
          // Prefer friendly modelName, then hardware model id.
          model = m.modelName.isNotEmpty
              ? m.modelName
              : (m.model.isNotEmpty ? m.model : m.computerName);
          break;
        case TargetPlatform.windows:
          final w = await plugin.windowsInfo;
          model = w.computerName.isNotEmpty
              ? w.computerName
              : (w.productName.isNotEmpty ? w.productName : 'Windows');
          break;
        case TargetPlatform.linux:
          final l = await plugin.linuxInfo;
          model = l.prettyName.isNotEmpty
              ? l.prettyName
              : (l.name.isNotEmpty ? l.name : 'Linux');
          break;
        default:
          final d = await plugin.deviceInfo;
          model = d.data['model']?.toString() ??
              d.data['name']?.toString() ??
              d.data['computerName']?.toString() ??
              '—';
      }

      if (model.trim().isEmpty) model = '—';
      if (mounted) setState(() => _deviceModel = model.trim());
    } catch (_) {
      if (mounted) setState(() => _deviceModel = 'Unknown device');
    }
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
    // Auto-detect ISP from public IP lookup (multiple providers).
    final isp = await _detectIspName();
    if (isp != null && isp.isNotEmpty && mounted) {
      setState(() => _ispName = isp);
    }

    final selected = _serverService.selected;
    final name = selected.name.isNotEmpty
        ? selected.name
        : (ServerConfig.serverName.isNotEmpty ? ServerConfig.serverName : 'HaaNSirO');
    if (mounted) setState(() => _serverDisplay = name);
  }

  /// Tries several free geo-IP endpoints until an ISP/org name is found.
  Future<String?> _detectIspName() async {
    final endpoints = <(String, List<String>)>[
      // (url, json keys to try in order)
      ('https://ipapi.co/json/', ['isp', 'org']),
      ('https://ip-api.com/json/?fields=status,isp,org,as', ['isp', 'org', 'as']),
      ('https://ipinfo.io/json', ['org', 'hostname']),
    ];

    for (final entry in endpoints) {
      final url = entry.$1;
      final keys = entry.$2;
      try {
        final r = await http
            .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 5));
        if (r.statusCode != 200) continue;
        final body = r.body;
        for (final key in keys) {
          final m = RegExp('"$key"\s*:\s*"([^"]*)"').firstMatch(body);
          var raw = (m?.group(1) ?? '').trim();
          if (raw.isEmpty) continue;
          // ipinfo org often looks like "ASxxxxx Name"
          if (key == 'as' || key == 'org') {
            raw = raw.replaceFirst(RegExp(r'^AS\d+\s*'), '').trim();
          }
          final normalized = _normalizeIspName(raw);
          if (normalized.isNotEmpty) return normalized;
        }
      } catch (_) {
        // try next provider
      }
    }
    return null;
  }

  String _normalizeIspName(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final lower = s.toLowerCase();
    if (lower.contains('telkom') ||
        lower.contains('indihome') ||
        lower.contains('tlkm') ||
        lower.contains('telekomunikasi indonesia')) {
      return 'Telkom / IndiHome';
    }
    if (lower.contains('xl axiata') ||
        lower.contains('xl ') ||
        lower == 'xl' ||
        lower.contains('axis')) {
      return 'XL Axiata';
    }
    if (lower.contains('indosat') ||
        lower.contains('im3') ||
        lower.contains('tri ') ||
        lower.contains('hutchison')) {
      return 'Indosat Ooredoo';
    }
    if (lower.contains('smartfren')) return 'Smartfren';
    if (lower.contains('by.u') || lower.contains('byu')) return 'by.U';
    if (lower.contains('biznet')) return 'Biznet';
    if (lower.contains('first media') || lower.contains('fastnet')) {
      return 'First Media';
    }
    if (lower.contains('myrepublic')) return 'MyRepublic';
    if (lower.contains('cbn')) return 'CBN';
    if (lower.contains('icon+') || lower.contains('icon plus')) return 'Icon+';
    if (lower.contains('oxygen')) return 'Oxygen.id';
    if (lower.contains('mnc')) return 'MNC Play';
    if (lower.contains('haansiro') || lower.contains('haan siro')) {
      return 'HaaNSirO';
    }
    if (lower.contains('arrab')) return 'ARRAB NETWORK';
    if (lower.contains('jsn') || lower.contains('jaringanku')) {
      return 'JSN Jaringanku';
    }
    if (lower.contains('three') || lower.contains('3 indonesia')) {
      return 'Tri Indonesia';
    }
    if (lower.contains('bolt')) return 'BOLT';
    if (lower.contains('orbit')) return 'Telkomsel Orbit';
    if (lower.contains('telkomsel')) return 'Telkomsel';
    // Keep original, trim length for UI
    return s.length > 32 ? '${s.substring(0, 30)}…' : s;
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
      avgPing = null;
      maxPing = null;
      packetLoss = null;
      download = null;
      upload = null;
      _testId = null;
      _serverStatus = 'Checking…';
    });
    _animateGaugeTo(0);
    // ignore: unawaited_futures
    _refreshServerStatus();
    // ignore: unawaited_futures
    _loadDeviceNetworkName();
    // ignore: unawaited_futures
    _fetchMeta();

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
        avgPing = result.avgPing;
        maxPing = result.maxPing;
        packetLoss = result.packetLossPercent;
        download = result.download;
        upload = result.upload;
        currentSpeed = result.download;
        phase = SpeedTestPhase.completed;
        running = false;
        // nextInt max must be <= 2^32; build a 10–13 digit Test ID safely
        _testId = _generateTestId();
      });
      _animateGaugeTo(result.download);

      // Keep final speed on the gauge (do not reset to 0).
      // ignore: unawaited_futures
      _refreshServerStatus();

      await _historyService.addResult(
        ping: result.ping,
        jitter: result.jitter,
        avgPing: result.avgPing,
        maxPing: result.maxPing,
        packetLossPercent: result.packetLossPercent,
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
        SnackBar(content: Text('Test failed: $e')),
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


  /// Safe Test ID (Random.nextInt max must be <= 2^32).
  String _generateTestId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final suffix = math.Random().nextInt(9000) + 1000; // 1000–9999
    return '$now$suffix';
  }

  /// Probe selected server via ping/status URL.
  Future<void> _refreshServerStatus() async {
    try {
      final url = ServerConfig.statusUrl;
      final sw = Stopwatch()..start();
      final res = await http
          .get(Uri.parse(url), headers: ServerConfig.defaultHeaders)
          .timeout(const Duration(seconds: 4));
      sw.stop();
      if (!mounted) return;
      if (res.statusCode < 500) {
        setState(() {
          _serverStatus = 'Online · ${sw.elapsedMilliseconds} ms';
        });
      } else {
        setState(() {
          _serverStatus = 'Degraded · HTTP ${res.statusCode}';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _serverStatus = 'Offline');
    }
  }


  /// Active network name on the device (Wi-Fi SSID or mobile/other).
  Future<void> _loadDeviceNetworkName() async {
    try {
      final list = await Connectivity().checkConnectivity();
      final hasWifi = list.contains(ConnectivityResult.wifi);
      final hasMobile = list.contains(ConnectivityResult.mobile);
      final hasEthernet = list.contains(ConnectivityResult.ethernet);

      String? name;
      if (hasWifi) {
        try {
          final raw = await NetworkInfo().getWifiName();
          if (raw != null && raw.trim().isNotEmpty) {
            // Android may wrap SSID in quotes
            name = raw.trim().replaceAll('"', '');
          } else {
            name = 'Wi-Fi';
          }
        } catch (_) {
          name = 'Wi-Fi';
        }
      } else if (hasMobile) {
        name = 'Mobile data';
      } else if (hasEthernet) {
        name = 'Ethernet';
      }

      if (name != null && mounted) {
        setState(() => _deviceNetworkName = name);
      }
    } catch (_) {
      // keep previous / fall back to ISP
    }
  }

  String get _ispLabel {
    // 1) Wi-Fi SSID when available (not the generic fallback labels)
    final deviceNet = _deviceNetworkName?.trim();
    if (deviceNet != null &&
        deviceNet.isNotEmpty &&
        deviceNet != 'Wi-Fi' &&
        deviceNet != 'Mobile data' &&
        deviceNet != 'Ethernet') {
      return deviceNet;
    }
    // 2) Auto-detected ISP name
    final isp = _ispName?.trim();
    if (isp != null && isp.isNotEmpty) return isp;
    // 3) Connection type fallback
    if (deviceNet != null && deviceNet.isNotEmpty) return deviceNet;
    return 'Network';
  }

  String get _ispCode => _deviceModel;

  @override
  Widget build(BuildContext context) {
    final showTestUi = running ||
        phase == SpeedTestPhase.completed ||
        phase == SpeedTestPhase.error;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          reverseDuration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final fade = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            final scale = Tween<double>(begin: 0.96, end: 1.0).animate(fade);
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(fade);
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                child: SlideTransition(
                  position: slide,
                  child: child,
                ),
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<bool>(showTestUi),
            child: showTestUi ? _buildTestingView() : _buildStandbyView(),
          ),
        ),
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
                            MaterialPageRoute<void>(
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
                      Divider(color: AppColors.green.withValues(alpha: 0.12), height: 28),
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

  bool _goPressed = false;

  Widget _goButton() {
    // Tombol GO: logo original full + ring kaca + animasi pulse & press
    return GestureDetector(
      onTapDown: (_) => setState(() => _goPressed = true),
      onTapUp: (_) => setState(() => _goPressed = false),
      onTapCancel: () => setState(() => _goPressed = false),
      onTap: startTest,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, _) {
          final pulse = 1.0 + (_pulseCtrl.value * 0.035);
          final pressScale = _goPressed ? 0.94 : 1.0;
          final glowBoost = 0.30 + (_pulseCtrl.value * 0.12);

          return AnimatedScale(
            scale: pressScale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Transform.scale(
              scale: pulse,
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow luar (cyan lembut, ikut pulse)
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: gold.withValues(alpha: glowBoost),
                            blurRadius: 36 + (_pulseCtrl.value * 12),
                            spreadRadius: 2 + (_pulseCtrl.value * 3),
                          ),
                          BoxShadow(
                            color: goldLight.withValues(alpha: 0.10 + _pulseCtrl.value * 0.06),
                            blurRadius: 64,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),

                    // Logo ORIGINAL — full, terang
                    ClipOval(
                      child: Image.asset(
                        'assets/images/mport_logo.png',
                        width: 180,
                        height: 180,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),

                    // Ring kaca transparan
                    IgnorePointer(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    // Ring aksen hijau transparan (opacity ikut pulse)
                    IgnorePointer(
                      child: Container(
                        width: 188,
                        height: 188,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                          border: Border.all(
                            color: gold.withValues(
                              alpha: 0.35 + (_pulseCtrl.value * 0.25),
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          );
        },
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
                // Network latency metrics
                _latencyMetricsRow(),
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
                // Gauge: arc + MPorT GO logo background (standby button style)
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_pulseCtrl, _gaugeCtrl]),
                        builder: (context, child) {
                          final pulse = running ? _pulseCtrl.value : 0.4;
                          final glowBoost = 0.32 + (pulse * 0.14);
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer soft glow (matches GO button)
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: gold.withValues(alpha: glowBoost),
                                      blurRadius: 36 + pulse * 14,
                                      spreadRadius: 2 + pulse * 4,
                                    ),
                                    BoxShadow(
                                      color: goldLight.withValues(
                                        alpha: 0.10 + pulse * 0.06,
                                      ),
                                      blurRadius: 56,
                                      spreadRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              // MPorT GO logo (same asset as GO button)
                              ClipOval(
                                child: Image.asset(
                                  'assets/images/mport_logo.png',
                                  width: 168,
                                  height: 168,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              // Dark veil so speed digits stay readable
                              Container(
                                width: 168,
                                height: 168,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(
                                    alpha: running ||
                                            phase == SpeedTestPhase.completed
                                        ? 0.45
                                        : 0.25,
                                  ),
                                ),
                              ),
                              // Glass ring
                              IgnorePointer(
                                child: Container(
                                  width: 168,
                                  height: 168,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.28),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              // Accent ring
                              IgnorePointer(
                                child: Container(
                                  width: 176,
                                  height: 176,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: gold.withValues(
                                        alpha: 0.35 + pulse * 0.25,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                              // Progress arc on top
                              CustomPaint(
                                size: const Size(240, 240),
                                painter: _ArcGaugePainter(
                                  progress: _animProgress,
                                  gold: gold,
                                  goldLight: goldLight,
                                  pulse: running ? _pulseCtrl.value : 0,
                                ),
                              ),
                              child!,
                            ],
                          );
                        },
                        child: _gaugeCenterValue(),
                      ),
                    ),
                  ),
                ),
                // Bottom: full result panel when done; ISP + device while running
                if (phase == SpeedTestPhase.completed)
                  _resultFooter()
                else
                  _testingIspServerRow(),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _gaugeCenterValue() {
    final show = running || phase == SpeedTestPhase.completed;
    if (!show) return const SizedBox.shrink();
    final value = running ? _animSpeed : (download ?? _animSpeed);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 40,
            fontWeight: FontWeight.w800,
            height: 1,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        Text(
          _unit,
          style: TextStyle(
            color: goldLight,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _testingIspServerRow() {
    final loc = _serverService.selected.location.isNotEmpty
        ? _serverService.selected.location
        : 'Pati';
    final serverName = _serverDisplay ?? 'HaaNSirO';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _ispLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.phone_android_rounded,
                        color: AppColors.textMuted, size: 14),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _deviceModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.dns_rounded,
                        color: AppColors.textMuted, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        serverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  loc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Result footer (image 3 style) shown on the testing view when completed.
  Widget _resultFooter() {
    final loc = _serverService.selected.location.isNotEmpty
        ? _serverService.selected.location
        : 'Pati';
    final serverName = _serverDisplay ?? 'HaaNSirO';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _ispLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.phone_android_rounded,
                            color: AppColors.textMuted, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _deviceModel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.dns_rounded,
                            color: AppColors.textMuted, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            serverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_serverStatus != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Server status: $_serverStatus',
                style: TextStyle(
                  color: (_serverStatus ?? '').startsWith('Online')
                      ? gold
                      : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Text(
            'Test ID: ${_testId ?? '—'}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  // Navigate to history for detailed past results
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Download ${(download ?? 0).toStringAsFixed(1)} $_unit · '
                        'Upload ${(upload ?? 0).toStringAsFixed(1)} $_unit · '
                        'Ping ${(ping ?? 0).toStringAsFixed(0)} ms · '
                        'Avg ${(avgPing ?? 0).toStringAsFixed(0)} ms · '
                        'Jitter ${(jitter ?? 0).toStringAsFixed(0)} ms · '
                        'Loss ${(packetLoss ?? 0).toStringAsFixed(0)}%',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text(
                  'Detailed result',
                  style: TextStyle(
                    color: Color(0xFF4DA3FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: startTest,
                child: const Text(
                  'Test Again',
                  style: TextStyle(
                    color: Color(0xFF4DA3FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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


  Widget _latencyMetricsRow() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _latencyChip(
              label: 'Ping',
              value: ping,
              unit: 'ms',
              icon: Icons.speed_rounded,
            ),
            _latencyChip(
              label: 'Avg',
              value: avgPing ?? (running && phase == SpeedTestPhase.ping ? ping : avgPing),
              unit: 'ms',
              icon: Icons.timelapse_rounded,
            ),
            _latencyChip(
              label: 'Jitter',
              value: jitter,
              unit: 'ms',
              icon: Icons.waves_rounded,
            ),
            _latencyChip(
              label: 'Loss',
              value: packetLoss,
              unit: '%',
              icon: Icons.signal_cellular_alt_rounded,
              fractionDigits: 0,
            ),
          ],
        ),
        if (maxPing != null && maxPing! > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Max latency ${maxPing!.toStringAsFixed(0)} ms',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _latencyChip({
    required String label,
    required double? value,
    required String unit,
    required IconData icon,
    int fractionDigits = 0,
  }) {
    final display = value == null
        ? '—'
        : value.toStringAsFixed(fractionDigits);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: gold),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: display,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          appMenuButton(context),
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
