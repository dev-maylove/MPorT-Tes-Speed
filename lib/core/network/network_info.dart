import 'package:connectivity_plus/connectivity_plus.dart';

/// Memeriksa status konektivitas perangkat.
class NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfo({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  Future<String> get connectionType async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return 'Tidak ada koneksi';
    switch (results.first) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Lainnya';
      case ConnectivityResult.none:
        return 'Tidak ada koneksi';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.satellite:
        return 'Satellite';
    }
  }
}
