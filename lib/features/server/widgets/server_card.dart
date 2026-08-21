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
    const accent = Color(0xFF00E5A0);
    final latency = server.latencyMs;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? accent : Colors.white12,
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${server.network} · ${server.location}'
          '${server.country.isNotEmpty ? ' · ${server.country}' : ''}\n'
          '${server.host}'
          '${server.latitude != null ? ' · ${server.latitude!.toStringAsFixed(2)}, ${server.longitude!.toStringAsFixed(2)}' : ''}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: latency == null
            ? const Text('—', style: TextStyle(color: Colors.white38))
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
