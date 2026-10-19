import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/disease_risk_service.dart';
import '../services/inference_service.dart';
import '../utils/theme.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/result_card.dart';
import 'IT23183186_disease_risk_screen.dart';

class DiseaseAssessmentScreen extends StatefulWidget {
  final InferenceService? inferenceService;
  const DiseaseAssessmentScreen({super.key, this.inferenceService});

  @override
  State<DiseaseAssessmentScreen> createState() =>
      _DiseaseAssessmentScreenState();
}

class _DiseaseAssessmentScreenState extends State<DiseaseAssessmentScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];
  bool _isAnalyzing = false;
  String? _errorMessage;

  Future<void> _pick(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(source: source, imageQuality: 90);
      if (photo == null || !mounted) return;
      setState(() {
        if (_photos.length < 6) {
          _photos.add(photo);
        }
        _errorMessage = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not open the image picker: $error',
        );
      }
    }
  }

  Future<void> _runAssessment() async {
    if (_photos.isEmpty) return;
    final service = widget.inferenceService;
    if (service == null || !service.isReady) {
      setState(() {
        _errorMessage = 'Image uploaded, but inference is unavailable: no trained ONNX model is bundled in assets/models.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });
    try {
      final results = <PredictionResult>[];
      for (final photo in _photos) {
        results.add(await service.predict(await photo.readAsBytes()));
      }
      final classNames = results.first.classScores.keys;
      final meanScores = <String, double>{
        for (final name in classNames)
          name:
              results
                  .map((result) => result.classScores[name] ?? 0)
                  .reduce((a, b) => a + b) /
              results.length,
      };
      final top = meanScores.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      final isOod = results.every((result) => result.isOod);
      final combined = PredictionResult(
        predictedClass: isOod ? 'OOD — Rejected' : top.key,
        confidence: top.value,
        isOod: isOod,
        oodScore: results.map((result) => result.oodScore).reduce(math.max),
        oodThreshold: results.first.oodThreshold,
        classScores: meanScores,
      );
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DiseaseAssessmentResultScreen(
            result: combined,
            imageCount: _photos.length,
            inferenceService: service,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Image inference failed: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelReady = widget.inferenceService?.isReady ?? false;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('New Image Assessment'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Text(
              'Upload clear photos of bees or brood frames for the available colony-health classifier.',
              style: _style(13, FontWeight.w400, AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _infoCard(
              Icons.camera_alt_outlined,
              'Image classifier',
              modelReady ? 'Ready · analyzes each selected image' : 'Model unavailable · upload and preview work, inference needs ONNX weights',
              modelReady ? AppColors.accent3 : AppColors.warning,
            ),
            const SizedBox(height: 9),
            _infoCard(
              Icons.speed_rounded,
              'In-hive sensor readings',
              'Not connected · outdoor WeatherAPI values are not hive sensor data',
              AppColors.textSecondary,
            ),
            const SizedBox(height: 9),
            _infoCard(
              Icons.graphic_eq_rounded,
              'Hive sound',
              'Audio recording and classification are not implemented',
              AppColors.textSecondary,
            ),
            const SizedBox(height: 15),
            InkWell(
              onTap: _photos.length >= 6
                  ? null
                  : () => ImageSourceSheet.show(
                      context,
                      onCamera: () => _pick(ImageSource.camera),
                      onGallery: () => _pick(ImageSource.gallery),
                    ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  border: Border.all(color: AppColors.border, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.accent,
                      size: 26,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose hive photos',
                      style: _style(14, FontWeight.w700, AppColors.textPrimary),
                    ),
                    Text(
                      '${_photos.length}/6 · JPG or PNG',
                      style: _style(
                        11,
                        FontWeight.w400,
                        AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _photoTile(index),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _message(_errorMessage!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _photos.isEmpty || _isAnalyzing
                  ? null
                  : _runAssessment,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics_outlined),
              label: Text(
                _isAnalyzing ? 'Analyzing images…' : 'Run image assessment',
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'The bundled classifier, when provided, has broad Healthy, Stressed, Disease Signs, and Empty/Other classes. It does not identify named diseases.',
              textAlign: TextAlign.center,
              style: _style(11, FontWeight.w400, AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoTile(int index) => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FutureBuilder(
          future: _photos[index].readAsBytes(),
          builder: (context, snapshot) => snapshot.hasData
              ? Image.memory(
                  snapshot.data!,
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 112,
                  height: 112,
                  color: AppColors.bgElevated,
                  child: const Icon(
                    Icons.image_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
        ),
      ),
      Positioned(
        top: 4,
        right: 4,
        child: IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _photos.removeAt(index)),
          icon: const Icon(Icons.close_rounded, size: 15),
        ),
      ),
    ],
  );

  Widget _infoCard(IconData icon, String title, String subtitle, Color color) =>
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _style(13, FontWeight.w700, AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: _style(11, FontWeight.w400, AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _message(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warning.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.warning.withValues(alpha: .35)),
    ),
    child: Text(
      message,
      style: _style(12, FontWeight.w500, AppColors.textPrimary),
    ),
  );
}

class DiseaseAssessmentResultScreen extends StatelessWidget {
  final PredictionResult result;
  final int imageCount;
  final InferenceService? inferenceService;

  const DiseaseAssessmentResultScreen({
    super.key,
    required this.result,
    required this.imageCount,
    this.inferenceService,
  });

  @override
  Widget build(BuildContext context) {
    final assessment = const DiseaseRiskService().assess(result);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Image assessment'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          children: [
            ResultCard(result: result),
            const SizedBox(height: 12),
            Text(
              'Analyzed $imageCount image${imageCount == 1 ? '' : 's'}. ${assessment.explanation}',
              textAlign: TextAlign.center,
              style: _style(12, FontWeight.w500, AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Baseline indicator from the classifier only. It is not a calibrated disease probability or veterinary diagnosis.',
              textAlign: TextAlign.center,
              style: _style(11, FontWeight.w400, AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DiseaseRiskScreen(
                    predictionResult: result,
                    inferenceService: inferenceService,
                  ),
                ),
              ),
              child: const Text('View risk overview'),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _style(double size, FontWeight weight, Color color) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);
