import 'package:flutter/material.dart';
import '../../../core/utils/speed_formatter.dart';
import '../../../core/widgets/app_card.dart';

class UploadCard extends StatelessWidget {
  final double uploadMbps;

  const UploadCard({super.key, required this.uploadMbps});

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
              const Icon(Icons.upload_rounded, size: 18, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                'UPLOAD',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            SpeedFormatter.formatSpeed(uploadMbps),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
