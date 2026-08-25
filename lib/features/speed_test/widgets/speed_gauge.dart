import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Neon circular speed gauge (MPorT Go style).
class SpeedGauge extends StatelessWidget {
  final double speedMbps;
  final double maxSpeed;
  final String label;
  final Color? progressColor;

  const SpeedGauge({
    super.key,
    required this.speedMbps,
    this.maxSpeed = 1000,
    this.label = 'Mbps',
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final gold = progressColor ?? const Color(0xFF00E5A0);
    final goldLight = const Color(0xFF5CFFC9);
    final progress = maxSpeed <= 0 ? 0.0 : (speedMbps / maxSpeed).clamp(0.0, 1.0);

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(280, 280),
            painter: _StandaloneGaugePainter(
              progress: progress,
              gold: gold,
              goldLight: goldLight,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speedMbps.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  shadows: [
                    Shadow(color: gold.withValues(alpha: 0.5), blurRadius: 14),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: goldLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'MPorT',
                      style: TextStyle(
                        color: goldLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' GO »»',
                      style: TextStyle(
                        color: gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandaloneGaugePainter extends CustomPainter {
  final double progress;
  final Color gold;
  final Color goldLight;

  _StandaloneGaugePainter({
    required this.progress,
    required this.gold,
    required this.goldLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 6;
    final trackR = outerR - 30;

    canvas.drawCircle(
      center,
      outerR - 1,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF0C1524), Color(0xFF05070E)],
        ).createShader(Rect.fromCircle(center: center, radius: outerR)),
    );

    const tickCount = 60;
    for (var i = 0; i < tickCount; i++) {
      final t = i / tickCount;
      final angle = -math.pi / 2 + t * math.pi * 2;
      final isMajor = i % 5 == 0;
      final purpleBlend =
          (t > 0.5 && t < 0.92) ? ((t - 0.5) / 0.42).clamp(0.0, 1.0) : 0.0;
      final color = Color.lerp(gold, const Color(0xFF9B7BFF), purpleBlend * 0.85)!
          .withValues(alpha: isMajor ? 0.95 : 0.4);
      final inner = outerR - (isMajor ? 20.0 : 12.0);
      canvas.drawLine(
        Offset(center.dx + math.cos(angle) * inner,
            center.dy + math.sin(angle) * inner),
        Offset(center.dx + math.cos(angle) * (outerR - 4),
            center.dy + math.sin(angle) * (outerR - 4)),
        Paint()
          ..color = color
          ..strokeWidth = isMajor ? 2.4 : 1.15
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..shader = SweepGradient(
          colors: [gold, goldLight, const Color(0xFF7B5CFF), gold],
        ).createShader(Rect.fromCircle(center: center, radius: outerR)),
    );

    const arcStart = math.pi * 0.75;
    const arcSweep = math.pi * 1.5;
    final p = progress.clamp(0.0, 1.0);
    final angle = arcStart + arcSweep * p;
    final tip = Offset(
      center.dx + math.cos(angle) * (trackR - 8),
      center.dy + math.sin(angle) * (trackR - 8),
    );
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = gold
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 8, Paint()..color = const Color(0xFF0A1628));
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = gold,
    );
  }

  @override
  bool shouldRepaint(covariant _StandaloneGaugePainter old) =>
      old.progress != progress;
}
