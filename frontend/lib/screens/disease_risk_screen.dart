import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import '../widgets/main_bottom_nav.dart';
import 'disease_assessment_screen.dart';
import 'disease_check_screen.dart';
import 'forage_map_screen.dart';
import 'hive_telemetry_screen.dart';
import 'home_screen.dart';
import 'environment_dashboard_screen.dart';

class DiseaseRiskScreen extends StatelessWidget {
  const DiseaseRiskScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('Disease Risk Overview'), actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.menu_book_outlined))]),
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 22), children: [
      Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9), decoration: _card(), child: Text('●  Hive #03 – Negombo Apiary', style: _style(12, FontWeight.w600, AppColors.textPrimary)))),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.hiveTop, AppColors.accent, AppColors.accent2, AppColors.accent], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(22)), child: Column(children: [Text('Colony Disease Risk Score', style: _style(13, FontWeight.w500, AppColors.textPrimary)), const SizedBox(height: 12), Container(width: 116, height: 116, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.textPrimary, width: 5)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [RichText(text: TextSpan(style: _style(34, FontWeight.w800, AppColors.textPrimary), children: const [TextSpan(text: '42'), TextSpan(text: '/100', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))])), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(18)), child: Text('Monitor closely', style: _style(10, FontWeight.w600, AppColors.bgPrimary)))])), const SizedBox(height: 12), Text('Based on sensor + image + acoustic fusion', textAlign: TextAlign.center, style: _style(11, FontWeight.w500, AppColors.textPrimary)), const SizedBox(height: 8), const Icon(Icons.speed_rounded, size: 20, color: AppColors.textPrimary)])),
      const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Suspected Conditions', style: _style(16, FontWeight.w700, AppColors.textPrimary)), Text('↗ Trend', style: _style(11, FontWeight.w500, AppColors.textSecondary))]),
      const SizedBox(height: 10), _condition('Varroa Destructor', '68% confidence', 'High', AppColors.accent2, Icons.shield_outlined), _condition('Nosema', '34% confidence', 'Medium', AppColors.warning, Icons.shield_outlined), _condition('American Foulbrood', '8% confidence', 'Low', AppColors.accent3, Icons.verified_user_outlined),
      const SizedBox(height: 16), FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DiseaseAssessmentScreen())), icon: const Icon(Icons.document_scanner_outlined), label: const Text('Run new diagnosis')),
      const SizedBox(height: 6), Text('Sample risk estimates for demonstration.', textAlign: TextAlign.center, style: _style(10, FontWeight.w400, AppColors.textSecondary)),
    ])), bottomNavigationBar: MainBottomNav(currentIndex: 1, onTap: (i) => _navigate(context, i)));
}

Widget _condition(String name, String confidence, String level, Color color, IconData icon) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(13), decoration: _card(), child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: _style(14, FontWeight.w700, AppColors.textPrimary)), Text(confidence, style: _style(11, FontWeight.w400, AppColors.textSecondary))])), Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: Text(level, style: _style(11, FontWeight.w600, color)),), const SizedBox(width: 6), const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary)]));
BoxDecoration _card() => BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(17), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: .04), blurRadius: 9, offset: const Offset(0, 3))]);
TextStyle _style(double size, FontWeight weight, Color color) => GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);
void _navigate(BuildContext c, int i) { final page = switch (i) { 0 => const HomeScreen(), 2 => const ForageMapScreen(), 3 => const HiveTelemetryScreen(), 4 => const EnvironmentDashboardScreen(), _ => const DiseaseCheckScreen() }; Navigator.push(c, MaterialPageRoute<void>(builder: (_) => page)); }
