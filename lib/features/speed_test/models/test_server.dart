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
  final String? externalUrl;
  final String sponsor;

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
    this.scheme = 'http',
    this.downloadPath = '/speedtest/download',
    this.uploadPath = '/speedtest/upload.php',
    this.pingPath = '/speedtest/latency.txt',
    this.latencyMs,
    this.network = '',
    this.externalUrl,
    this.sponsor = '',
  });

  /// Default: HaanSirO Network (Ookla server Pati)
  factory TestServer.haansiro() => const TestServer(
        id: '75224',
        name: 'HaanSirO Network',
        host: 'ookla.haansiro.net:8080',
        location: 'Pati',
        country: 'ID',
        latitude: -6.7487,
        longitude: 111.0379,
        distanceKm: 7,
        isDefault: true,
        scheme: 'http',
        downloadPath: '/speedtest/download',
        uploadPath: '/speedtest/upload.php',
        pingPath: '/speedtest/latency.txt',
        network: 'HaaNSirO',
        sponsor: 'HaanSirO Network',
      );

  /// Legacy OpenSpeedTest endpoint (opsional)
  factory TestServer.haansiroLegacy() => const TestServer(
        id: 'haansiro-legacy',
        name: 'HaaNSirO (Legacy)',
        host: 'speed2.haansiro.id',
        location: 'Indonesia',
        country: 'ID',
        latitude: -6.2088,
        longitude: 106.8456,
        isDefault: false,
        scheme: 'https',
        downloadPath: '/downloading',
        uploadPath: '/upload',
        pingPath: '/',
        network: 'HaaNSirO',
        sponsor: 'HaaNSirO',
      );

  static TestServer fromOokla({
    required String id,
    required String sponsor,
    required String host,
    required String location,
    required double lat,
    required double lon,
    required int distance,
    bool isDefault = false,
  }) {
    // Bersihkan host prod.hosts.ooklaserver.net jika ada — tetap pakai host asli dari field host
    final cleanHost = host.contains('.prod.hosts.ooklaserver.net')
        ? host.replaceAll('.prod.hosts.ooklaserver.net', '')
        : host;
    return TestServer(
      id: id,
      name: sponsor,
      host: cleanHost,
      location: location,
      country: 'ID',
      latitude: lat,
      longitude: lon,
      distanceKm: distance,
      isDefault: isDefault,
      scheme: 'http',
      downloadPath: '/speedtest/download',
      uploadPath: '/speedtest/upload.php',
      pingPath: '/speedtest/latency.txt',
      network: sponsor,
      sponsor: sponsor,
    );
  }

  static List<TestServer> catalog() => [
        TestServer.haansiro(),
        TestServer.fromOokla(
          id: '57184',
          sponsor: 'JSN Jaringanku',
          host: 'speedtest-pati.jsn.net.id:8080',
          location: 'Pati',
          lat: -6.7487,
          lon: 111.0379,
          distance: 7,
        ),
        TestServer.fromOokla(
          id: '70985',
          sponsor: 'Global Media Data Prima',
          host: 'speedtest-pati.gmdp.net.id:8080',
          location: 'Pati',
          lat: -6.7487,
          lon: 111.0379,
          distance: 7,
        ),
        TestServer.fromOokla(
          id: '69733',
          sponsor: 'ARRAB NETWORK',
          host: 'speedtest-pati.arrab.id:8080',
          location: 'Pati',
          lat: -6.7487,
          lon: 111.0379,
          distance: 7,
        ),
        TestServer.fromOokla(
          id: '68681',
          sponsor: 'PT Jaringan Internet Tayu',
          host: 'pati.tayu.my.id:8080',
          location: 'Pati',
          lat: -6.7487,
          lon: 111.0379,
          distance: 7,
        ),
        TestServer.fromOokla(
          id: '65329',
          sponsor: 'PerkasaNetwork',
          host: 'speedtest.perkasa.net.id:8080',
          location: 'Pati',
          lat: -6.7487,
          lon: 111.0379,
          distance: 7,
        ),
        TestServer.fromOokla(
          id: '70300',
          sponsor: 'PusatNet',
          host: 'pati.pusatnet.id:8080',
          location: 'Pati',
          lat: -6.7487,
          lon: 111.0379,
          distance: 7,
        ),
        TestServer.fromOokla(
          id: '70063',
          sponsor: 'PT BERKAH MEDIA KUSUMA VISION',
          host: 'speedtest.bmkv.net:8080',
          location: 'Pati',
          lat: -6.7487,
          lon: 111.0379,
          distance: 7,
        ),
        TestServer.fromOokla(
          id: '72845',
          sponsor: 'PT STAR NUSANTARA NETWORK',
          host: 'speedtest.starnus.net:8080',
          location: 'Kab. Pati',
          lat: -6.7450,
          lon: 111.0460,
          distance: 7,
        ),
        TestServer.fromOokla(
          id: '69130',
          sponsor: 'PT Menara Digital Salama',
          host: 'speedtest-kudus.menaracloud.com:8080',
          location: 'Kudus',
          lat: -6.8075,
          lon: 110.8427,
          distance: 12,
        ),
        TestServer.fromOokla(
          id: '68392',
          sponsor: 'GM.NET',
          host: 'speedtest.gmnet.id:8080',
          location: 'Kudus',
          lat: -6.8075,
          lon: 110.8427,
          distance: 12,
        ),
        TestServer.fromOokla(
          id: '68628',
          sponsor: 'ISKNET',
          host: 'speedtest.isknet.id:8080',
          location: 'Kudus',
          lat: -6.8075,
          lon: 110.8427,
          distance: 12,
        ),
        TestServer.fromOokla(
          id: '73027',
          sponsor: 'PT Merdeka Telekomunikasi Center',
          host: 'speedtest-kudus.merdeka.net.id:8080',
          location: 'Kudus',
          lat: -6.8075,
          lon: 110.8427,
          distance: 12,
        ),
        TestServer.fromOokla(
          id: '16143',
          sponsor: 'AN . NET',
          host: 'kudus.an-group.my.id:8080',
          location: 'Kudus',
          lat: -6.8073,
          lon: 110.8414,
          distance: 12,
        ),
        TestServer.fromOokla(
          id: '71558',
          sponsor: 'Eratel',
          host: 'speedtest-kudus.eratelindo.id:8080',
          location: 'Kudus',
          lat: -6.8073,
          lon: 110.8414,
          distance: 12,
        ),
        TestServer.fromOokla(
          id: '74426',
          sponsor: 'PT. Nesta Indo Media Kudus',
          host: 'speedtest.infinityteknik.net:8080',
          location: 'Kudus',
          lat: -6.8073,
          lon: 110.8414,
          distance: 12,
        ),
        TestServer.fromOokla(
          id: '72982',
          sponsor: 'PT Merdeka Telekomunikasi Center',
          host: 'speedtest-jepara.merdeka.net.id:8080',
          location: 'Jepara',
          lat: -6.5805,
          lon: 110.6790,
          distance: 21,
        ),
        TestServer.fromOokla(
          id: '67856',
          sponsor: 'Fahasa Net',
          host: 'speed.fahasatridata.co.id:8080',
          location: 'Jepara',
          lat: -6.5805,
          lon: 110.6790,
          distance: 21,
        ),
        TestServer.fromOokla(
          id: '67570',
          sponsor: 'Internet Coffee',
          host: 'jepara.netcoffee.my.id:8080',
          location: 'Jepara',
          lat: -6.5805,
          lon: 110.6790,
          distance: 21,
        ),
        TestServer.fromOokla(
          id: '72342',
          sponsor: 'UNISNU JEPARA',
          host: 'speedtest.unisnu.ac.id:8080',
          location: 'Jepara',
          lat: -6.5805,
          lon: 110.6790,
          distance: 21,
        ),
        TestServer.fromOokla(
          id: '71935',
          sponsor: 'Lintas Home',
          host: 'jepara.lintasjepara.my.id:8080',
          location: 'Jepara',
          lat: -6.5923,
          lon: 110.6729,
          distance: 21,
        ),
        TestServer.fromOokla(
          id: '69798',
          sponsor: 'DEMAK CENTRAL DATA ONLINE',
          host: 'speedtest-demak.demak.online:8080',
          location: 'Demak',
          lat: -6.8906,
          lon: 110.6434,
          distance: 26,
        ),
        TestServer.fromOokla(
          id: '69928',
          sponsor: 'PT Menara Digital Salama',
          host: 'speedtest-demak.menaracloud.com:8080',
          location: 'Demak',
          lat: -6.8906,
          lon: 110.6434,
          distance: 26,
        ),
        TestServer.fromOokla(
          id: '71987',
          sponsor: 'PT AYODYA DATA INTERNUSA',
          host: 'speedtest.adinetwork.info:8080',
          location: 'Rembang',
          lat: -6.7094,
          lon: 111.3413,
          distance: 26,
        ),
        TestServer.fromOokla(
          id: '73323',
          sponsor: 'PT Merdeka Telekomunikasi Center',
          host: 'speedtest-demak.merdeka.net.id:8080',
          location: 'Demak',
          lat: -6.8922,
          lon: 110.6378,
          distance: 26,
        ),
        TestServer.fromOokla(
          id: '63932',
          sponsor: 'PT Lintas Data Prima',
          host: 'speeddmk.ldp.net.id:8080',
          location: 'Demak',
          lat: -6.8922,
          lon: 110.6378,
          distance: 26,
        ),
        TestServer.fromOokla(
          id: '60447',
          sponsor: 'Linkbit Inovasi Teknologi',
          host: 'krry.speedtest.linkbit.net.id:8080',
          location: 'Godong',
          lat: -7.0279,
          lon: 110.7748,
          distance: 27,
        ),
        TestServer.fromOokla(
          id: '14443',
          sponsor: 'RECONET',
          host: 'speedtest.reconet.co.id:8080',
          location: 'Purwodadi',
          lat: -7.1151,
          lon: 110.9715,
          distance: 30,
        ),
        TestServer.fromOokla(
          id: '70992',
          sponsor: 'High Speed Connection Network',
          host: 'speedtest.hscnet.id:8080',
          location: 'Purwodadi',
          lat: -7.1151,
          lon: 110.9715,
          distance: 30,
        ),
        TestServer.haansiroLegacy(),
      ];

  TestServer copyWith({double? latencyMs, int? distanceKm, String? externalUrl}) =>
      TestServer(
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
        externalUrl: externalUrl ?? this.externalUrl,
        sponsor: sponsor,
      );

  @override
  String toString() => '$name ($location)';
}
