class SpeedResult {
  final double ping;
  final double jitter;
  final double avgPing;
  final double maxPing;
  final double packetLossPercent;
  final double download;
  final double upload;
  final String server;
  final DateTime timestamp;

  const SpeedResult({
    required this.ping,
    required this.jitter,
    this.avgPing = 0,
    this.maxPing = 0,
    this.packetLossPercent = 0,
    required this.download,
    required this.upload,
    required this.server,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'ping': ping,
        'jitter': jitter,
        'avgPing': avgPing,
        'maxPing': maxPing,
        'packetLossPercent': packetLossPercent,
        'download': download,
        'upload': upload,
        'server': server,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SpeedResult.fromJson(Map<String, dynamic> json) {
    return SpeedResult(
      ping: (json['ping'] as num?)?.toDouble() ?? 0,
      jitter: (json['jitter'] as num?)?.toDouble() ?? 0,
      avgPing: (json['avgPing'] as num?)?.toDouble() ?? 0,
      maxPing: (json['maxPing'] as num?)?.toDouble() ?? 0,
      packetLossPercent:
          (json['packetLossPercent'] as num?)?.toDouble() ?? 0,
      download: (json['download'] as num?)?.toDouble() ?? 0,
      upload: (json['upload'] as num?)?.toDouble() ?? 0,
      server: json['server'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
