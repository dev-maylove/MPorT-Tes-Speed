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
  final ServerService _service = ServerService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Server'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _service.loadServers,
          ),
        ],
      ),
      body: _service.isLoading
          ? const LoadingView(message: 'Memuat server...')
          : ListView.builder(
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
    );
  }
}
