import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';

/// Detailed anatomical top-down honeybee illustration matching the user's sketch:
/// - Symmetrical dorsal view with wings spread wide horizontally
/// - Precise wing venation cells (forewings and hindwings)
/// - Segmented thorax with sculpted dorsal plates
/// - Compound eyes, vertex ocelli, and curved antennae
/// - 6 jointed black legs extending gracefully
/// - Striped abdomen with hand-drawn vertical sketch hatching texture and sharp stinger
class BeeIllustration extends StatelessWidget {
  final double size;
  final bool animate;

  const BeeIllustration({
    super.key,
    this.size = 78,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    // Top-down bee aspect ratio: width is ~1.38x height
    final double width = size;
    final double height = size * 0.72;

    Widget bee = SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _TopDownBeePainter(),
      ),
    );

    if (animate) {
      bee = bee
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(begin: 0, end: -3, duration: 1600.ms, curve: Curves.easeInOut)
          .scaleXY(begin: 1.0, end: 1.02, duration: 2000.ms, curve: Curves.easeInOut);
    }

    return bee;
  }
}

class _TopDownBeePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Ink paints
    const Color inkColor = Color(0xFF1E211E); // Crisp sketch black ink

    final strokeThick = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final strokeMid = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final strokeThin = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;

    final strokeLight = Paint()
      ..color = const Color(0xFFFAF7EE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final fillInk = Paint()
      ..color = inkColor
      ..style = PaintingStyle.fill;

    final fillBodyLight = Paint()
      ..color = const Color(0xFFFAF7EE) // Matching cream background
      ..style = PaintingStyle.fill;

    final fillWing = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;

    // ────────────────────────────────────────────────────────────────
    // 1. LEGS (Drawn in background behind wings and body)
    // ────────────────────────────────────────────────────────────────
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(cx, 0);
      canvas.scale(dir, 1.0);

      // Foreleg (front leg beside head)
      final foreleg = Path()
        ..moveTo(w * 0.065, h * 0.28)
        ..lineTo(w * 0.115, h * 0.21)
        ..lineTo(w * 0.135, h * 0.16)
        ..lineTo(w * 0.120, h * 0.13);
      canvas.drawPath(foreleg, strokeThick);

      // Midleg (under wings)
      final midleg = Path()
        ..moveTo(w * 0.10, h * 0.38)
        ..lineTo(w * 0.155, h * 0.44)
        ..lineTo(w * 0.185, h * 0.50)
        ..lineTo(w * 0.195, h * 0.56);
      canvas.drawPath(midleg, strokeThick);

      // Hindleg (along abdomen)
      final hindleg = Path()
        ..moveTo(w * 0.08, h * 0.48)
        ..lineTo(w * 0.135, h * 0.56)
        ..lineTo(w * 0.160, h * 0.66)
        ..lineTo(w * 0.150, h * 0.74);
      canvas.drawPath(hindleg, strokeThick);

      canvas.restore();
    }

    // ────────────────────────────────────────────────────────────────
    // 2. WINGS (Forewings and Hindwings spread wide horizontally)
    // ────────────────────────────────────────────────────────────────
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(cx, 0);
      canvas.scale(dir, 1.0);

      // ── Hindwing (lower smaller wing) ──
      final hindwingPath = Path()
        ..moveTo(w * 0.065, h * 0.38)
        ..cubicTo(w * 0.18, h * 0.36, w * 0.30, h * 0.39, w * 0.34, h * 0.42)
        ..cubicTo(w * 0.32, h * 0.49, w * 0.20, h * 0.51, w * 0.07, h * 0.44)
        ..close();

      canvas.drawPath(hindwingPath, fillWing);
      canvas.drawPath(hindwingPath, strokeMid);

      // Hindwing radiating veins
      canvas.drawLine(Offset(w * 0.07, h * 0.39), Offset(w * 0.31, h * 0.41), strokeThin);
      canvas.drawLine(Offset(w * 0.07, h * 0.41), Offset(w * 0.26, h * 0.47), strokeThin);
      canvas.drawLine(Offset(w * 0.07, h * 0.42), Offset(w * 0.18, h * 0.49), strokeThin);

      // ── Forewing (upper large wing) ──
      final forewingPath = Path()
        ..moveTo(w * 0.06, h * 0.35)
        ..cubicTo(w * 0.15, h * 0.23, w * 0.30, h * 0.16, w * 0.44, h * 0.17)
        ..cubicTo(w * 0.47, h * 0.20, w * 0.45, h * 0.27, w * 0.39, h * 0.33)
        ..cubicTo(w * 0.30, h * 0.37, w * 0.16, h * 0.38, w * 0.06, h * 0.35)
        ..close();

      canvas.drawPath(forewingPath, fillWing);
      canvas.drawPath(forewingPath, strokeThick);

      // Forewing leading edge costal vein (prominent double line)
      final costalVein = Path()
        ..moveTo(w * 0.065, h * 0.34)
        ..cubicTo(w * 0.15, h * 0.24, w * 0.28, h * 0.19, w * 0.40, h * 0.19);
      canvas.drawPath(costalVein, strokeMid);

      // Radial vein and marginal cell
      final marginalCell = Path()
        ..moveTo(w * 0.16, h * 0.27)
        ..cubicTo(w * 0.28, h * 0.23, w * 0.38, h * 0.21, w * 0.42, h * 0.23)
        ..cubicTo(w * 0.39, h * 0.27, w * 0.33, h * 0.28, w * 0.24, h * 0.30);
      canvas.drawPath(marginalCell, strokeThin);

      // Submarginal cell cross-veins
      canvas.drawLine(Offset(w * 0.20, h * 0.28), Offset(w * 0.22, h * 0.36), strokeThin);
      canvas.drawLine(Offset(w * 0.28, h * 0.26), Offset(w * 0.30, h * 0.34), strokeThin);
      canvas.drawLine(Offset(w * 0.35, h * 0.24), Offset(w * 0.37, h * 0.32), strokeThin);

      // Lower longitudinal vein branching to wing margin
      final lowerVein = Path()
        ..moveTo(w * 0.07, h * 0.35)
        ..cubicTo(w * 0.18, h * 0.35, w * 0.28, h * 0.34, w * 0.38, h * 0.32);
      canvas.drawPath(lowerVein, strokeThin);

      canvas.restore();
    }

    // ────────────────────────────────────────────────────────────────
    // 3. ABDOMEN (Oval with stripes, hand-drawn hatching, and stinger)
    // ────────────────────────────────────────────────────────────────
    // Full abdomen outline
    final abdomenOutline = Path()
      ..moveTo(cx, h * 0.45)
      ..cubicTo(cx + w * 0.12, h * 0.45, cx + w * 0.16, h * 0.58, cx + w * 0.13, h * 0.72)
      ..cubicTo(cx + w * 0.10, h * 0.81, cx + w * 0.04, h * 0.87, cx + w * 0.015, h * 0.90)
      ..lineTo(cx, h * 0.94) // Stinger tip
      ..lineTo(cx - w * 0.015, h * 0.90)
      ..cubicTo(cx - w * 0.04, h * 0.87, cx - w * 0.10, h * 0.81, cx - w * 0.13, h * 0.72)
      ..cubicTo(cx - w * 0.16, h * 0.58, cx - w * 0.12, h * 0.45, cx, h * 0.45)
      ..close();

    // Base fill
    canvas.drawPath(abdomenOutline, fillBodyLight);

    // Save layer to clip all abdomen bands cleanly inside the outline
    canvas.save();
    canvas.clipPath(abdomenOutline);

    // Band 1: Upper dark arch
    final topBand = Path()
      ..moveTo(cx - w * 0.14, h * 0.43)
      ..lineTo(cx + w * 0.14, h * 0.43)
      ..lineTo(cx + w * 0.14, h * 0.51)
      ..cubicTo(cx + w * 0.06, h * 0.53, cx - w * 0.06, h * 0.53, cx - w * 0.14, h * 0.51)
      ..close();
    canvas.drawPath(topBand, fillInk);

    // Band 2: Mid dark arch
    final midBand = Path()
      ..moveTo(cx - w * 0.15, h * 0.56)
      ..cubicTo(cx - w * 0.06, h * 0.54, cx + w * 0.06, h * 0.54, cx + w * 0.15, h * 0.56)
      ..lineTo(cx + w * 0.16, h * 0.63)
      ..cubicTo(cx + w * 0.06, h * 0.65, cx - w * 0.06, h * 0.65, cx - w * 0.16, h * 0.63)
      ..close();
    canvas.drawPath(midBand, fillInk);

    // Band 3: Lower solid black abdomen mass & stinger
    final lowerBlackArea = Path()
      ..moveTo(cx - w * 0.16, h * 0.67)
      ..cubicTo(cx - w * 0.06, h * 0.65, cx + w * 0.06, h * 0.65, cx + w * 0.16, h * 0.67)
      ..lineTo(cx + w * 0.16, h * 0.98)
      ..lineTo(cx - w * 0.16, h * 0.98)
      ..close();
    canvas.drawPath(lowerBlackArea, fillInk);

    // Hand-drawn sketch vertical hatching lines between stripes
    // 1) In the first light stripe (h * 0.51 to h * 0.55)
    for (double x = cx - w * 0.11; x <= cx + w * 0.11; x += 1.8) {
      final double dy = (x - cx).abs() * 0.02;
      canvas.drawLine(
        Offset(x, h * 0.51 + dy),
        Offset(x, h * 0.55 + dy),
        strokeThin,
      );
    }

    // 2) In the second light stripe (h * 0.63 to h * 0.67)
    for (double x = cx - w * 0.13; x <= cx + w * 0.13; x += 1.8) {
      final double dy = (x - cx).abs() * 0.02;
      canvas.drawLine(
        Offset(x, h * 0.63 + dy),
        Offset(x, h * 0.67 + dy),
        strokeThin,
      );
    }

    // 3) Pen-drawn feathering on the top border of the bottom black area
    for (double x = cx - w * 0.12; x <= cx + w * 0.12; x += 2.2) {
      final double hLen = ((x.hashCode % 5) + 3).toDouble();
      canvas.drawLine(
        Offset(x, h * 0.66),
        Offset(x, h * 0.66 + hLen),
        strokeLight,
      );
    }

    canvas.restore();

    // Abdomen outer border
    canvas.drawPath(abdomenOutline, strokeThick);

    // ────────────────────────────────────────────────────────────────
    // 4. THORAX (Shield-shaped scutum, dark lateral plates, scutellum)
    // ────────────────────────────────────────────────────────────────
    final thoraxOutline = Path()
      ..moveTo(cx - w * 0.06, h * 0.27)
      ..cubicTo(cx - w * 0.09, h * 0.28, cx - w * 0.12, h * 0.35, cx - w * 0.10, h * 0.42)
      ..cubicTo(cx - w * 0.08, h * 0.46, cx + w * 0.08, h * 0.46, cx + w * 0.10, h * 0.42)
      ..cubicTo(cx + w * 0.12, h * 0.35, cx + w * 0.09, h * 0.28, cx + w * 0.06, h * 0.27)
      ..close();

    canvas.drawPath(thoraxOutline, fillBodyLight);

    // Dark lateral shoulders / wing hinge plates
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(cx, 0);
      canvas.scale(dir, 1.0);

      final shoulder = Path()
        ..moveTo(w * 0.06, h * 0.28)
        ..cubicTo(w * 0.09, h * 0.30, w * 0.11, h * 0.36, w * 0.09, h * 0.42)
        ..cubicTo(w * 0.07, h * 0.42, w * 0.06, h * 0.36, w * 0.05, h * 0.30)
        ..close();
      canvas.drawPath(shoulder, fillInk);

      canvas.restore();
    }

    // Scutum central dome lines
    final scutumPlate = Path()
      ..moveTo(cx - w * 0.05, h * 0.29)
      ..cubicTo(cx - w * 0.06, h * 0.35, cx - w * 0.05, h * 0.40, cx, h * 0.42)
      ..cubicTo(cx + w * 0.05, h * 0.40, cx + w * 0.06, h * 0.35, cx + w * 0.05, h * 0.29)
      ..close();
    canvas.drawPath(scutumPlate, strokeMid);

    // Posterior transverse seam
    canvas.drawLine(Offset(cx - w * 0.07, h * 0.43), Offset(cx + w * 0.07, h * 0.43), strokeMid);

    // Thorax perimeter stroke
    canvas.drawPath(thoraxOutline, strokeThick);

    // ────────────────────────────────────────────────────────────────
    // 5. HEAD, COMPOUND EYES, VERTEX, AND ANTENNAE
    // ────────────────────────────────────────────────────────────────
    // Head base shape
    final headPath = Path()
      ..moveTo(cx - w * 0.045, h * 0.27)
      ..cubicTo(cx - w * 0.065, h * 0.24, cx - w * 0.05, h * 0.19, cx, h * 0.18)
      ..cubicTo(cx + w * 0.05, h * 0.19, cx + w * 0.065, h * 0.24, cx + w * 0.045, h * 0.27)
      ..close();

    canvas.drawPath(headPath, fillBodyLight);
    canvas.drawPath(headPath, strokeThick);

    // Compound eyes (left & right ovals with white highlight crescents)
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(cx, 0);
      canvas.scale(dir, 1.0);

      final eyeRect = Rect.fromCenter(
        center: Offset(w * 0.042, h * 0.23),
        width: w * 0.034,
        height: h * 0.070,
      );

      canvas.save();
      canvas.translate(w * 0.042, h * 0.23);
      canvas.rotate(0.18);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 0.034, height: h * 0.070),
        fillInk,
      );

      // Inner eye highlight crescent
      final eyeGlint = Paint()
        ..color = const Color(0xFFFAF7EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85;

      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: w * 0.024, height: h * 0.052),
        -1.8,
        2.4,
        false,
        eyeGlint,
      );
      canvas.restore();

      // Antenna (curving forward and slightly outward with sharp tip)
      final antenna = Path()
        ..moveTo(w * 0.018, h * 0.18)
        ..cubicTo(w * 0.022, h * 0.13, w * 0.035, h * 0.09, w * 0.045, h * 0.08);
      canvas.drawPath(antenna, strokeThick);

      canvas.restore();
    }

    // Three vertex ocelli dots at center of head
    canvas.drawCircle(Offset(cx, h * 0.195), 0.9, fillInk);
    canvas.drawCircle(Offset(cx - 2.2, h * 0.21), 0.7, fillInk);
    canvas.drawCircle(Offset(cx + 2.2, h * 0.21), 0.7, fillInk);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
