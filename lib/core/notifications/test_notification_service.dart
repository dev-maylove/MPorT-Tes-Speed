import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows a local notification when a speed test finishes.
class TestNotificationService {
  TestNotificationService._();
  static final TestNotificationService instance = TestNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'mport_speed_test';
  static const _channelName = 'Speed Test Results';
  static const _channelDesc = 'Notifications when a speed test completes';

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> showTestComplete({
    required double downloadMbps,
    required double uploadMbps,
    required double pingMs,
    double? jitterMs,
  }) async {
    if (!_ready || kIsWeb) return;
    try {
      final body = '↓ ${downloadMbps.toStringAsFixed(1)} Mbps  '
          '↑ ${uploadMbps.toStringAsFixed(1)} Mbps  '
          'Ping ${pingMs.toStringAsFixed(0)} ms'
          '${jitterMs != null ? '  Jitter ${jitterMs.toStringAsFixed(0)} ms' : ''}';

      await _plugin.show(
        1001,
        'MPorT Go — Tes selesai',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'speed_test_complete',
      );
    } catch (_) {}
  }
}
