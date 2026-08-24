import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Local ASN/ISP lookup with disk + memory cache.
///
/// Flow:
///   public IP → ASN/ISP (API) → normalize → cache 15–30 min
///
/// Avoids hitting external geo-IP APIs on every Download/Upload press.
/// Also keeps a small offline ASN → name map for common Indonesian providers.
class AsnIspService {
  AsnIspService._();
  static final AsnIspService instance = AsnIspService._();

  static const _cacheKey = 'mport_asn_isp_cache_v1';
  /// Keep ISP/ASN warm for one session without re-hitting geo-IP APIs.
  static const _cacheTtl = Duration(minutes: 15);

  /// In-memory cache for the current process.
  _IspCacheEntry? _memory;

  /// In-flight remote lookup — prevents duplicate API calls when
  /// init + connectivity + startTest all request meta at once.
  Future<IspLookupResult>? _inFlight;

  /// Last known values (for UI before async completes).
  String? lastIspName;
  String? lastPublicIp;
  String? lastAsn;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Returns ISP display name. Uses cache when still valid for the same IP.
  Future<IspLookupResult> lookup({bool forceRefresh = false}) async {
    // 1) Memory cache
    if (!forceRefresh && _memory != null && !_memory!.isExpired) {
      return _apply(_memory!, fromCache: true);
    }

    // 2) Disk cache
    if (!forceRefresh) {
      final disk = await _loadDisk();
      if (disk != null && !disk.isExpired && disk.ispName.isNotEmpty) {
        _memory = disk;
        return _apply(disk, fromCache: true);
      }
    }

    // 3) Coalesce concurrent remote lookups
    if (_inFlight != null && !forceRefresh) {
      return _inFlight!;
    }

    final future = _lookupRemote();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  Future<IspLookupResult> _lookupRemote() async {
    final fresh = await _fetchRemote();
    if (fresh != null && fresh.ispName.isNotEmpty) {
      _memory = fresh;
      await _saveDisk(fresh);
      return _apply(fresh, fromCache: false);
    }

    // Stale cache as last resort
    if (_memory != null && _memory!.ispName.isNotEmpty) {
      return _apply(_memory!, fromCache: true);
    }
    final stale = await _loadDisk();
    if (stale != null && stale.ispName.isNotEmpty) {
      _memory = stale;
      return _apply(stale, fromCache: true);
    }

    return const IspLookupResult(ispName: null, publicIp: null, asn: null);
  }

  IspLookupResult _apply(_IspCacheEntry entry, {required bool fromCache}) {
    lastIspName = entry.ispName;
    lastPublicIp = entry.publicIp;
    lastAsn = entry.asn;
    return IspLookupResult(
      ispName: entry.ispName,
      publicIp: entry.publicIp,
      asn: entry.asn,
      fromCache: fromCache,
    );
  }

  /// Clear memory + disk cache (e.g. after network change).
  Future<void> clearCache() async {
    _memory = null;
    _inFlight = null;
    lastIspName = null;
    lastPublicIp = null;
    lastAsn = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }

  // ── Remote fetch ────────────────────────────────────────────────────────

  Future<_IspCacheEntry?> _fetchRemote() async {
    // Prefer endpoints that also return IP + ASN in one call.
    const endpoints = <_Endpoint>[
      _Endpoint(
        url: 'https://ip-api.com/json/?fields=status,query,isp,org,as,asname',
        ipKey: 'query',
        ispKeys: ['isp', 'org', 'asname'],
        asnKey: 'as',
      ),
      _Endpoint(
        url: 'https://ipapi.co/json/',
        ipKey: 'ip',
        ispKeys: ['isp', 'org'],
        asnKey: 'asn',
      ),
      _Endpoint(
        url: 'https://ipinfo.io/json',
        ipKey: 'ip',
        ispKeys: ['org'],
        asnKey: 'org', // often "ASxxxxx Name"
      ),
    ];

    for (final ep in endpoints) {
      try {
        final r = await http
            .get(
              Uri.parse(ep.url),
              headers: const {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 5));
        if (r.statusCode != 200) continue;

        final dynamic decoded = jsonDecode(r.body);
        if (decoded is! Map) continue;
        final map = Map<String, dynamic>.from(decoded);

        // ip-api.com returns status=fail on rate-limit / reserved IP
        final status = (map['status']?.toString() ?? '').toLowerCase();
        if (status == 'fail' || status == 'error') continue;

        final publicIp = (map[ep.ipKey]?.toString() ?? '').trim();
        final asnRaw = (map[ep.asnKey]?.toString() ?? '').trim();
        String? ispRaw;
        for (final k in ep.ispKeys) {
          final v = (map[k]?.toString() ?? '').trim();
          if (v.isNotEmpty) {
            ispRaw = v;
            break;
          }
        }

        // Extract ASN number from strings like "AS7713 PT Telekomunikasi..."
        String? asn;
        final asnMatch = RegExp(r'AS(\d+)', caseSensitive: false)
            .firstMatch(asnRaw.isNotEmpty ? asnRaw : (ispRaw ?? ''));
        if (asnMatch != null) {
          asn = 'AS${asnMatch.group(1)}';
        }

        // Prefer local ASN map when we have a known ASN.
        String ispName = '';
        if (asn != null && _localAsnMap.containsKey(asn)) {
          ispName = _localAsnMap[asn] ?? '';
        }

        // Fall back to normalized remote ISP/org name.
        if (ispName.isEmpty) {
          var raw = ispRaw ?? '';
          if (raw.isEmpty && asnRaw.isNotEmpty) {
            raw = asnRaw.replaceFirst(RegExp(r'^AS\d+\s*'), '').trim();
          } else {
            raw = raw.replaceFirst(RegExp(r'^AS\d+\s*'), '').trim();
          }
          ispName = normalizeIspName(raw);
        }

        if (ispName.isEmpty) continue;

        return _IspCacheEntry(
          ispName: ispName,
          publicIp: publicIp.isNotEmpty ? publicIp : null,
          asn: asn,
          cachedAt: DateTime.now(),
        );
      } catch (_) {
        // try next provider
      }
    }
    return null;
  }

  // ── Disk persistence ────────────────────────────────────────────────────

  Future<_IspCacheEntry?> _loadDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = _IspCacheEntry.fromJson(map);
      if (entry.ispName.isEmpty) return null;
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveDisk(_IspCacheEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(entry.toJson()));
    } catch (_) {}
  }

  // ── Local ASN database (Indonesia-focused, lightweight) ─────────────────
  //
  // Maps well-known ASN numbers → display name so we can resolve offline
  // when the remote response only gives ASN, or to prefer consistent branding.

  static const Map<String, String> _localAsnMap = {
    // Telkom / IndiHome
    'AS7713': 'Telkom / IndiHome',
    'AS17974': 'Telkom / IndiHome',
    // Telkomsel
    'AS23693': 'Telkomsel',
    'AS45727': 'Telkomsel',
    // XL Axiata / Axis
    'AS24203': 'XL Axiata',
    'AS18004': 'XL Axiata',
    // Indosat Ooredoo Hutchison
    'AS4761': 'Indosat Ooredoo',
    'AS9340': 'Indosat Ooredoo',
    // Smartfren
    'AS18007': 'Smartfren',
    'AS45728': 'Smartfren',
    // Biznet
    'AS17451': 'Biznet',
    // First Media
    'AS23700': 'First Media',
    // MyRepublic
    'AS63859': 'MyRepublic',
    // CBN
    'AS135478': 'CBN',
    // Icon+
    'AS17922': 'Icon+',
    // MNC Play
    'AS55655': 'MNC Play',
    // Oxygen.id
    'AS138840': 'Oxygen.id',
    // BOLT (historical)
    'AS58495': 'BOLT',
    // Tri / 3 Indonesia (often under IOH now)
    'AS45701': 'Tri Indonesia',
  };

  /// Normalize free-form ISP/org strings to consistent display names.
  static String normalizeIspName(String raw) {
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
        lower.contains('hutchison') ||
        lower.contains('ooredoo')) {
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
    return s.length > 32 ? '${s.substring(0, 30)}…' : s;
  }
}

// ── Models ────────────────────────────────────────────────────────────────

class IspLookupResult {
  final String? ispName;
  final String? publicIp;
  final String? asn;
  final bool fromCache;

  const IspLookupResult({
    required this.ispName,
    required this.publicIp,
    required this.asn,
    this.fromCache = false,
  });
}

class _IspCacheEntry {
  final String ispName;
  final String? publicIp;
  final String? asn;
  final DateTime cachedAt;

  const _IspCacheEntry({
    required this.ispName,
    required this.publicIp,
    required this.asn,
    required this.cachedAt,
  });

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > AsnIspService._cacheTtl;

  Map<String, dynamic> toJson() => {
        'ispName': ispName,
        'publicIp': publicIp,
        'asn': asn,
        'cachedAt': cachedAt.toIso8601String(),
      };

  factory _IspCacheEntry.fromJson(Map<String, dynamic> json) {
    return _IspCacheEntry(
      ispName: (json['ispName'] as String?) ?? '',
      publicIp: json['publicIp'] as String?,
      asn: json['asn'] as String?,
      cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _Endpoint {
  final String url;
  final String ipKey;
  final List<String> ispKeys;
  final String asnKey;

  const _Endpoint({
    required this.url,
    required this.ipKey,
    required this.ispKeys,
    required this.asnKey,
  });
}
