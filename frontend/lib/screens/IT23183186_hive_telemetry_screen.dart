import 'package:flutter/material.dart';

import 'IT23183186_disease_risk_screen.dart';

/// Uses the authenticated monitoring flow and actual latest hive readings.
class HiveTelemetryScreen extends StatelessWidget {
  final String? location;
  final String? hiveId;
  const HiveTelemetryScreen({super.key, this.location, this.hiveId});
  @override
  Widget build(BuildContext context) =>
      DiseaseRiskScreen(location: location, hiveId: hiveId);
}
