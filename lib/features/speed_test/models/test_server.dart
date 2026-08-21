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
    this.pingPath = '/ping',
    this.latencyMs,
    this.network = 'OpenSpeedTest',
    this.engine = TestEngine.mport,
    this.externalUrl,
  });

  factory TestServer.haansiro() => const TestServer(
        id: 'haansiro', name: 'HaaNSirO', host: 'speed2.haansiro.id',
        location: 'Indonesia', country: 'ID', isDefault: true,
        scheme: 'https', downloadPath: '/downloading', uploadPath: '/upload',
        pingPath: '/', network: 'HaaNSirO', engine: TestEngine.mport,
      );

  factory TestServer.fromCbn(Map<String, dynamic> json) {
    final url = (json['url'] as String? ?? '').replaceAll(r'\/', '/');
    final uri = Uri.tryParse(url);
    final host = (json['host'] as String?) ?? uri?.authority ?? '';
    final location = (json['name'] as String?) ?? 'CBN';
    return TestServer(
      id: 'cbn-${json['id'] ?? host}', name: 'CBN $location', host: host,
      location: location, country: json['cc'] as String? ?? 'ID',
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lon'] as num?)?.toDouble(),
      distanceKm: (json['distance'] as num?)?.round(), scheme: 'https',
      network: 'CBN / Speedtest Custom', engine: TestEngine.cbnSpeedtestCustom,
      externalUrl: 'https://cbn.speedtestcustom.com',
    );
  }

  static List<TestServer> catalog() => [TestServer.haansiro()];

  TestServer copyWith({double? latencyMs, int? distanceKm}) => TestServer(
    id: id, name: name, host: host, location: location, country: country,
    latitude: latitude, longitude: longitude,
    distanceKm: distanceKm ?? this.distanceKm, isDefault: isDefault,
    scheme: scheme, downloadPath: downloadPath, uploadPath: uploadPath,
    pingPath: pingPath, latencyMs: latencyMs ?? this.latencyMs,
    network: network, engine: engine, externalUrl: externalUrl,
  );

  @override
  String toString() => '$name ($location)';
}
