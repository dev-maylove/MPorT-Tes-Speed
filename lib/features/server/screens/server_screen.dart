import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_footer.dart';
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
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Select Server'),
        actions: [
          IconButton(
            tooltip: 'Auto-select (nearest)',
            icon: Icon(Icons.my_location_outlined),
            onPressed:
                _service.isProbing ? null : () => _service.selectNearest(force: true),
          ),
          IconButton(
            tooltip: 'Reload',
            icon: Icon(Icons.refresh_rounded),
            onPressed: _service.isLoading
                ? null
                : () => _service.loadServers(autoNearest: true),
          ),
        ],
      ),
      body: _service.isLoading
          ? LoadingView(message: 'Loading servers...')
          : Column(
              children: [
                if (_service.isProbing)
                  LinearProgressIndicator(
                    color: accent,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nearest servers (Pati, Kudus, Jepara, …)',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _service.isProbing
                            ? null
                            : () => _service.selectNearest(force: true),
                        icon: Icon(Icons.speed, size: 18, color: accent),
                        label: Text('Auto', style: TextStyle(color: accent)),
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
                    itemCount: _service.servers.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _service.servers.length) {
                        return const AppFooter();
                      }
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
