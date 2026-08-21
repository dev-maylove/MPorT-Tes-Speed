import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfo({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  Future<String> get connectionType async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return 'none';
    final r = results.first;
    if (r == ConnectivityResult.wifi) return 'wifi';
    if (r == ConnectivityResult.mobile) return 'mobile';
    if (r == ConnectivityResult.ethernet) return 'ethernet';
    if (r == ConnectivityResult.vpn) return 'vpn';
    return 'none';
  }
}
