import 'package:flutter/material.dart';

import '../services/inference_service.dart';
import 'IT23183186_disease_risk_screen.dart';

class DiseaseCheckScreen extends StatelessWidget {
  final InferenceService? inferenceService;
  const DiseaseCheckScreen({super.key, this.inferenceService});
  @override
  Widget build(BuildContext context) =>
      DiseaseRiskScreen(inferenceService: inferenceService);
}
