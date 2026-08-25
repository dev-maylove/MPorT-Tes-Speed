import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions needed by MPorT Go.
///
/// - **Location** (when-in-use): required by Android to read Wi-Fi SSID
///   via [network_info_plus] (API ≤ 32). On API 33+ we also request
///   [Permission.nearbyWifiDevices].
/// - **Notification**: Android 13+ (POST_NOTIFICATIONS) for optional
///   test-complete alerts.
class AppPermissions {
  AppPermissions._();

  /// Request every permission the speed-test flow needs.
  /// Safe to call multiple times; already-granted permissions are skipped.
  static Future<AppPermissionResult> requestAll() async {
    if (kIsWeb) {
      return const AppPermissionResult(
        location: PermissionStatus.granted,
        nearbyWifi: PermissionStatus.granted,
        notification: PermissionStatus.granted,
      );
    }

    final results = <Permission, PermissionStatus>{};

    // Location — Wi-Fi SSID on Android ≤ 12, and general network context
    if (Platform.isAndroid || Platform.isIOS) {
      results[Permission.locationWhenInUse] =
          await Permission.locationWhenInUse.request();
    }

    // Nearby Wi-Fi devices — Android 13+ (SSID without continuous location)
    if (Platform.isAndroid) {
      results[Permission.nearbyWifiDevices] =
          await Permission.nearbyWifiDevices.request();
    }

    // Notifications — Android 13+ / iOS
    if (Platform.isAndroid || Platform.isIOS) {
      results[Permission.notification] =
          await Permission.notification.request();
    }

    return AppPermissionResult(
      location: results[Permission.locationWhenInUse] ?? PermissionStatus.denied,
      nearbyWifi:
          results[Permission.nearbyWifiDevices] ?? PermissionStatus.granted,
      notification:
          results[Permission.notification] ?? PermissionStatus.granted,
    );
  }

  /// Whether we can reliably read the Wi-Fi SSID.
  static Future<bool> canReadWifiSsid() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      return Permission.locationWhenInUse.isGranted;
    }
    if (Platform.isAndroid) {
      final loc = await Permission.locationWhenInUse.isGranted;
      final nearby = await Permission.nearbyWifiDevices.isGranted;
      // Either is enough depending on API level; accept if any granted.
      return loc || nearby;
    }
    return false;
  }

  static Future<bool> get isLocationGranted async =>
      Permission.locationWhenInUse.isGranted;

  static Future<bool> get isNotificationGranted async =>
      Permission.notification.isGranted;

  /// Open the system app-settings page so the user can enable permissions.
  static Future<bool> openSettings() => openAppSettings();
}

class AppPermissionResult {
  final PermissionStatus location;
  final PermissionStatus nearbyWifi;
  final PermissionStatus notification;

  const AppPermissionResult({
    required this.location,
    required this.nearbyWifi,
    required this.notification,
  });

  bool get locationOk =>
      location.isGranted || location.isLimited;

  bool get notificationOk =>
      notification.isGranted || notification.isLimited;

  bool get allOk => locationOk && notificationOk;
}
