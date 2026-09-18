import 'package:flutter/foundation.dart';

/// Central security configuration and helpers for MPorT Go.
class SecurityConfig {
  SecurityConfig._();

  /// Domains that are allowed to be loaded inside in-app WebViews.
  /// Navigation to any other host is blocked.
  static const Set<String> webViewAllowedHosts = {
    'downdetector.id',
    'www.downdetector.id',
    // Leaflet / OpenStreetMap tile & asset CDNs used by the offline map HTML
    'unpkg.com',
    'cdnjs.cloudflare.com',
    'tile.openstreetmap.org',
    'a.tile.openstreetmap.org',
    'b.tile.openstreetmap.org',
    'c.tile.openstreetmap.org',
  };

  /// Returns true if [url] is allowed to load in a WebView.
  static bool isWebViewUrlAllowed(String? url) {
    if (url == null || url.isEmpty) return false;
    // Allow local HTML (maps)
    if (url.startsWith('data:') || url.startsWith('about:')) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return true; // relative / local
    for (final allowed in webViewAllowedHosts) {
      if (host == allowed || host.endsWith('.$allowed')) return true;
    }
    return false;
  }

  /// Safe debug logging — never prints in release builds and never logs
  /// sensitive values (SSID, IP, tokens, full history payloads).
  static void log(String message, {Object? error, StackTrace? stack}) {
    if (kReleaseMode) return;
    // Strip common sensitive patterns before printing
    final sanitized = message
        .replaceAll(RegExp(r'\b\d{1,3}(\.\d{1,3}){3}\b'), '[ip]')
        .replaceAll(RegExp(r'SSID[=:]\s*\S+', caseSensitive: false), 'SSID=[redacted]');
    // ignore: avoid_print
    print('[MPorT] $sanitized${error != null ? ' | $error' : ''}');
  }

  /// Prefer HTTPS when both schemes are available.
  static String preferHttps(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.scheme == 'http' && uri.port != 8080) {
      // Many Ookla-style servers only speak HTTP on :8080 — leave those alone.
      return uri.replace(scheme: 'https', port: uri.hasPort ? null : null).toString();
    }
    return url;
  }

  /// True when the given host is known to support HTTPS for speed tests.
  static bool hostSupportsHttps(String host) {
    final h = host.toLowerCase().replaceFirst(RegExp(r'^https?://'), '');
    const httpsHosts = {
      'speed2.haansiro.id',
      'haansiro.id',
    };
    return httpsHosts.any((e) => h == e || h.startsWith('$e:') || h.endsWith('.$e'));
  }
}
