import 'package:flutter/material.dart';
import '../../../core/widgets/app_button.dart';
import '../models/speed_test_state.dart';

class TestButton extends StatelessWidget {
  final SpeedTestPhase phase;
  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback? onCancel;

  const TestButton({
    super.key,
    required this.phase,
    required this.isRunning,
    required this.onStart,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (isRunning) {
      return AppButton(
        label: 'Batalkan',
        isOutlined: true,
        icon: Icons.stop_rounded,
        onPressed: onCancel,
        width: 200,
      );
    }

    String label;
    IconData icon;
    switch (phase) {
      case SpeedTestPhase.completed:
        label = 'Tes Lagi';
        icon = Icons.refresh_rounded;
        break;
      case SpeedTestPhase.error:
        label = 'Coba Lagi';
        icon = Icons.refresh_rounded;
        break;
      default:
        label = 'Mulai Tes';
        icon = Icons.play_arrow_rounded;
    }

    return AppButton(
      label: label,
      icon: icon,
      onPressed: onStart,
      width: 200,
    );
  }
}
