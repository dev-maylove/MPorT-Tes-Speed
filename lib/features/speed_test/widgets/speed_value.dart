import 'package:flutter/material.dart';
import '../../../core/utils/speed_formatter.dart';

class SpeedValue extends StatelessWidget {
  final double value;
  final String unit;
  final double fontSize;
  final Color? color;

  const SpeedValue({
    super.key,
    required this.value,
    this.unit = 'Mbps',
    this.fontSize = 28,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final display = unit == 'ms'
        ? SpeedFormatter.formatLatency(value)
        : SpeedFormatter.formatSpeed(value, unit: unit);

    return Text(
      display,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
