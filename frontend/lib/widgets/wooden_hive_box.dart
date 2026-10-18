import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Renders a wooden beehive box matching the 3D wooden hive illustration in the design mockup:
/// - Telescoping wooden roof with overhang
/// - 3 tiered box supers with wood plank gradients and flight entrance holes
/// - Hive stand with elevated wooden legs
/// - Soft shadow beneath
class WoodenHiveBox extends StatelessWidget {
  final double size;

  const WoodenHiveBox({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WoodenHivePainter(),
      ),
    );
  }
}

class _WoodenHivePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Proportional dimensions
    final roofW = w * 0.72;
    final roofH = h * 0.08;
    final roofLeft = (w - roofW) / 2;
    final roofTop = h * 0.12;

    final boxW = w * 0.64;
    final boxLeft = (w - boxW) / 2;
    final boxTop = roofTop + roofH;
    final boxH = h * 0.54;
    final tierH = boxH / 3.0;

    final legH = h * 0.16;
    final legTop = boxTop + boxH;

    // 1. Soft Shadow underneath the hive
    final shadowPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, legTop + legH),
        width: boxW * 1.05,
        height: h * 0.10,
      ),
      shadowPaint,
    );

    // 2. Stand & Legs
    final standPaint = Paint()
      ..color = const Color(0xFF6E563B) // Dark stained wood for legs
      ..style = PaintingStyle.fill;

    // Left front leg
    final leftLegPath = Path()
      ..moveTo(boxLeft + 2, legTop)
      ..lineTo(boxLeft + 6, legTop)
      ..lineTo(boxLeft + 3, legTop + legH)
      ..lineTo(boxLeft - 2, legTop + legH)
      ..close();
    canvas.drawPath(leftLegPath, standPaint);

    // Right front leg
    final rightLegPath = Path()
      ..moveTo(boxLeft + boxW - 6, legTop)
      ..lineTo(boxLeft + boxW - 2, legTop)
      ..lineTo(boxLeft + boxW + 2, legTop + legH)
      ..lineTo(boxLeft + boxW - 3, legTop + legH)
      ..close();
    canvas.drawPath(rightLegPath, standPaint);

    // Back legs (darker)
    final backStandPaint = Paint()
      ..color = const Color(0xFF4A3824)
      ..style = PaintingStyle.fill;

    final backLeftLeg = Path()
      ..moveTo(boxLeft + 10, legTop)
      ..lineTo(boxLeft + 13, legTop)
      ..lineTo(boxLeft + 11, legTop + legH * 0.85)
      ..lineTo(boxLeft + 8, legTop + legH * 0.85)
      ..close();
    canvas.drawPath(backLeftLeg, backStandPaint);

    final backRightLeg = Path()
      ..moveTo(boxLeft + boxW - 13, legTop)
      ..lineTo(boxLeft + boxW - 10, legTop)
      ..lineTo(boxLeft + boxW - 8, legTop + legH * 0.85)
      ..lineTo(boxLeft + boxW - 11, legTop + legH * 0.85)
      ..close();
    canvas.drawPath(backRightLeg, backStandPaint);

    // Bottom baseboard
    final baseboardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boxLeft - 1, legTop - 2, boxW + 2, 4),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(baseboardRect, standPaint);

    // 3. Hive Box Tiers (3 tiers)
    final tierColors = [
      [const Color(0xFFE5B769), const Color(0xFFC79244)], // Top box
      [const Color(0xFFDCAE60), const Color(0xFFBC853A)], // Mid box
      [const Color(0xFFD3A457), const Color(0xFFB17932)], // Bottom box
    ];

    final strokePaint = Paint()
      ..color = const Color(0xFF8A591C).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final holeFill = Paint()
      ..color = AppColors.hiveDoor
      ..style = PaintingStyle.fill;

    final holeRim = Paint()
      ..color = const Color(0xFF8A591C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < 3; i++) {
      final currentTierTop = boxTop + (i * tierH);
      final tierRect = Rect.fromLTWH(boxLeft, currentTierTop, boxW, tierH - 0.8);

      final woodGrad = LinearGradient(
        colors: tierColors[i],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(tierRect);

      final woodPaint = Paint()..shader = woodGrad;

      final rrect = RRect.fromRectAndRadius(tierRect, const Radius.circular(2.5));
      canvas.drawRRect(rrect, woodPaint);
      canvas.drawRRect(rrect, strokePaint);

      // Subtle horizontal wood grain line
      final grainPaint = Paint()
        ..color = const Color(0xFFFFF2D0).withValues(alpha: 0.28)
        ..strokeWidth = 0.7;
      canvas.drawLine(
        Offset(boxLeft + 3, currentTierTop + tierH * 0.35),
        Offset(boxLeft + boxW - 3, currentTierTop + tierH * 0.35),
        grainPaint,
      );

      // Entrance / ventilation hole in the center of tier
      final holeCenter = Offset(boxLeft + boxW / 2, currentTierTop + tierH * 0.5);
      final holeRadius = (w * 0.03).clamp(1.5, 3.2);
      canvas.drawCircle(holeCenter, holeRadius, holeFill);
      canvas.drawCircle(holeCenter, holeRadius, holeRim);
    }

    // 4. Telescoping Roof / Cover
    final roofRect = Rect.fromLTWH(roofLeft, roofTop, roofW, roofH);
    final roofGrad = const LinearGradient(
      colors: [Color(0xFFF1C878), Color(0xFFBA8738)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(roofRect);

    final roofPaint = Paint()..shader = roofGrad;
    final roofRRect = RRect.fromRectAndRadius(roofRect, const Radius.circular(3));
    canvas.drawRRect(roofRRect, roofPaint);

    final roofRimPaint = Paint()
      ..color = const Color(0xFF7E4F18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawRRect(roofRRect, roofRimPaint);

    // Rim highlight on roof top
    final roofHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(roofLeft + 2, roofTop + 1),
      Offset(roofLeft + roofW - 2, roofTop + 1),
      roofHighlight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
