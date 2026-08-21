class ServerInfo {
  final String id;
  final String name;
  final String host;
  final String location;
  final String country;
  final int? distanceKm;
  final bool isSelected;

  const ServerInfo({
    required this.id,
    required this.name,
    required this.host,
    required this.location,
    this.country = '',
    this.distanceKm,
    this.isSelected = false,
  });

  ServerInfo copyWith({bool? isSelected}) {
    return ServerInfo(
      id: id,
      name: name,
      host: host,
      location: location,
      country: country,
      distanceKm: distanceKm,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
