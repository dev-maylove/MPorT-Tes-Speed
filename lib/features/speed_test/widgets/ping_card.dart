import 'package:flutter/material.dart';
import '../../../core/utils/speed_formatter.dart';
import '../../../core/widgets/app_card.dart';

class PingCard extends StatelessWidget {
  final double pingMs;
  final double jitterMs;

  const PingCard({
    super.key,
    required this.pingMs,
    this.jitterMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.network_ping_rounded, size: 18, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                'PING',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            SpeedFormatter.formatLatency(pingMs),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          if (jitterMs > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Jitter ${SpeedFormatter.formatJitter(jitterMs)}',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
