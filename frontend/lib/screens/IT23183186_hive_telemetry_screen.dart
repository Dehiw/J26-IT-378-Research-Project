import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';

class HiveTelemetryScreen extends StatefulWidget {
  const HiveTelemetryScreen({super.key});
  @override
  State<HiveTelemetryScreen> createState() => _HiveTelemetryScreenState();
}

class _HiveTelemetryScreenState extends State<HiveTelemetryScreen> {
  int _range = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(
        'Hive Telemetry',
        style: _text(18, FontWeight.w800, AppColors.textPrimary),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: () => _showFilters(context),
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rangeSelector(),
            const SizedBox(height: 18),
            Text(
              'Hive #03 Â· Negombo Apiary Â· sample data',
              style: _text(12, FontWeight.w500, AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            const _TelemetryChart(
              title: 'Internal Hive Temperature',
              value: '31.2Â°C',
              range: 'Optimal range: 32â€“36Â°C',
              color: AppColors.accent3,
              points: [.66, .58, .49, .41, .53, .62, .47, .35, .25, .21],
            ),
            const SizedBox(height: 14),
            const _TelemetryChart(
              title: 'Humidity',
              value: '64%',
              range: 'Optimal range: 50â€“60%',
              color: AppColors.blue,
              points: [.31, .38, .53, .46, .62, .71, .55, .66, .81, .75],
            ),
            const SizedBox(height: 14),
            const _TelemetryChart(
              title: 'Comb Weight',
              value: '38.4 kg',
              range: 'Change today: +0.6 kg',
              color: AppColors.accent,
              points: [.82, .69, .52, .37, .29, .43, .65, .4, .27, .22],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.badgeTempBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.accent2,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Values shown are sample readings for the design preview.',
                      style: _text(12, FontWeight.w500, AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _showFilters(context),
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.textPrimary,
      child: const Icon(Icons.add_rounded),
    ),
  );

  Widget _rangeSelector() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _range = i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: _range == i ? AppColors.accent : AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                ['24H', '7D', '30D'][i],
                textAlign: TextAlign.center,
                style: _text(
                  13,
                  FontWeight.w700,
                  _range == i ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  void _showFilters(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgSecondary,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Telemetry filters',
            style: _text(18, FontWeight.w800, AppColors.textPrimary),
          ),
          const SizedBox(height: 14),
          const ListTile(
            leading: Icon(Icons.hive_outlined, color: AppColors.accent),
            title: Text('Hive #03'),
            subtitle: Text('Negombo Apiary'),
          ),
          const ListTile(
            leading: Icon(Icons.sensors_outlined, color: AppColors.accent3),
            title: Text('Sensors'),
            subtitle: Text('Temperature Â· Humidity Â· Weight'),
          ),
        ],
      ),
    ),
  );
}


TextStyle _text(double s, FontWeight w, Color c) =>
    GoogleFonts.inter(fontSize: s, fontWeight: w, color: c);

class _TelemetryChart extends StatelessWidget {
  final String title, value, range;
  final Color color;
  final List<double> points;
  const _TelemetryChart({
    required this.title,
    required this.value,
    required this.range,
    required this.color,
    required this.points,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
    decoration: BoxDecoration(
      color: AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: .05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: _text(15, FontWeight.w700, AppColors.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.panelBlack,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(value, style: _text(13, FontWeight.w700, color)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 118,
          width: double.infinity,
          child: CustomPaint(painter: _ChartPainter(color, points)),
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ['00:00', '06:00', '12:00', '18:00', 'Now']
              .map(
                (e) => Text(
                  e,
                  style: _text(10, FontWeight.w500, AppColors.textSecondary),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(range, style: _text(12, FontWeight.w500, AppColors.textSecondary)),
      ],
    ),
  );
}

class _ChartPainter extends CustomPainter {
  final Color color;
  final List<double> points;
  _ChartPainter(this.color, this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = Offset(
        size.width * i / (points.length - 1),
        size.height * (1 - points[i]),
      );
      if (i == 0)
        path.moveTo(p.dx, p.dy);
      else
        path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      Offset(size.width, size.height * (1 - points.last)),
      4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.color != color || old.points != points;
}
