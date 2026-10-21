import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_inference_api.dart';
import '../services/apiary_service.dart';
import '../widgets/IT23183186_assessment_card.dart';
import '../utils/theme.dart';
import '../widgets/image_source_sheet.dart';

class ImageModelAnalysisScreen extends StatefulWidget {
  final String? location;
  final String? hiveId;
  const ImageModelAnalysisScreen({super.key, this.location, this.hiveId});

  @override
  State<ImageModelAnalysisScreen> createState() =>
      _ImageModelAnalysisScreenState();
}

class _ImageModelAnalysisScreenState extends State<ImageModelAnalysisScreen> {
  final _picker = ImagePicker();
  final ImageInferenceApi _api = const ImageInferenceApi();
  XFile? _outside;
  XFile? _inside;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  Future<void> _pick({
    required bool outside,
    required ImageSource source,
  }) async {
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 95);
      if (image == null || !mounted) return;
      setState(() {
        if (outside) {
          _outside = image;
        } else {
          _inside = image;
        }
        _error = null;
        _result = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the image picker.');
    }
  }

  void _choose(bool outside) => ImageSourceSheet.show(
    context,
    onCamera: () => _pick(outside: outside, source: ImageSource.camera),
    onGallery: () => _pick(outside: outside, source: ImageSource.gallery),
  );

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _api.analyze(
        outsideImage: _outside,
        insideImage: _inside,
        location:
            widget.location ??
            ApiaryService.instance.selectedApiary?.gpsLocation ??
            ApiaryService.instance.selectedApiary?.locationName,
        hiveId: widget.hiveId,
      );
      if (mounted) setState(() => _result = result);
    } on ImageInferenceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(title: const Text('Image model analysis')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose either image type or both. Each photo is sent only to its matching model.',
          ),
          const SizedBox(height: 14),
          _photoCard(
            title: 'Outside-hive / individual bee',
            subtitle: 'Model A · healthy or Varroa-positive bee crop',
            image: _outside,
            onPick: () => _choose(true),
            onRemove: () => setState(() {
              _outside = null;
              _result = null;
            }),
          ),
          const SizedBox(height: 12),
          _photoCard(
            title: 'Inside-hive frame',
            subtitle: 'Model B · comb and frame structures',
            image: _inside,
            onPick: () => _choose(false),
            onRemove: () => setState(() {
              _inside = null;
              _result = null;
            }),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading || (_outside == null && _inside == null)
                ? null
                : _analyze,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.analytics_outlined),
            label: Text(_loading ? 'Analyzing…' : 'Analyze selected images'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Model scores and detections are image findings, not disease probabilities or confirmed diagnoses. Model B detects structural classes only.',
            style: TextStyle(fontSize: 12),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _message(_error!, isError: true),
          ],
          if (_result != null) ...[
            if (_result!['assessment'] != null)
              ColonyAssessmentCard(
                assessment: Map<String, dynamic>.from(
                  _result!['assessment'] as Map,
                ),
              ),
            const SizedBox(height: 18),
            _resultCard('Outside-hive · Model A', _result!['model_a']),
            const SizedBox(height: 10),
            _resultCard('Inside-hive · Model B', _result!['model_b']),
          ],
        ],
      ),
    ),
  );

  Widget _photoCard({
    required String title,
    required String subtitle,
    required XFile? image,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) => Card(
    color: AppColors.bgSecondary,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (image == null)
            const SizedBox(
              width: 72,
              height: 72,
              child: Icon(Icons.add_a_photo_outlined),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: FutureBuilder<Uint8List>(
                  future: image.readAsBytes(),
                  builder: (_, snapshot) => snapshot.hasData
                      ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                      : const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
                TextButton(
                  onPressed: _loading ? null : onPick,
                  child: Text(image == null ? 'Choose photo' : 'Replace photo'),
                ),
              ],
            ),
          ),
          if (image != null)
            IconButton(
              onPressed: _loading ? null : onRemove,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    ),
  );

  Widget _resultCard(String title, dynamic raw) {
    if (raw == null) return const SizedBox.shrink();
    final result = Map<String, dynamic>.from(raw as Map);
    final status = result['status'] as String? ?? 'complete';
    final details = status == 'complete'
        ? (result['predicted_class'] != null
              ? 'Prediction: ${result['predicted_class']}\nClass scores:\n${(result['class_scores'] as Map).entries.map((e) => '• ${e.key}: ${(e.value as num).toStringAsFixed(3)}').join('\n')}'
              : 'Detections:\n${(result['detections'] as List).isEmpty ? 'No objects detected.' : (result['detections'] as List).map((d) => '${d['class_name']} · ${(d['confidence'] as num).toStringAsFixed(3)} · box ${d['bbox_xyxy']}').join('\n')}')
        : (result['message']?.toString() ?? 'Analysis unavailable.');
    final limitations = (result['limitations'] as List<dynamic>? ?? const [])
        .map((e) => '• $e')
        .join('\n');
    return Card(
      color: AppColors.bgSecondary,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              status == 'complete'
                  ? 'Model ${result['model_version']}'
                  : 'Status: $status',
            ),
            const SizedBox(height: 8),
            SelectableText(details),
            if (limitations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(limitations, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _message(String message, {required bool isError}) => Container(
    padding: const EdgeInsets.all(12),
    color: isError
        ? AppColors.warning.withValues(alpha: .12)
        : AppColors.bgSecondary,
    child: Text(message),
  );
}
