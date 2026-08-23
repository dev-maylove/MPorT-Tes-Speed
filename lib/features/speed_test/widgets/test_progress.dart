import 'package:flutter/material.dart';

import '../models/speed_test_state.dart';

class TestProgress extends StatelessWidget {
  final SpeedTestPhase phase;

  const TestProgress({super.key, required this.phase});

  String get _label {
    switch (phase) {
      case SpeedTestPhase.ping:
        return 'Measuring Ping...';
      case SpeedTestPhase.download:
        return 'Measuring Download...';
      case SpeedTestPhase.upload:
        return 'Measuring Upload...';
      case SpeedTestPhase.completed:
        return 'Completed';
      case SpeedTestPhase.error:
        return 'An error occurred';
      case SpeedTestPhase.idle:
        return 'Ready to test';
    }
  }

  int get _step {
    switch (phase) {
      case SpeedTestPhase.ping:
        return 1;
      case SpeedTestPhase.download:
        return 2;
      case SpeedTestPhase.upload:
        return 3;
      case SpeedTestPhase.completed:
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = phase != SpeedTestPhase.idle &&
        phase != SpeedTestPhase.completed &&
        phase != SpeedTestPhase.error;

    if (!isActive && phase == SpeedTestPhase.idle) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          _label,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isDone = index < _step;
            final isCurrent = index == _step && isActive;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isCurrent ? 24 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: isDone || isCurrent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5),
              ),
            );
          }),
        ),
      ],
    );
  }
}
