import 'dart:convert' show jsonDecode;

enum TestEngine { mport, cbnSpeedtestCustom }

class TestServer {
  final String id;
  final String name;
  final String host;
  final String location;
  final String country;
  final double? latitude;
  final double? longitude;
  final int? distanceKm;
  final bool isDefault;
  final String scheme;
  final String downloadPath;
  final String uploadPath;
  final String pingPath;
  final double? latencyMs;
  final String network;
  final TestEngine engine;
  final String? externalUrl;

  const TestServer({
    required this.id,
    required this.name,
    required this.host,
    required this.location,
    this.country = '',
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.isDefault = false,
    this.scheme = 'https',
    this.downloadPath = '/downloading',
    this.uploadPath = '/upload',
    this.pingPath = '/',
    this.latencyMs,
    this.network = 'HaaNSirO',
    this.engine = TestEngine.mport,
    this.externalUrl,
  });

  factory TestServer.haansiro() => const TestServer(
        id: 'haansiro',
        name: 'HaaNSirO',
        host: 'speed2.haansiro.id',
        location: 'Indonesia',
        country: 'ID',
        isDefault: true,
        scheme: 'https',
        downloadPath: '/downloading',
        uploadPath: '/upload',
        pingPath: '/',
        network: 'HaaNSirO',
        engine: TestEngine.mport,
      );

  /// Parse satu item dari API CBN Speedtest Custom.
  /// Mengembalikan null jika data tidak valid / non-aktif.
  static TestServer? tryFromCbn(Object? raw) {
    if (raw is! Map) return null;

    // Akses langsung tanpa Map.from (lebih hemat alokasi)
    final status = raw['status'];
    if (status != null && status != 1 && status != '1' && status != true) {
      return null;
    }

    final hostField = raw['host'];
    final urlField = raw['url'];

    String host = '';
    if (hostField is String && hostField.isNotEmpty) {
      host = hostField;
    } else if (urlField is String && urlField.isNotEmpty) {
      // API kadang meng-escape slash: https:\/\/host\/path
      final cleaned = urlField.replaceAll(r'\/', '/');
      final uri = Uri.tryParse(cleaned);
      host = uri?.host ?? '';
      if (host.isEmpty) {
        final withoutScheme = cleaned.replaceFirst(RegExp(r'^https?://'), '');
        host = withoutScheme.split('/').first;
      }
    }
    if (host.isEmpty) return null;

    final idRaw = raw['id'];
    final id = idRaw != null ? 'cbn-$idRaw' : 'cbn-$host';

    final nameField = raw['name'];
    final location =
        nameField is String && nameField.isNotEmpty ? nameField : 'CBN';

    final cc = raw['cc'];
    final country = cc is String && cc.isNotEmpty ? cc : 'ID';

    return TestServer(
      id: id,
      name: 'CBN $location',
      host: host,
      location: location,
      country: country,
      latitude: _toDouble(raw['lat']),
      longitude: _toDouble(raw['lon']),
      distanceKm: _toInt(raw['distance']),
      scheme: 'https',
      network: 'CBN / Speedtest Custom',
      engine: TestEngine.cbnSpeedtestCustom,
      externalUrl: 'https://cbn.speedtestcustom.com',
    );
  }

  /// Kompatibel dengan pemanggilan lama.
  factory TestServer.fromCbn(Map<String, dynamic> json) {
    return tryFromCbn(json) ??
        const TestServer(
          id: 'cbn-invalid',
          name: 'CBN',
          host: '',
          location: 'CBN',
          engine: TestEngine.cbnSpeedtestCustom,
          externalUrl: 'https://cbn.speedtestcustom.com',
        );
  }

  static double? _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
    return null;
  }

  static List<TestServer> catalog() => [TestServer.haansiro()];

  TestServer copyWith({double? latencyMs, int? distanceKm}) => TestServer(
        id: id,
        name: name,
        host: host,
        location: location,
        country: country,
        latitude: latitude,
        longitude: longitude,
        distanceKm: distanceKm ?? this.distanceKm,
        isDefault: isDefault,
        scheme: scheme,
        downloadPath: downloadPath,
        uploadPath: uploadPath,
        pingPath: pingPath,
        latencyMs: latencyMs ?? this.latencyMs,
        network: network,
        engine: engine,
        externalUrl: externalUrl,
      );

  @override
  String toString() => '$name ($location)';
}

/// Top-level agar bisa dijalankan di isolate lewat [compute].
/// Input: body JSON mentah (String). Output: daftar server CBN valid.
List<TestServer> parseCbnServersJson(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) return const [];

  final out = <TestServer>[];
  final seen = <String>{};

  for (final item in decoded) {
    final server = TestServer.tryFromCbn(item);
    if (server == null) continue;
    if (!seen.add(server.id)) continue;
    out.add(server);
  }
  return out;
}
