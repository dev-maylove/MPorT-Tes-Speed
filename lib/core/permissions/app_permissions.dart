import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions needed by MPorT Go.
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

    if (Platform.isAndroid || Platform.isIOS) {
      results[Permission.locationWhenInUse] =
          await Permission.locationWhenInUse.request();
    }

    if (Platform.isAndroid) {
      results[Permission.nearbyWifiDevices] =
          await Permission.nearbyWifiDevices.request();
      results[Permission.notification] =
          await Permission.notification.request();
    }

    if (Platform.isIOS) {
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

  static Future<bool> canReadWifiSsid() async {
    if (kIsWeb) return false;
    if (Platform.isIOS) {
      return Permission.locationWhenInUse.isGranted;
    }
    if (Platform.isAndroid) {
      final loc = await Permission.locationWhenInUse.isGranted;
      final nearby = await Permission.nearbyWifiDevices.isGranted;
      return loc || nearby;
    }
    return false;
  }

  static Future<bool> get isLocationGranted async =>
      Permission.locationWhenInUse.isGranted;

  static Future<bool> get isNotificationGranted async =>
      Permission.notification.isGranted;

  /// Open the system app-settings page.
  static Future<bool> openSettings() => openAppSettings();

  /// Request location, then open system settings so the user can enable it.
  static Future<void> openLocationSettingsFlow() async {
    if (kIsWeb) return;
    try {
      final status = await Permission.locationWhenInUse.status;
      if (status.isDenied) {
        final next = await Permission.locationWhenInUse.request();
        if (next.isGranted || next.isLimited) return;
      }
      if (status.isGranted || status.isLimited) {
        // Already granted — still open settings so user can toggle system location.
        await openAppSettings();
        return;
      }
      // Permanently denied / restricted → app settings
      await openAppSettings();
    } catch (_) {
      await openAppSettings();
    }
  }

  /// Request notification permission, then open system notification settings.
  static Future<void> openNotificationSettingsFlow() async {
    if (kIsWeb) return;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final next = await Permission.notification.request();
        if (next.isGranted || next.isLimited) return;
      }
      // Open app settings (Android shows notification toggle there)
      await openAppSettings();
    } catch (_) {
      await openAppSettings();
    }
  }
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

  bool get locationOk => location.isGranted || location.isLimited;

  bool get notificationOk =>
      notification.isGranted || notification.isLimited;

  bool get allOk => locationOk && notificationOk;
}
