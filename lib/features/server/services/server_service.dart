import 'package:flutter/foundation.dart';
import '../../speed_test/models/test_server.dart';

class ServerService extends ChangeNotifier {
  List<TestServer> _servers = [];
  TestServer _selected = TestServer.haansiro();
  bool _loading = false;
  String? _error;

  ServerService() {
    loadServers();
  }

  List<TestServer> get servers => List.unmodifiable(_servers);
  TestServer get selected => _selected;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> loadServers() async {
    _loading = true;
    _error = null;
    notifyListeners();

    // Server utama HaaNSirO + cadangan
    _servers = [
      TestServer.haansiro(),
      const TestServer(
        id: 'haansiro-backup',
        name: 'HaaNSirO Backup',
        host: 'speed2.haansiro.id',
        location: 'Indonesia',
        country: 'Indonesia',
      ),
    ];

    _loading = false;
    notifyListeners();
  }

  void select(TestServer server) {
    _selected = server;
    notifyListeners();
  }
}
