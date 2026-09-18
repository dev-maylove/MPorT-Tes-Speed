import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'security_config.dart';

/// Lightweight device integrity heuristics.
///
/// Full Google Play Integrity API requires Play Console setup and is left as
/// a future enhancement. This helper only surfaces basic signals that can
/// still be useful for logging / soft warnings.
class DeviceIntegrity {
  DeviceIntegrity._();

  static Future<DeviceIntegrityResult> check() async {
    if (kIsWeb) {
      return const DeviceIntegrityResult(isEmulator: false, isLikelyRooted: false);
    }

    var isEmulator = false;
    var isLikelyRooted = false;

    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        isEmulator = !info.isPhysicalDevice ||
            (info.fingerprint.toLowerCase().contains('generic')) ||
            (info.model.toLowerCase().contains('sdk')) ||
            (info.manufacturer.toLowerCase().contains('genymotion'));
        // Soft heuristic only — never treat as hard block
        isLikelyRooted = info.tags.contains('test-keys');
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        isEmulator = !info.isPhysicalDevice;
      }
    } catch (e) {
      SecurityConfig.log('DeviceIntegrity check failed', error: e);
    }

    return DeviceIntegrityResult(
      isEmulator: isEmulator,
      isLikelyRooted: isLikelyRooted,
    );
  }
}

class DeviceIntegrityResult {
  final bool isEmulator;
  final bool isLikelyRooted;

  const DeviceIntegrityResult({
    required this.isEmulator,
    required this.isLikelyRooted,
  });

  bool get hasAnomaly => isEmulator || isLikelyRooted;
}
