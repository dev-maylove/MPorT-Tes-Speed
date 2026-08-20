import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/speed_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../models/history_item.dart';

class HistoryCard extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback? onDelete;

  const HistoryCard({super.key, required this.item, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = item.result;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormatter.formatDateTime(r.timestamp),
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 15),
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (r.server.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.server, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                label: 'Ping',
                value: SpeedFormatter.formatLatency(r.ping),
                color: Colors.orange,
              ),
              _Metric(
                label: 'Download',
                value: SpeedFormatter.formatSpeed(r.download),
                color: theme.colorScheme.primary,
              ),
              _Metric(
                label: 'Upload',
                value: SpeedFormatter.formatSpeed(r.upload),
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
