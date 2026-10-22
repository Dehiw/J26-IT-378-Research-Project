import 'package:flutter/material.dart';

import '../services/environment_catalog.dart';
import '../services/environment_fallback.dart';
import '../widgets/environment_source.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../services/inference_service.dart';
import '../services/IT23183186_colony_assessment_api.dart';
import '../utils/theme.dart';
import '../widgets/IT23183186_assessment_card.dart';
import 'image_model_analysis_screen.dart';

class DiseaseRiskScreen extends StatefulWidget {
  final PredictionResult? predictionResult;
  final InferenceService? inferenceService;
  final String? location;
  final String? hiveId;
  final ColonyAssessmentApi assessmentApi;
  const DiseaseRiskScreen({
    super.key,
    this.predictionResult,
    this.inferenceService,
    this.location,
    this.hiveId,
    this.assessmentApi = const ColonyAssessmentApi(),
  });
  @override
  State<DiseaseRiskScreen> createState() => _DiseaseRiskScreenState();
}

class _DiseaseRiskScreenState extends State<DiseaseRiskScreen> {
  late final TextEditingController _location;
  List<HiveModel> _hives = [];
  String? _hiveId;
  String? _hiveError;
  Map<String, dynamic>? _snapshot;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final apiary = ApiaryService.instance.selectedApiary;
    _location = TextEditingController(
      text:
          widget.location ?? apiary?.gpsLocation ?? apiary?.locationName ?? '',
    );
    _hiveId = widget.hiveId;
    _loadHives();
    _refresh();
  }

  Future<void> _loadHives() async {
    final apiary = ApiaryService.instance.selectedApiary;
    final apiaryId = isDemoId(widget.hiveId) ? 'demo-apiary-kandy' : apiary?.id;
    if (apiaryId == null) return;
    try {
      final hives = await EnvironmentCatalog.hives(
        ApiaryService.instance,
        apiaryId,
      );
      if (mounted) setState(() => _hives = hives);
    } catch (_) {
      if (mounted) {
        setState(
          () => _hiveError =
              'Could not load hives. Weather monitoring remains available.',
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _snapshot = null;
    });
    try {
      final snapshot = await widget.assessmentApi.fetch(
        location: _location.text,
        hiveId: _hiveId,
      );
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EnvironmentRecovery(
    needed: () =>
        _snapshot != null &&
        (dataSource(_snapshot) != 'live' ||
            dataSource(_snapshot!['sensor'] as Map?) != 'live' ||
            dataSource(_snapshot!['weather'] as Map?) != 'live'),
    onRetry: _refresh,
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    final environment = _snapshot?['environment'] as Map?;
    final sensor = _snapshot?['sensor'] as Map?;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Colony risk and alerts')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Outdoor weather, current hive readings and supported image findings are assessed separately. No disease probability is calculated.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _location,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Apiary GPS or location',
              helperText:
                  'Use the hive location, not a different weather location.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('$_hiveId:${_hives.length}'),
            initialValue: _hives.any((hive) => hive.id == _hiveId)
                ? _hiveId
                : null,
            decoration: const InputDecoration(
              labelText: 'Hive for sensor readings (optional)',
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('No hive selected'),
              ),
              for (final hive in _hives)
                DropdownMenuItem(value: hive.id, child: Text(hive.name)),
            ],
            onChanged: _loading
                ? null
                : (value) {
                    setState(() => _hiveId = value);
                    _refresh();
                  },
          ),
          if (_hiveError != null) Text(_hiveError!),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: Text(
              _loading ? 'Loading evidence...' : 'Refresh monitoring',
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          if (_snapshot != null) ...[
            if (_snapshot!['weather_error'] != null)
              Text('${_snapshot!['weather_error']}'),
            ColonyAssessmentCard(
              assessment: Map<String, dynamic>.from(
                _snapshot!['assessment'] as Map,
              ),
            ),
            if (environment != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SourceDot(source: dataSource(environment)),
                      Text(
                        '${environment['season']} ? ${environment['season_period']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('${environment['regional_context']}'),
                      Text('${environment['environmental_summary']}'),
                      Text(
                        'Bee activity: ${environment['bee_activity']['assessment']}',
                      ),
                      Text(
                        'Colony growth: ${environment['colony_growth']['assessment']}',
                      ),
                      Text(
                        'Food availability: ${environment['food_availability']['assessment']}',
                      ),
                      Text(
                        'Population: ${environment['population']['assessment']}',
                      ),
                    ],
                  ),
                ),
              ),
            SourceDot(
              source: sensor == null ? 'unavailable' : dataSource(sensor),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  sensor == null
                      ? 'Hive sensors: no reading available for the selected hive.'
                      : 'Hive sensor observation: ${sensor['timestamp']}\nTemperature: ${sensor['temperature']} C\nHumidity: ${sensor['humidity']}%\nWeight: ${sensor['weight']} kg\nFreshness: ${_snapshot!['assessment']['evidence']['sensors']}',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loading
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ImageModelAnalysisScreen(
                        location: _location.text,
                        hiveId: _hiveId,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add bee and frame image evidence'),
          ),
        ],
      ),
    );
  }
}
