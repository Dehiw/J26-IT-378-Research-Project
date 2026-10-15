import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/theme.dart';

/// Dark panel with a bar waveform. [amplitudes] are normalised 0-1 values,
/// one per bar; the widget does not depend on how they were captured.
class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.amplitudes,
    this.height = 72,
    this.color = AppColors.accent,
  });

  final List<double> amplitudes;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.panelBlack,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _WaveformPainter(amplitudes: amplitudes, color: color),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.amplitudes, required this.color});

  final List<double> amplitudes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final slot = size.width / amplitudes.length;
    final barWidth = math.max(2.0, slot * 0.5);
    final paint = Paint()..color = color;

    for (var i = 0; i < amplitudes.length; i++) {
      final level = amplitudes[i].clamp(0.0, 1.0);
      final barHeight = math.max(4.0, level * size.height);
      final centerX = slot * i + slot / 2;
      final rect = Rect.fromCenter(
        center: Offset(centerX, size.height / 2),
        width: barWidth,
        height: barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.amplitudes != amplitudes || oldDelegate.color != color;
}
