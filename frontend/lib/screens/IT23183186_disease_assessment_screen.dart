import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/theme.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/main_bottom_nav.dart';
import 'IT23183186_disease_check_screen.dart';
import 'IT23183186_disease_risk_screen.dart';
import 'IT23183186_forage_map_screen.dart';
import 'IT23183186_hive_telemetry_screen.dart';
import 'home_screen.dart';
import 'IT23183186_environment_dashboard_screen.dart';

class DiseaseAssessmentScreen extends StatefulWidget {
  const DiseaseAssessmentScreen({super.key});
  @override State<DiseaseAssessmentScreen> createState() => _DiseaseAssessmentScreenState();
}

class _DiseaseAssessmentScreenState extends State<DiseaseAssessmentScreen> {
  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();
  bool _hasAudio = false;
  bool _ready = false;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file != null && mounted) setState(() { if (_photos.length < 6) _photos.add(file); _refresh(); });
  }
  void _refresh() => _ready = _photos.isNotEmpty && _hasAudio;
  void _recordDemo() => setState(() { _hasAudio = true; _refresh(); });

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)), title: const Text('New Disease Diagnosis')),
    body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
      Text('We combine three data sources for a more accurate colony health assessment.', style: _style(13, FontWeight.w400, AppColors.textSecondary)),
      const SizedBox(height: 18),
      _sensorCard(), const SizedBox(height: 10), _photoCard(), const SizedBox(height: 10), _audioCard(),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: _ready ? () => Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => const DiseaseAssessmentResultScreen())) : null, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Run diagnosis')),
      const SizedBox(height: 8), Text('Add at least one hive photo and an audio sample to continue.', textAlign: TextAlign.center, style: _style(11, FontWeight.w400, AppColors.textSecondary)),
    ])), bottomNavigationBar: MainBottomNav(currentIndex: 1, onTap: (i) => _navigate(context, i)));

  Widget _sensorCard() => _section(icon: Icons.speed_rounded, tint: AppColors.badgeLeafBg, color: AppColors.accent3, title: 'IoT Sensor Data', subtitle: 'Synced automatically Â· Last 48h', child: Row(children: [const Icon(Icons.circle, size: 9, color: AppColors.accent), const SizedBox(width: 8), Text('Sensor patterns ready', style: _style(11, FontWeight.w500, AppColors.textSecondary)), const Spacer(), const Icon(Icons.check_circle, size: 20, color: AppColors.accent3)]));

  Widget _photoCard() => _section(icon: Icons.camera_alt_outlined, tint: AppColors.badgeBeeBg, color: AppColors.accent, title: 'Upload Hive Photos', subtitle: 'Clear photos of comb, bees, and entrance help detect visual symptoms', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [InkWell(onTap: () => ImageSourceSheet.show(context, onCamera: () => _pick(ImageSource.camera), onGallery: () => _pick(ImageSource.gallery)), borderRadius: BorderRadius.circular(14), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(border: Border.all(color: AppColors.border, width: 1.5), borderRadius: BorderRadius.circular(14)), child: Column(children: [const Icon(Icons.add_a_photo_outlined, color: AppColors.accent), const SizedBox(height: 5), Text('Add Photos', style: _style(13, FontWeight.w700, AppColors.textPrimary)), Text('JPG or PNG Â· up to 6 images', style: _style(10, FontWeight.w400, AppColors.textSecondary))]))), if (_photos.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, children: _photos.asMap().entries.map((e) => InputChip(label: Text('Photo ${e.key + 1}'), onDeleted: () => setState(() { _photos.removeAt(e.key); _refresh(); }))).toList())), const SizedBox(height: 8), _status(_photos.isEmpty ? 'No images yet' : '${_photos.length} image${_photos.length == 1 ? '' : 's'} added') ]));

  Widget _audioCard() => _section(icon: Icons.graphic_eq_rounded, tint: AppColors.badgeWaveBg, color: AppColors.blue, title: 'Record or Upload Hive Sound', subtitle: '30 seconds recommended', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [InkWell(onTap: _recordDemo, child: Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accent2.withValues(alpha: .5), width: 2)), child: Icon(_hasAudio ? Icons.check_rounded : Icons.mic_none_rounded, color: AppColors.accent2)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_hasAudio ? 'Audio sample ready' : 'Tap to record sample', style: _style(13, FontWeight.w600, AppColors.textPrimary)), Text('or upload an audio file', style: _style(12, FontWeight.w400, AppColors.blue))]), const Spacer(), IconButton(onPressed: _recordDemo, icon: const Icon(Icons.upload_file_outlined, color: AppColors.textSecondary))])), const SizedBox(height: 7), _status(_hasAudio ? 'Sample captured Â· demo input' : 'No sample yet')]));

  Widget _section({required IconData icon, required Color tint, required Color color, required String title, required String subtitle, required Widget child}) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: .04), blurRadius: 10, offset: const Offset(0, 3))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(color: tint, shape: BoxShape.circle), child: Icon(icon, color: color)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _style(14, FontWeight.w700, AppColors.textPrimary)), const SizedBox(height: 3), Text(subtitle, style: _style(11, FontWeight.w400, AppColors.textSecondary))])), if (title == 'IoT Sensor Data') const Icon(Icons.check_circle, color: AppColors.accent3)]), const SizedBox(height: 12), child]));
  Widget _status(String text) => Row(children: [const Icon(Icons.circle_outlined, size: 13, color: AppColors.textSecondary), const SizedBox(width: 6), Text(text, style: _style(11, FontWeight.w500, AppColors.textSecondary))]);
  TextStyle _style(double s, FontWeight w, Color c) => GoogleFonts.inter(fontSize: s, fontWeight: w, color: c);
  void _navigate(BuildContext c, int i) { final p = switch (i) { 0 => const HomeScreen(), 2 => const ForageMapScreen(), 3 => const HiveTelemetryScreen(), 4 => const EnvironmentDashboardScreen(), _ => const DiseaseCheckScreen() }; Navigator.push(c, MaterialPageRoute<void>(builder: (_) => p)); }
}

class DiseaseAssessmentResultScreen extends StatelessWidget {
  const DiseaseAssessmentResultScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.bgPrimary, appBar: AppBar(leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)), title: const Text('New diagnosis'), bottom: PreferredSize(preferredSize: const Size.fromHeight(24), child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Hive A-02 Â· Kandy apiary', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))))), body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26), decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)), child: Column(children: [Container(width: 72, height: 72, decoration: const BoxDecoration(color: AppColors.badgeLeafBg, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: AppColors.accent3, size: 36)), const SizedBox(height: 16), Text('Assessment ready', style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), const SizedBox(height: 7), Text('One finding needs your attention and one is stable. Review the detail before you open the hive.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: AppColors.textSecondary))])), const SizedBox(height: 16), _done('Reading brood frames', '6 images Â· computer vision'), _done('Listening to the colony', '30 second sample Â· 0â€“800 Hz'), _done('Pulling sensor window', 'Temp, humidity, weight Â· 72 h'), _done('Fusing signals', 'Matched against 14 disease profiles'), const SizedBox(height: 15), FilledButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => const DiseaseRiskScreen())), child: const Text('View assessment')), const SizedBox(height: 8), Text('Demonstration assessment summary.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary))]),), bottomNavigationBar: MainBottomNav(currentIndex: 1, onTap: (i) { if (i == 1) Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DiseaseCheckScreen())); }));
  Widget _done(String title, String subtitle) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.bgSecondary, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: AppColors.badgeLeafBg.withValues(alpha: .7), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.check_rounded, color: AppColors.accent3)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary))])), Text('Done', style: GoogleFonts.inter(fontSize: 10, color: AppColors.accent3))]));
}
