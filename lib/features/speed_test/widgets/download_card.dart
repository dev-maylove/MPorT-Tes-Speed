import 'package:flutter/material.dart';
import '../../../core/utils/speed_formatter.dart';
import '../../../core/widgets/app_card.dart';

class DownloadCard extends StatelessWidget {
  final double downloadMbps;

  const DownloadCard({super.key, required this.downloadMbps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_rounded, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                'DOWNLOAD',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            SpeedFormatter.formatSpeed(downloadMbps),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
