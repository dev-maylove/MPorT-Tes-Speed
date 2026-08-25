import 'package:flutter/material.dart';

import '../../speed_test/models/test_server.dart';

class ServerCard extends StatelessWidget {
  final TestServer server;
  final bool isSelected;
  final VoidCallback onTap;

  const ServerCard({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = cs.primary;
    final latency = server.latencyMs;
    final borderIdle = cs.onSurface.withValues(alpha: 0.12);
    final muted = cs.onSurface.withValues(alpha: 0.54);
    final faint = cs.onSurface.withValues(alpha: 0.38);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? accent : borderIdle,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.28),
                accent.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.map_rounded,
                  color: accent.withValues(alpha: 0.35), size: 22),
              Icon(
                isSelected ? Icons.location_on : Icons.location_on_outlined,
                color: accent,
                size: 18,
              ),
            ],
          ),
        ),
        title: Text(
          server.name,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${server.network} · ${server.location}'
          '${server.country.isNotEmpty ? ' · ${server.country}' : ''}\n'
          '${server.host}'
          '${(server.latitude != null && server.longitude != null) ? ' · ${server.latitude!.toStringAsFixed(2)}, ${server.longitude!.toStringAsFixed(2)}' : ''}',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        trailing: latency == null
            ? Text('—', style: TextStyle(color: faint))
            : Text(
                '${latency.toStringAsFixed(0)} ms',
                style: TextStyle(
                  color: latency < 80
                      ? accent
                      : latency < 150
                          ? Colors.amber
                          : Colors.orangeAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }
}
