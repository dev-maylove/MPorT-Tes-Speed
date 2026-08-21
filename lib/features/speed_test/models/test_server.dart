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
  final String downloadPath;
  final String uploadPath;
  final double? latencyMs;
  final String network; // label jaringan (HaaNSirO, OpenSpeedTest, Arab, dll)

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
    this.downloadPath = '/downloading',
    this.uploadPath = '/upload',
    this.latencyMs,
    this.network = 'OpenSpeedTest',
  });

  factory TestServer.haansiro() {
    return const TestServer(
      id: 'haansiro',
      name: 'HaaNSirO',
      host: 'speed2.haansiro.id',
      location: 'Indonesia',
      country: 'ID',
      isDefault: true,
      network: 'HaaNSirO',
    );
  }

  /// Katalog multi-region + Arab Network.
  static List<TestServer> catalog() => [
        TestServer.haansiro(),
        // ── Arab Network / Timur Tengah ──
        const TestServer(
          id: 'arab-ae',
          name: 'Arab Network AE',
          host: 'ae.openspeedtest.com',
          location: 'UAE / Dubai',
          country: 'AE',
          network: 'Arab Network',
        ),
        const TestServer(
          id: 'arab-sa',
          name: 'Arab Network SA',
          host: 'sa.openspeedtest.com',
          location: 'Saudi Arabia',
          country: 'SA',
          network: 'Arab Network',
        ),
        const TestServer(
          id: 'arab-eg',
          name: 'Arab Network EG',
          host: 'eg.openspeedtest.com',
          location: 'Egypt',
          country: 'EG',
          network: 'Arab Network',
        ),
        // ── Asia ──
        const TestServer(
          id: 'ost-sg',
          name: 'OpenSpeedTest SG',
          host: 'openspeedtest.server.net',
          location: 'Singapore',
          country: 'SG',
          network: 'OpenSpeedTest',
        ),
        const TestServer(
          id: 'ost-jp',
          name: 'OpenSpeedTest JP',
          host: 'jp.openspeedtest.com',
          location: 'Tokyo',
          country: 'JP',
          network: 'OpenSpeedTest',
        ),
        const TestServer(
          id: 'ost-in',
          name: 'OpenSpeedTest IN',
          host: 'in.openspeedtest.com',
          location: 'India',
          country: 'IN',
          network: 'OpenSpeedTest',
        ),
        // ── Global ──
        const TestServer(
          id: 'ost-us',
          name: 'OpenSpeedTest US',
          host: 'us.openspeedtest.com',
          location: 'United States',
          country: 'US',
          network: 'OpenSpeedTest',
        ),
        const TestServer(
          id: 'ost-eu',
          name: 'OpenSpeedTest EU',
          host: 'eu.openspeedtest.com',
          location: 'Europe',
          country: 'EU',
          network: 'OpenSpeedTest',
        ),
        const TestServer(
          id: 'haansiro-backup',
          name: 'HaaNSirO Mirror',
          host: 'speed2.haansiro.id',
          location: 'Indonesia (mirror)',
          country: 'ID',
          network: 'HaaNSirO',
        ),
      ];

  TestServer copyWith({
    double? latencyMs,
    int? distanceKm,
  }) {
    return TestServer(
      id: id,
      name: name,
      host: host,
      location: location,
      country: country,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      isDefault: isDefault,
      downloadPath: downloadPath,
      uploadPath: uploadPath,
      latencyMs: latencyMs ?? this.latencyMs,
      network: network,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'location': location,
        'country': country,
        'network': network,
        'latencyMs': latencyMs,
        'isDefault': isDefault,
      };

  factory TestServer.fromJson(Map<String, dynamic> json) {
    return TestServer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      location: json['location'] as String? ?? '',
      country: json['country'] as String? ?? '',
      network: json['network'] as String? ?? 'OpenSpeedTest',
      isDefault: json['isDefault'] as bool? ?? false,
      latencyMs: (json['latencyMs'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() => '$name ($location)';
}
