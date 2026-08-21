import 'package:flutter/material.dart';

import '../../../core/widgets/loading_view.dart';
import '../services/server_service.dart';
import '../widgets/server_card.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  final ServerService _service = ServerService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    if (_service.servers.isEmpty || _service.servers.every((s) => s.latencyMs == null)) {
      _service.loadServers(autoNearest: true);
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00E5A0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E17),
        title: const Text('Pilih Server'),
        actions: [
          IconButton(
            tooltip: 'Pilih otomatis (terdekat)',
            icon: const Icon(Icons.my_location_outlined),
            onPressed:
                _service.isProbing ? null : () => _service.selectNearest(force: true),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _service.isLoading
                ? null
                : () => _service.loadServers(autoNearest: true),
          ),
        ],
      ),
      body: _service.isLoading
          ? const LoadingView(message: 'Memuat server...')
          : Column(
              children: [
                if (_service.isProbing)
                  const LinearProgressIndicator(
                    color: accent,
                    backgroundColor: Colors.white10,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Server terdekat (Pati, Kudus, Jepara, …)',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _service.isProbing
                            ? null
                            : () => _service.selectNearest(force: true),
                        icon: const Icon(Icons.speed, size: 18, color: accent),
                        label: const Text('Otomatis', style: TextStyle(color: accent)),
                      ),
                    ],
                  ),
                ),
                if (_service.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _service.error!,
                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _service.servers.length,
                    itemBuilder: (context, index) {
                      final server = _service.servers[index];
                      final isSelected = _service.selected.id == server.id;
                      return ServerCard(
                        server: server,
                        isSelected: isSelected,
                        onTap: () {
                          _service.select(server);
                          Navigator.pop(context, server);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
