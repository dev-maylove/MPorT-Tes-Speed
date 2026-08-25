import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import '../../../core/constants/server_config.dart';
import '../../../core/notifications/test_notification_service.dart';
import '../../../core/permissions/app_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../server/screens/server_screen.dart';
import '../../server/services/server_service.dart';
import '../models/speed_test_state.dart';
import '../services/asn_isp_service.dart';
import '../services/history_service.dart';
import '../services/realtime_service.dart';
import '../services/speed_test_service.dart';
import 'main_screen.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  // Theme-aware palette (light + dark)
  Color get gold => AppPalette.of(context).primary;
  Color get goldLight => AppPalette.of(context).primaryLight;
  Color get background => AppPalette.of(context).background;
  Color get sheetColor => AppPalette.of(context).sheet;
  Color get cardColor => AppPalette.of(context).card;
  Color get textPri => AppPalette.of(context).textPrimary;
  Color get textSec => AppPalette.of(context).textSecondary;
  Color get textMut => AppPalette.of(context).textMuted;
  Color get borderDim => AppPalette.of(context).isDark
      ? AppColors.greenDim
      : AppPalette.of(context).primary.withValues(alpha: 0.25);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  final SpeedTestService _service = SpeedTestService();
  final HistoryService _historyService = HistoryService();
  final ServerService _serverService = ServerService.instance;
  final RealtimeService _realtime = RealtimeService.instance;
  final AsnIspService _asnIsp = AsnIspService.instance;

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
  /// Bumps on cancel so an in-flight test cannot overwrite UI after cancel.
  int _testGeneration = 0;
  String? _ispName;
  String? _deviceNetworkName; // Wi-Fi SSID or mobile network label
  /// Active path: wifi | mobile | ethernet | none
  String _connectionKind = 'none';
  String? _serverDisplay;
  String _deviceModel = '—';
  String? _testId;
  String? _serverStatus; // Online / Offline / latency

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  String? _connectivityKey; // fingerprint of last connectivity type(s)

  // Bottom sheet
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  double _sheetSize = 0.14;

  // Settings in sheet
  String _unit = 'Mbps';
  int _scale = 100;
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
        // Update values only — AnimatedBuilder rebuilds the gauge.
        // Avoid setState here: full-tree rebuild every frame makes start-test feel laggy.
        _animSpeed = _speedTween.value;
        _animProgress = _progressTween.value;
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
    _listenConnectivity();
    // Request location + notification (and nearby Wi-Fi) then refresh SSID label
    // ignore: unawaited_futures
    _bootstrapPermissions();
    // After first frame: pre-allocate upload buffer so start-test stays snappy
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _service.warmUp();
    });
  }

  /// Ask for runtime permissions once, then re-read Wi-Fi SSID / connection kind.
  Future<void> _bootstrapPermissions() async {
    try {
      await AppPermissions.requestAll();
    } catch (_) {
      // Permission dialog dismissed / plugin missing — still try SSID read
    }
    if (!mounted) return;
    await _loadDeviceNetworkName();
  }

  /// Clears ASN/ISP cache when Wi-Fi ↔ mobile (or offline) so Network label
  /// stays accurate after the user switches networks.
  void _listenConnectivity() {
    // Seed current state without forcing a refresh.
    Connectivity().checkConnectivity().then((list) {
      _connectivityKey = _connectivityFingerprint(list);
    }).catchError((_) {});

    _connectivitySub = Connectivity().onConnectivityChanged.listen((list) {
      final key = _connectivityFingerprint(list);
      if (_connectivityKey == null) {
        _connectivityKey = key;
        return;
      }
      if (key == _connectivityKey) return;
      _connectivityKey = key;
      // ignore: unawaited_futures
      _onNetworkPathChanged();
    });
  }

  String _connectivityFingerprint(List<ConnectivityResult> list) {
    if (list.isEmpty) return 'none';
    final sorted = List<ConnectivityResult>.from(list)
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted.map((e) => e.name).join(',');
  }

  Future<void> _onNetworkPathChanged() async {
    await _asnIsp.clearCache();
    if (!mounted) return;
    await Future.wait([
      _loadDeviceNetworkName(),
      _fetchMeta(forceRefresh: true),
    ]);
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

  void _animateGaugeTo(double speedMbps, {bool lock = false}) {
    // Grow scale so the needle uses a meaningful portion of the dial.
    _ensureScaleFor(speedMbps);
    final targetProgress = _speedToProgress(speedMbps);

    // Continue from the *current visual* position (even mid-tween) so the
    // needle never jumps when progress updates arrive rapidly.
    final beginSpeed =
        _gaugeCtrl.isAnimating ? _speedTween.value : _animSpeed;
    final beginProgress =
        _gaugeCtrl.isAnimating ? _progressTween.value : _animProgress;

    final speedDelta = (speedMbps - beginSpeed).abs();
    final progressDelta = (targetProgress - beginProgress).abs();

    // Ignore small updates — fewer tween restarts = smoother UI under load.
    if (speedDelta < 0.8 && progressDelta < 0.012 && !lock) {
      return;
    }

    _speedTween = Tween<double>(begin: beginSpeed, end: speedMbps).animate(
      CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic),
    );
    _progressTween =
        Tween<double>(begin: beginProgress, end: targetProgress).animate(
      CurvedAnimation(parent: _gaugeCtrl, curve: Curves.easeOutCubic),
    );

    // Longer duration for bigger swings → smoother, more fluid motion.
    final ms = (260 + progressDelta * 700 + speedDelta * 1.5)
        .round()
        .clamp(220, 900);

    _gaugeCtrl
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);

    if (lock) {
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          _gaugeCtrl.removeStatusListener(listener);
          if (!mounted) return;
          setState(() {
            _animSpeed = speedMbps;
            _animProgress = targetProgress;
          });
        }
      }
      _gaugeCtrl.addStatusListener(listener);
    }
  }

  /// Raise gauge scale when measured speed approaches the current max.
  void _ensureScaleFor(double speedMbps) {
    if (speedMbps <= 0) return;
    // Prefer user-selected scale, but auto-bump if needle would peg near the rim.
    final thresholds = <int>[100, 200, 500, 1000, 2000, 5000];
    var needed = _scale;
    for (final t in thresholds) {
      if (speedMbps <= t * 0.85) {
        needed = t;
        break;
      }
      needed = t;
    }
    // Never shrink below the user's explicit choice during an active test.
    if (needed > _scale) {
      _scale = needed;
    }
  }

  double _speedToProgress(double s) {
    final maxScale = _scale.toDouble().clamp(1.0, 1e9);
    if (s <= 0) return 0;
    return (s / maxScale).clamp(0.0, 1.0);
  }

  /// Convert internal Mbps value to the user-selected display unit.
  /// Mbps stays as-is; MB/s = Mbps/8; kB/s = Mbps * 125.
  double _toDisplayUnit(double mbps) {
    switch (_unit) {
      case 'MB/s':
        return mbps / 8.0;
      case 'kB/s':
        return mbps * 125.0;
      default:
        return mbps;
    }
  }

  String _formatSpeed(double? mbps, {int decimals = 1}) {
    if (mbps == null) return '—';
    return _toDisplayUnit(mbps).toStringAsFixed(decimals);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
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

  Future<void> _fetchMeta({bool forceRefresh = false}) async {
    // ISP/ASN: memory → disk (15 min) → remote API. Not on every Download/Upload.
    final result = await _asnIsp.lookup(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        if (result.ispName != null && result.ispName!.isNotEmpty) {
          _ispName = result.ispName;
        } else if (forceRefresh) {
          _ispName = null;
        }
        // ASN & public IP intentionally not shown in UI
      });
    }

    final selected = _serverService.selected;
    final name = selected.name.isNotEmpty
        ? selected.name
        : (ServerConfig.serverName.isNotEmpty ? ServerConfig.serverName : 'HaaNSirO');
    if (mounted) setState(() => _serverDisplay = name);
  }

  Future<void> startTest() async {
    if (running) return;

    // Collapse sheet when starting
    try {
      _sheetCtrl.animateTo(0.14,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } catch (_) {}

    final gen = ++_testGeneration;

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
    // Lightweight status only — avoid stacking geo-IP / SSID work on test start
    // (already loaded in initState). Keeps UI responsive when user taps GO.
    // ignore: unawaited_futures
    _refreshServerStatus();

    try {
      final result = await _service.start(
        multiConnection: _multiConnection,
        onProgress: (newPhase, value) {
          if (!mounted || gen != _testGeneration) return;
          // Skip completed phase here — final values applied after await.
          if (newPhase == SpeedTestPhase.completed) return;

          double? gaugeTarget;
          setState(() {
            phase = newPhase;
            if (newPhase == SpeedTestPhase.ping) {
              ping = value;
              currentSpeed = 0;
              gaugeTarget = 0;
            } else if (newPhase == SpeedTestPhase.download) {
              download = value;
              currentSpeed = value;
              gaugeTarget = value;
            } else if (newPhase == SpeedTestPhase.upload) {
              upload = value;
              currentSpeed = value;
              gaugeTarget = value;
            }
          });
          // Animate outside setState to avoid rebuild/animation races.
          final target = gaugeTarget;
          if (target != null) {
            _animateGaugeTo(target);
          }
        },
      );

      // Cancelled while test was running — discard results.
      if (!mounted || gen != _testGeneration) return;

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
      // After test finishes: reset needle to 0 (center still shows final Mbps).
      _animateGaugeTo(0);
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
        isp: _ispName,
        networkName: _deviceNetworkName,
        connectionKind: _connectionKind,
        deviceModel: _deviceModel,
        testId: _testId,
        serverLocation: _serverService.selected.location,
      );

      // Local notification with results
      // ignore: unawaited_futures
      TestNotificationService.instance.showTestComplete(
        downloadMbps: result.download,
        uploadMbps: result.upload,
        pingMs: result.ping,
        jitterMs: result.jitter,
      );
    } catch (e) {
      if (!mounted || gen != _testGeneration) return;
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
    // Bump generation so in-flight onProgress is ignored.
    _testGeneration++;
    // Stop download/upload workers immediately.
    _service.cancel();
    setState(() {
      running = false;
      phase = SpeedTestPhase.idle;
      currentSpeed = 0;
    });
    _animateGaugeTo(0);
  }

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
  ///
  /// Important: on Wi-Fi we must NOT surface the public-IP ISP brand alone
  /// (e.g. "XL Axiata") — that looks like cellular even when the phone is on Wi-Fi.
  Future<void> _loadDeviceNetworkName() async {
    try {
      final list = await Connectivity().checkConnectivity();
      // Prefer Wi-Fi when both Wi-Fi and mobile are reported (common on Android).
      final hasWifi = list.contains(ConnectivityResult.wifi);
      final hasEthernet = list.contains(ConnectivityResult.ethernet);
      final hasMobile = list.contains(ConnectivityResult.mobile);

      String kind = 'none';
      String? name;

      if (hasWifi) {
        kind = 'wifi';
        try {
          final raw = await NetworkInfo().getWifiName();
          final cleaned = raw
              ?.trim()
              .replaceAll('"', '')
              .replaceAll("'", '');
          if (cleaned != null &&
              cleaned.isNotEmpty &&
              cleaned.toLowerCase() != '<unknown ssid>' &&
              cleaned.toLowerCase() != 'unknown ssid' &&
              cleaned.toLowerCase() != 'null') {
            name = cleaned;
          } else {
            // Location permission denied / restricted — still mark as Wi-Fi
            name = 'Wi-Fi';
          }
        } catch (_) {
          name = 'Wi-Fi';
        }
      } else if (hasEthernet) {
        kind = 'ethernet';
        name = 'Ethernet';
      } else if (hasMobile) {
        kind = 'mobile';
        name = 'Mobile data';
      }

      if (mounted) {
        setState(() {
          _connectionKind = kind;
          if (name != null) _deviceNetworkName = name;
        });
      }
    } catch (_) {
      // keep previous
    }
  }

  /// Primary network label shown in UI.
  /// Wi-Fi → SSID (or "Wi-Fi"); Mobile → ISP/carrier; never show carrier as if it were Wi-Fi.
  String get _ispLabel {
    final isp = _ispName?.trim();
    final deviceNet = _deviceNetworkName?.trim();
    final kind = _connectionKind;

    if (kind == 'wifi') {
      if (deviceNet != null &&
          deviceNet.isNotEmpty &&
          deviceNet != 'Wi-Fi') {
        return deviceNet; // real SSID
      }
      // No SSID (permission) — keep explicit Wi-Fi, do not replace with mobile ISP brand
      return 'Wi-Fi';
    }

    if (kind == 'ethernet') {
      return 'Ethernet';
    }

    if (kind == 'mobile') {
      if (isp != null && isp.isNotEmpty) return isp;
      if (deviceNet != null && deviceNet.isNotEmpty) return deviceNet;
      return 'Mobile data';
    }

    // Unknown path: prefer ISP, then device net
    if (isp != null && isp.isNotEmpty) return isp;
    if (deviceNet != null && deviceNet.isNotEmpty) return deviceNet;
    return 'Network';
  }

  /// Icon for the active connection path (not the device form-factor).
  IconData get _connectionIcon {
    switch (_connectionKind) {
      case 'wifi':
        return Icons.wifi_rounded;
      case 'ethernet':
        return Icons.settings_ethernet_rounded;
      case 'mobile':
        return Icons.signal_cellular_alt_rounded;
      default:
        return Icons.lan_rounded;
    }
  }

  String get _connectionKindLabel {
    switch (_connectionKind) {
      case 'wifi':
        return 'Wi-Fi';
      case 'mobile':
        return 'Mobile';
      case 'ethernet':
        return 'Ethernet';
      default:
        return 'Offline';
    }
  }

  Color get _connectionStatusColor {
    switch (_connectionKind) {
      case 'wifi':
      case 'ethernet':
        return gold;
      case 'mobile':
        return const Color(0xFF4DA3FF);
      default:
        return const Color(0xFFFF6B6B);
    }
  }

  /// Compact connection status chip (Wi-Fi / Mobile / Offline + label).
  Widget _connectionStatusChip({bool compact = false}) {
    final color = _connectionStatusColor;
    final kind = _connectionKindLabel;
    final detail = _ispLabel;
    final showDetail =
        detail.isNotEmpty && detail != kind && detail != 'Network';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live pulse dot
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) {
              final p = _connectionKind == 'none' ? 0.35 : (0.55 + _pulseCtrl.value * 0.45);
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: p),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45 * p),
                      blurRadius: 6,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 7),
          Icon(_connectionIcon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              showDetail ? '$kind · $detail' : kind,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.center,
                child: _connectionStatusChip(),
              ),
            ),
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
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                          color: borderDim,
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
                      Divider(color: gold.withValues(alpha: 0.12), height: 28),
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
                            setState(() => _scale = int.tryParse(v) ?? 100),
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
    // Layout:
    //   Network
    //   <SSID or carrier>
    //   ISP name only (no ASN / public IP)
    final isp = _ispName?.trim();
    String subtitle = _deviceModel;
    if (_connectionKind == 'wifi' &&
        isp != null &&
        isp.isNotEmpty &&
        isp != _ispLabel) {
      subtitle = isp; // e.g. provider brand under SSID — without AS/IP
    } else if (isp != null &&
        isp.isNotEmpty &&
        isp != _ispLabel &&
        _connectionKind != 'wifi') {
      subtitle = isp;
    }

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderDim),
          ),
          child: Icon(_connectionIcon, color: textPri, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Network',
                style: TextStyle(
                  color: textMut,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _ispLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textMut, fontSize: 12),
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
            border: Border.all(color: borderDim),
          ),
          child: Icon(Icons.dns_rounded, color: textPri, size: 18),
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
                style: TextStyle(
                  color: textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                loc,
                style: TextStyle(color: textMut, fontSize: 12),
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
            style: TextStyle(color: textSec, fontSize: 14),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Align(
            alignment: Alignment.center,
            child: _connectionStatusChip(compact: true),
          ),
        ),
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
                // Gauge while testing; hide after complete
                if (phase != SpeedTestPhase.completed)
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 280,
                        height: 280,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_pulseCtrl, _gaugeCtrl]),
                          builder: (context, _) {
                            final pulse = running ? _pulseCtrl.value : 0.35;
                            // Read tween values here so center text tracks the needle
                            // without full-screen setState on every frame.
                            final progress = _gaugeCtrl.isAnimating
                                ? _progressTween.value
                                : _animProgress;
                            final speed = _gaugeCtrl.isAnimating
                                ? _speedTween.value
                                : _animSpeed;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Soft glow — cheaper when not testing
                                if (running)
                                  Container(
                                    width: 250,
                                    height: 250,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: gold.withValues(
                                            alpha: 0.18 + pulse * 0.14,
                                          ),
                                          blurRadius: 22 + pulse * 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                CustomPaint(
                                  size: const Size(280, 280),
                                  painter: _ArcGaugePainter(
                                    progress: progress,
                                    gold: gold,
                                    goldLight: goldLight,
                                    pulse: running ? pulse : 0.2,
                                    showNeedle: true,
                                    isDark: _isDark,
                                  ),
                                ),
                                _gaugeCenterValue(speedOverride: speed),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  )
                else
                  // After test: no gauge — result panel fills the space
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: _resultFooter(),
                      ),
                    ),
                  ),
                // ISP row only while test is running
                if (phase != SpeedTestPhase.completed) _testingIspServerRow(),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget _gaugeCenterValue({double? speedOverride}) {
    // Always show speed on dial (0.0 while waiting / idle of phase)
    final raw = speedOverride ??
        (running
            ? _animSpeed
            : (phase == SpeedTestPhase.completed
                ? (download ?? _animSpeed)
                : _animSpeed));
    final value = _toDisplayUnit(raw);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speed + unit on one line: "39.3 Mbps"
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                color: AppPalette.of(context).textPrimary,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: -0.8,
                shadows: [
                  Shadow(color: gold.withValues(alpha: 0.5), blurRadius: 18),
                  const Shadow(color: Colors.black87, blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _unit,
              style: TextStyle(
                color: goldLight.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                height: 1,
              ),
            ),
          ],
        ),

        // Push branding below the needle hub so the pointer never covers it
        const SizedBox(height: 32),

        // MPorT GO — match logo art (gradient, glow, motion streaks)
        _mportGoLogoBrand(),
      ],
    );
  }



  /// Logo-faithful "MPorT / GO »» / TEST SPEED" wordmark (matches brand art).
  Widget _mportGoLogoBrand() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // MPorT with cyan→white metallic gradient + left motion streaks
        SizedBox(
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -36,
                child: CustomPaint(
                  size: const Size(40, 22),
                  painter: _MotionStreakPainter(
                    color: const Color(0xFF4DA3FF).withValues(alpha: 0.55),
                  ),
                ),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFB8F3FF),
                    Color(0xFF5CE1FF),
                    Color(0xFF2BB8FF),
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ).createShader(bounds),
                child: Text(
                  'MPorT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    height: 1,
                    shadows: [
                      Shadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.75),
                        blurRadius: 16,
                      ),
                      Shadow(
                        color: const Color(0xFF2BB8FF).withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // GO »» blue neon
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF9BD4FF),
                  Color(0xFF3B9EFF),
                  Color(0xFF1A6FE0),
                ],
              ).createShader(bounds),
              child: const Text(
                'GO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.2,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 4),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6EC8FF), Color(0xFF3B9EFF)],
              ).createShader(bounds),
              child: const Text(
                '»»',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ECG cyan · TEST SPEED · ECG purple
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ecgDecor(const Color(0xFF5CE1FF).withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(
              'TEST SPEED',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.6,
              ),
            ),
            const SizedBox(width: 6),
            _ecgDecor(const Color(0xFFB07BFF).withValues(alpha: 0.7)),
          ],
        ),
      ],
    );
  }

  Widget _ecgDecor(Color color) {
    return SizedBox(
      width: 28,
      height: 10,
      child: CustomPaint(painter: _EcgLinePainter(color: color)),
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
                        style: TextStyle(
                          color: textSec,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(_connectionIcon,
                        color: textMut, size: 14),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _deviceModel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textMut,
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
                    Icon(Icons.dns_rounded,
                        color: textMut, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        serverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: textSec,
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
                  style: TextStyle(
                    color: textMut,
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
                            style: TextStyle(
                              color: textSec,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(_connectionIcon,
                            color: textMut, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _deviceModel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textMut,
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
                        Icon(Icons.dns_rounded,
                            color: textMut, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            serverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textSec,
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
                      style: TextStyle(
                        color: textMut,
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
                      : textMut,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Text(
            'Test ID: ${_testId ?? '—'}',
            style: TextStyle(
              color: textMut,
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
                  // Open History tab for full saved results
                  MainScreen.openHistory();
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
          color: highlight ? gold.withValues(alpha: 0.4) : gold.withValues(alpha: 0.12),
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
                style: TextStyle(
                  color: textPri,
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
                _formatSpeed(value),
                style: TextStyle(
                  color: textPri,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const Spacer(),
              Text(
                _unit,
                style: TextStyle(color: textMut, fontSize: 12),
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
            style: TextStyle(
              color: textMut,
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
        border: Border.all(color: gold.withValues(alpha: 0.12)),
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
                style: TextStyle(
                  color: textMut,
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
                  style: TextStyle(
                    color: textPri,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    color: textMut,
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
        Icon(icon, color: textMut, size: 22),
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
                color: i < dots ? gold : gold.withValues(alpha: 0.12),
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
              icon: Icon(Icons.close, color: textPri),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speed_rounded, color: gold, size: 20),
                const SizedBox(width: 6),
                Text(
                  'MPorT',
                  style: TextStyle(
                    color: textPri,
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



/// Full dial gauge — matches product screenshot exactly:
/// full cyan rim, major/minor ticks (cyan→purple), needle from hub, dark face.
class _ArcGaugePainter extends CustomPainter {
  final double progress;
  final Color gold;
  final Color goldLight;
  final double pulse;
  final bool showNeedle;
  final bool isDark;

  _ArcGaugePainter({
    required this.progress,
    required this.gold,
    required this.goldLight,
    this.pulse = 0,
    this.showNeedle = true,
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 4;

    // ── Dial face ───────────────────────────────────────────────
    final faceColors = isDark
        ? const [
            Color(0xFF0E1828),
            Color(0xFF080C16),
            Color(0xFF05070E),
          ]
        : const [
            Color(0xFFFFFFFF),
            Color(0xFFF0F4F8),
            Color(0xFFE2E8F0),
          ];
    canvas.drawCircle(
      center,
      outerR - 1,
      Paint()
        ..shader = RadialGradient(
          colors: faceColors,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: outerR)),
    );

    // Soft concentric rings (screenshot grid)
    for (final f in [0.28, 0.48, 0.68, 0.86]) {
      canvas.drawCircle(
        center,
        outerR * f,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.04),
      );
    }

    // ── Tick marks around full circle ───────────────────────────
    // Major every 30° (12 marks), minor every 6°
    const majorCount = 12;
    const minorPerMajor = 5;
    const totalTicks = majorCount * minorPerMajor;
    for (var i = 0; i < totalTicks; i++) {
      final t = i / totalTicks;
      // Start from top (-pi/2) going clockwise visually via Flutter CW angles
      final angle = -math.pi / 2 + t * math.pi * 2;
      final isMajor = i % minorPerMajor == 0;

      // Left/top cyan, right side shifts purple (as in screenshot)
      final purple = (t > 0.45 && t < 0.9)
          ? ((t - 0.45) / 0.45).clamp(0.0, 1.0)
          : 0.0;
      final tickColor = Color.lerp(
        gold,
        const Color(0xFF9B7BFF),
        purple * 0.9,
      )!
          .withValues(alpha: isMajor ? 1.0 : 0.55);

      final outer = outerR - 10;
      final inner = outerR - (isMajor ? 28.0 : 18.0);
      final p1 = Offset(
        center.dx + math.cos(angle) * inner,
        center.dy + math.sin(angle) * inner,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * outer,
        center.dy + math.sin(angle) * outer,
      );
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = tickColor
          ..strokeWidth = isMajor ? 3.0 : 1.4
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Outer neon rim ──────────────────────────────────────────
    // Glow — lighter blur when pulse is low (cheaper during idle / start)
    final glowBlur = pulse > 0.4 ? 12.0 : 6.0;
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 + pulse * 3
        ..color = gold.withValues(alpha: 0.22 + pulse * 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur),
    );
    // Solid gradient ring (cyan → purple → cyan)
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [
            gold,
            goldLight,
            const Color(0xFF6EC8FF),
            const Color(0xFF8B6CFF),
            gold,
          ],
          stops: const [0.0, 0.2, 0.45, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: outerR)),
    );

    // ── Needle (classic meter: 0 at bottom-left ~ 225° style) ───
    // Map progress 0..1 onto arc from ~210° to ~-30° (270° sweep)
    // Flutter angles: 0 = east, positive = clockwise
    // Screenshot rest position ≈ lower-left (about 7–8 o'clock)
    const arcStart = math.pi * 0.75; // SW
    const arcSweep = math.pi * 1.5; // 270° CW toward SE via N
    final p = progress.clamp(0.0, 1.0);
    final needleAngle = arcStart + arcSweep * p;
    final needleLen = outerR - 36;

    if (showNeedle) {
      final tip = Offset(
        center.dx + math.cos(needleAngle) * needleLen,
        center.dy + math.sin(needleAngle) * needleLen,
      );
      final tail = Offset(
        center.dx - math.cos(needleAngle) * 20,
        center.dy - math.sin(needleAngle) * 20,
      );

      // Glow
      canvas.drawLine(
        tail,
        tip,
        Paint()
          ..color = gold.withValues(alpha: 0.45)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Body
      canvas.drawLine(
        tail,
        tip,
        Paint()
          ..shader = LinearGradient(
            colors: [goldLight, Colors.white, gold],
          ).createShader(Rect.fromPoints(tail, tip))
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );
      // Bright tip
      canvas.drawCircle(
        tip,
        3.2,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(tip, 2.2, Paint()..color = goldLight);

      // Hub
      canvas.drawCircle(center, 11, Paint()..color = const Color(0xFF0A1422));
      canvas.drawCircle(
        center,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = gold,
      );
      canvas.drawCircle(center, 4.0, Paint()..color = goldLight);
    }
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.progress != progress ||
      old.pulse != pulse ||
      old.showNeedle != showNeedle ||
      old.isDark != isDark ||
      old.gold != gold;
}

/// Tiny ECG / pulse decoration beside "TEST SPEED".
class _EcgLinePainter extends CustomPainter {
  final Color color;
  _EcgLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width * 0.22, size.height * 0.55)
      ..lineTo(size.width * 0.32, size.height * 0.15)
      ..lineTo(size.width * 0.42, size.height * 0.9)
      ..lineTo(size.width * 0.52, size.height * 0.35)
      ..lineTo(size.width * 0.62, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.55);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _EcgLinePainter old) => old.color != color;
}

/// Horizontal speed lines behind "MPorT" (logo motion effect).
class _MotionStreakPainter extends CustomPainter {
  final Color color;
  _MotionStreakPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final ys = [size.height * 0.25, size.height * 0.5, size.height * 0.75];
    final lens = [size.width * 0.55, size.width * 0.95, size.width * 0.7];
    for (var i = 0; i < ys.length; i++) {
      final y = ys[i];
      final len = lens[i];
      canvas.drawLine(
        Offset(size.width - len, y),
        Offset(size.width, y),
        paint..color = color.withValues(alpha: 0.25 + i * 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MotionStreakPainter old) => old.color != color;
}
