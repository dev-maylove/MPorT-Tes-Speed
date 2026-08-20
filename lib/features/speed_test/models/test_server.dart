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
  });

  factory TestServer.haansiro() {
    return const TestServer(
      id: 'haansiro',
      name: 'HaaNSirO',
      host: 'speed2.haansiro.id',
      location: 'Indonesia',
      country: 'Indonesia',
      isDefault: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'location': location,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
        'distanceKm': distanceKm,
        'isDefault': isDefault,
      };

  factory TestServer.fromJson(Map<String, dynamic> json) {
    return TestServer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      location: json['location'] as String? ?? '',
      country: json['country'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: json['distanceKm'] as int?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  @override
  String toString() => '$name ($location)';
}
