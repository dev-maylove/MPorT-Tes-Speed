import 'package:flutter/material.dart';
import '../../speed_test/models/test_server.dart';
import '../../../core/theme/app_colors.dart';

Color _bg(BuildContext c) => AppPalette.of(c).background;
Color _card(BuildContext c) => AppPalette.of(c).card;
Color _text(BuildContext c) => AppPalette.of(c).textPrimary;
Color _muted(BuildContext c) => AppPalette.of(c).textMuted;
Color _sec(BuildContext c) => AppPalette.of(c).textSecondary;
Color _prim(BuildContext c) => AppPalette.of(c).primary;
Color _primL(BuildContext c) => AppPalette.of(c).primaryLight;

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
      color: _card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? accent : _muted(context).withValues(alpha: 0.2),
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
            color: _text(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${server.network} · ${server.location}'
          '${server.country.isNotEmpty ? ' · ${server.country}' : ''}\n'
          '${server.host}'
          '${(server.latitude != null && server.longitude != null) ? ' · ${server.latitude!.toStringAsFixed(2)}, ${server.longitude!.toStringAsFixed(2)}' : ''}',
          style: const TextStyle(color: _text(context)54, fontSize: 12),
        ),
        trailing: latency == null
            ? const Text('—', style: TextStyle(color: _text(context)38))
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
