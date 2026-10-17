import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import '../widgets/main_bottom_nav.dart';
import 'disease_risk_screen.dart';
import 'forage_map_screen.dart';
import 'hive_telemetry_screen.dart';
import 'home_screen.dart';
import 'environment_dashboard_screen.dart';

class DiseaseCheckScreen extends StatelessWidget {
  const DiseaseCheckScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(
      backgroundColor: AppColors.bgPrimary,
      title: const Text('Disease check'),
      actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded))],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text('COLONY HEALTH', style: _text(11, FontWeight.w700, AppColors.textSecondary, spacing: 1.1)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: const [
            _HiveChip(label: 'Hive A-02', active: true),
            _HiveChip(label: 'Hive A-01'),
            _HiveChip(label: 'Hive B-04'),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.panelBlack, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              SizedBox(width: 92, height: 92, child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(child: CircularProgressIndicator(value: .68, strokeWidth: 7, backgroundColor: AppColors.bgSecondary.withValues(alpha: .16), valueColor: const AlwaysStoppedAnimation(AppColors.accent))),
                Column(mainAxisSize: MainAxisSize.min, children: [Text('68', style: _text(28, FontWeight.w800, AppColors.bgPrimary)), Text('of 100', style: _text(10, FontWeight.w500, AppColors.textMuted))]),
              ])),
              const SizedBox(width: 18),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _pill('Monitor · medium risk', AppColors.accent), const SizedBox(height: 10),
                Text('Early infection signs', style: _text(18, FontWeight.w700, AppColors.bgPrimary)),
                const SizedBox(height: 6), Text('Kandy apiary · sample assessment', style: _text(12, FontWeight.w400, AppColors.textMuted)),
              ])),
            ]),
          ),
          const SizedBox(height: 22),
          _heading('Signals fused', trailing: 'LIVE'),
          const SizedBox(height: 10),
          Row(children: const [
            Expanded(child: _SignalCard(icon: Icons.speed_rounded, name: 'Sensors', value: '34.8°C · 72% RH', score: '94')),
            SizedBox(width: 9), Expanded(child: _SignalCard(icon: Icons.camera_alt_outlined, name: 'Vision', value: '6 frames read', score: '88')),
            SizedBox(width: 9), Expanded(child: _SignalCard(icon: Icons.graphic_eq_rounded, name: 'Acoustics', value: '218 Hz mean', score: '91')),
          ]),
          const SizedBox(height: 22), _heading('Findings for Hive A-02'), const SizedBox(height: 10),
          _finding('European Foulbrood', 'Melissococcus plutonius · early stage · Today, 09:12', '76%', AppColors.warning),
          _finding('Varroa mite pressure', 'Varroa destructor · low load · Yesterday, 17:40', '41%', AppColors.accent3),
          const SizedBox(height: 8), Text('Decision support only. This is not a veterinary diagnosis.', style: _text(11, FontWeight.w400, AppColors.textSecondary)),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DiseaseRiskScreen())), icon: const Icon(Icons.assessment_outlined), label: const Text('Open risk overview')),
        ],
      ),
    ),
    bottomNavigationBar: MainBottomNav(currentIndex: 1, onTap: (i) => _navigate(context, i)),
  );
}

void _navigate(BuildContext context, int i) {
  final page = switch (i) { 0 => const HomeScreen(), 2 => const ForageMapScreen(), 3 => const HiveTelemetryScreen(), 4 => const EnvironmentDashboardScreen(), _ => null };
  if (page != null) Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
}

TextStyle _text(double size, FontWeight weight, Color color, {double? spacing}) => GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing);
Widget _heading(String title, {String? trailing}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: _text(16, FontWeight.w700, AppColors.textPrimary)), if (trailing != null) Text(trailing, style: _text(11, FontWeight.w600, AppColors.accent3))]);
Widget _pill(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(20)), child: Text(label, style: _text(11, FontWeight.w600, color)));

class _HiveChip extends StatelessWidget {
  final String label; final bool active;
  const _HiveChip({required this.label, this.active = false});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: active ? AppColors.accent.withValues(alpha: .15) : AppColors.bgSecondary, border: Border.all(color: active ? AppColors.accent : AppColors.border), borderRadius: BorderRadius.circular(22)), child: Text(label, style: _text(12, FontWeight.w600, AppColors.textPrimary)));
}

class _SignalCard extends StatelessWidget {
  final IconData icon; final String name, value, score;
  const _SignalCard({required this.icon, required this.name, required this.value, required this.score});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: AppColors.textPrimary), const SizedBox(height: 9), Text(name, style: _text(12, FontWeight.w700, AppColors.textPrimary)), const SizedBox(height: 4), Text(value, maxLines: 2, style: _text(10, FontWeight.w400, AppColors.textSecondary)), const SizedBox(height: 8), Text(score, style: _text(10, FontWeight.w600, AppColors.textSecondary))]));
}

Widget _finding(String name, String detail, String confidence, Color color) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 5, height: 42, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: _text(13, FontWeight.w700, AppColors.textPrimary)), const SizedBox(height: 4), Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: _text(11, FontWeight.w400, AppColors.textSecondary))])), const SizedBox(width: 8), _pill(confidence, color)]));
