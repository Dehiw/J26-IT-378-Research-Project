import 'package:flutter/material.dart';

import '../services/inference_service.dart';
import 'image_model_analysis_screen.dart';

class DiseaseAssessmentScreen extends StatelessWidget {
  final InferenceService? inferenceService;
  const DiseaseAssessmentScreen({super.key, this.inferenceService});
  @override
  Widget build(BuildContext context) => const ImageModelAnalysisScreen();
}
