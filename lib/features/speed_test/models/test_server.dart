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
  });

  factory TestServer.haansiro() => const TestServer(
        id: 'haansiro',
        name: 'HaaNSirO',
        host: 'speed2.haansiro.id',
        location: 'Indonesia',
        country: 'ID',
        latitude: -6.2088,
        longitude: 106.8456,
        isDefault: true,
        scheme: 'https',
        downloadPath: '/downloading',
        uploadPath: '/upload',
        pingPath: '/',
        network: 'HaaNSirO',
      );

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
      );

  @override
  String toString() => '$name ($location)';
}
