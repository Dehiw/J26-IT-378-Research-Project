import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';

/// Detailed honeybee illustration matching the bee art in the header of Colony Health Monitoring.
/// Includes gentle floating/fluttering animation.
class BeeIllustration extends StatelessWidget {
  final double size;
  final bool animate;

  const BeeIllustration({
    super.key,
    this.size = 64,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget bee = SizedBox(
      width: size,
      height: size * 0.85,
      child: CustomPaint(
        painter: _BeePainter(),
      ),
    );

    if (animate) {
      bee = bee
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(begin: 0, end: -4, duration: 1800.ms, curve: Curves.easeInOut)
          .rotate(begin: -0.02, end: 0.02, duration: 2200.ms, curve: Curves.easeInOut);
    }

    return bee;
  }
}

class _BeePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bee is facing slightly to the left / forward
    // 1. Wings (drawn behind body)
    final wingPaint = Paint()
      ..color = const Color(0xFFD6E4EE).withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    final wingBorder = Paint()
      ..color = const Color(0xFF8AA7BE).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final veinPaint = Paint()
      ..color = const Color(0xFF9FB7C9).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    // Upper Wing (Right/Back)
    final backWing = Path()
      ..moveTo(w * 0.48, h * 0.40)
      ..cubicTo(w * 0.52, h * 0.10, w * 0.78, h * 0.02, w * 0.88, h * 0.18)
      ..cubicTo(w * 0.94, h * 0.32, w * 0.76, h * 0.46, w * 0.52, h * 0.45)
      ..close();
    canvas.drawPath(backWing, wingPaint);
    canvas.drawPath(backWing, wingBorder);

    // Back wing veins
    canvas.drawLine(Offset(w * 0.52, h * 0.40), Offset(w * 0.84, h * 0.16), veinPaint);
    canvas.drawLine(Offset(w * 0.64, h * 0.30), Offset(w * 0.78, h * 0.36), veinPaint);

    // Front Wing (Left/Top)
    final frontWing = Path()
      ..moveTo(w * 0.42, h * 0.42)
      ..cubicTo(w * 0.38, h * 0.12, w * 0.68, h * 0.04, w * 0.82, h * 0.22)
      ..cubicTo(w * 0.90, h * 0.36, w * 0.68, h * 0.48, w * 0.46, h * 0.46)
      ..close();
    canvas.drawPath(frontWing, wingPaint);
    canvas.drawPath(frontWing, wingBorder);

    // Front wing veins
    canvas.drawLine(Offset(w * 0.46, h * 0.40), Offset(w * 0.76, h * 0.18), veinPaint);
    canvas.drawLine(Offset(w * 0.58, h * 0.28), Offset(w * 0.72, h * 0.38), veinPaint);

    // 2. Legs
    final legPaint = Paint()
      ..color = const Color(0xFF231B12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // Front legs
    final frontLeg1 = Path()
      ..moveTo(w * 0.34, h * 0.58)
      ..lineTo(w * 0.28, h * 0.74)
      ..lineTo(w * 0.24, h * 0.82);
    canvas.drawPath(frontLeg1, legPaint);

    // Mid leg
    final midLeg = Path()
      ..moveTo(w * 0.44, h * 0.62)
      ..lineTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.38, h * 0.86);
    canvas.drawPath(midLeg, legPaint);

    // Hind leg
    final hindLeg = Path()
      ..moveTo(w * 0.54, h * 0.62)
      ..lineTo(w * 0.58, h * 0.76)
      ..lineTo(w * 0.54, h * 0.88);
    canvas.drawPath(hindLeg, legPaint);

    // 3. Abdomen (Yellow & Black Striped)
    // Save layer to clip stripes neatly inside abdomen oval
    final abdomenRect = Rect.fromCenter(
      center: Offset(w * 0.62, h * 0.56),
      width: w * 0.42,
      height: h * 0.40,
    );

    canvas.save();
    final abdomenPath = Path()
      ..moveTo(w * 0.48, h * 0.44)
      ..cubicTo(w * 0.72, h * 0.36, w * 0.88, h * 0.52, w * 0.82, h * 0.68)
      ..cubicTo(w * 0.76, h * 0.80, w * 0.54, h * 0.76, w * 0.46, h * 0.64)
      ..close();
    canvas.clipPath(abdomenPath);

    // Base golden yellow
    final abdomenBase = Paint()
      ..color = const Color(0xFFE8A825)
      ..style = PaintingStyle.fill;
    canvas.drawRect(abdomenRect, abdomenBase);

    // Dark stripes
    final stripePaint = Paint()
      ..color = const Color(0xFF221A0F)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(w * 0.50, h * 0.30, w * 0.07, h * 0.6), stripePaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.62, h * 0.30, w * 0.08, h * 0.6), stripePaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.74, h * 0.30, w * 0.12, h * 0.6), stripePaint);

    // Stinger tip
    final stingerPaint = Paint()
      ..color = const Color(0xFF1B140B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.83, h * 0.68), 2.5, stingerPaint);

    canvas.restore();

    // 4. Thorax (Furry golden brown)
    final thoraxCenter = Offset(w * 0.40, h * 0.52);
    final thoraxPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFB77926), Color(0xFF4A3111)],
        center: Alignment(-0.2, -0.2),
      ).createShader(Rect.fromCircle(center: thoraxCenter, radius: w * 0.14));

    canvas.drawOval(
      Rect.fromCenter(center: thoraxCenter, width: w * 0.28, height: h * 0.32),
      thoraxPaint,
    );

    // 5. Head
    final headCenter = Offset(w * 0.26, h * 0.50);
    final headPaint = Paint()..color = const Color(0xFF2B1F13);
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: w * 0.18, height: h * 0.24),
      headPaint,
    );

    // Eye (Glossy dark oval)
    final eyePaint = Paint()..color = const Color(0xFF110C07);
    final eyeRect = Rect.fromCenter(
      center: Offset(w * 0.23, h * 0.48),
      width: w * 0.08,
      height: h * 0.14,
    );
    canvas.drawOval(eyeRect, eyePaint);

    // Eye glint
    final glintPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(w * 0.22, h * 0.46), 1.2, glintPaint);

    // 6. Antennae
    final antennaPaint = Paint()
      ..color = const Color(0xFF1F160C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final antenna1 = Path()
      ..moveTo(w * 0.22, h * 0.42)
      ..cubicTo(w * 0.18, h * 0.34, w * 0.12, h * 0.34, w * 0.10, h * 0.38);
    canvas.drawPath(antenna1, antennaPaint);

    final antenna2 = Path()
      ..moveTo(w * 0.24, h * 0.40)
      ..cubicTo(w * 0.22, h * 0.30, w * 0.16, h * 0.26, w * 0.14, h * 0.28);
    canvas.drawPath(antenna2, antennaPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
