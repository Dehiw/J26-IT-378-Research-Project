import 'dart:typed_data';

import '../widgets/bee_image_upload_zone.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_inference_api.dart';
import '../services/apiary_service.dart';
import '../services/environment_analysis_session.dart';
import '../services/environment_fallback.dart';
import '../widgets/environment_source.dart';
import '../widgets/IT23183186_assessment_card.dart';
import '../utils/theme.dart';
import '../widgets/IT23183186_model_results.dart';

class ImageModelAnalysisScreen extends StatefulWidget {
  final XFile? initialOutside;
  final String? location;
  final String? hiveId;
  const ImageModelAnalysisScreen({
    super.key,
    this.location,
    this.hiveId,
    this.initialOutside,
  });

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
  bool _uploadsVisible = true;
  bool _saveResult = true;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialOutside == null
        ? EnvironmentAnalysisSession.get(widget.hiveId)
        : null;
    _outside = widget.initialOutside ?? draft?.bee;
    _inside = draft?.frame;
    _result = draft?.result;
    _uploadsVisible = _result == null;
  }

  @override
  void dispose() {
    EnvironmentAnalysisSession.put(widget.hiveId, _outside, _inside, _result);
    super.dispose();
  }

  Future<void> _pick({
    required bool outside,
    required ImageSource source,
  }) async {
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 95);
      if (image == null || !mounted) return;
      await ImageInferenceApi.validateImage(image);
      if (!mounted || _loading) return;
      setState(() {
        if (outside) {
          _outside = image;
        } else {
          _inside = image;
        }
        _error = null;
        _result = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ImageInferenceException
              ? error.message
              : 'Could not open the image picker.',
        );
      }
    }
  }

  Future<void> _analyze({bool recovering = false}) async {
    setState(() {
      _loading = true;
      _error = null;
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
        saveResult: _saveResult && widget.hiveId != null && !recovering,
      );
      if (mounted) {
        // Keep a successful result for this unchanged upload when a refresh fails.
        for (final key in ['model_a', 'model_b', 'assessment']) {
          final old = _result?[key];
          final incoming = result[key];
          if (old is Map &&
              dataSource(old) != 'demo' &&
              incoming is Map &&
              dataSource(incoming) == 'demo') {
            result[key] = EnvironmentFallback.instance.tagged(old, 'cached');
          }
        }
        setState(() {
          _result = result;
          _uploadsVisible = false;
        });
        EnvironmentAnalysisSession.put(
          widget.hiveId,
          _outside,
          _inside,
          _result,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ImageInferenceException ? error.message : 'Analysis could not complete. Check your image and sign-in, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => EnvironmentRecovery(
    needed: () =>
        _result != null &&
        ['model_a', 'model_b'].any(
          (key) =>
              _result![key] is Map &&
              dataSource(_result![key] as Map) != 'live',
        ),
    onRetry: () async {
      if (!_loading &&
          _result != null &&
          ['model_a', 'model_b'].any(
            (key) =>
                _result![key] is Map &&
                dataSource(_result![key] as Map) != 'live',
          )) {
        await _analyze(recovering: true);
      }
    },
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(title: const Text('Bee Disease Identification')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose either image type or both. Each photo is sent only to its matching model.',
          ),
          const SizedBox(height: 14),
          if (_result != null && !_uploadsVisible)
            OutlinedButton.icon(
              onPressed: () => setState(() => _uploadsVisible = true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Change photos'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final bee = _uploadSection(true);
                final frame = _uploadSection(false);
                if (constraints.maxWidth < 750) {
                  return Column(
                    children: [bee, const SizedBox(height: 16), frame],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: bee),
                    const SizedBox(width: 20),
                    Expanded(child: frame),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          if (widget.hiveId != null)
            CheckboxListTile(
              value: _saveResult,
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _saveResult = v ?? false),
              title: const Text('Save analysis to this hive'),
              subtitle: const Text(
                'Save model findings and combined assessment. Original photos are not retained.',
              ),
              contentPadding: EdgeInsets.zero,
            ),
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
            label: Text(_loading ? 'Analyzing...' : 'Analyze selected images'),
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
            if (_result!['local_saved_record_id'] != null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Saved on this device only. Not saved to the backend.',
                ),
              ),
            if (_result!['saved_record_id'] != null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Backend assessment saved. Demo examples are not included.',
                ),
              ),
            if (_result!['save_error'] != null)
              _message(_result!['save_error'].toString(), isError: true),
            for (final key in ['model_a', 'model_b'])
              if (_result![key] is Map)
                ModelAnalysisResults(
                  key: ValueKey(
                    '$key-${_result![key]['image_identifier'] ?? _result.hashCode}',
                  ),
                  modelKey: key,
                  result: Map<String, dynamic>.from(_result![key] as Map),
                  image: key == 'model_a' ? _outside : _inside,
                ),
            if (_result!['assessment'] != null)
              ColonyAssessmentCard(
                assessment: Map<String, dynamic>.from(
                  _result!['assessment'] as Map,
                ),
              ),
          ],
        ],
      ),
    ),
  );

  Widget _uploadSection(bool outside) {
    final image = outside ? _outside : _inside;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            outside ? 'Individual bee - Model A' : 'Hive frame - Model B',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            outside
                ? 'Healthy / Varroa-positive individual-bee crops'
                : 'Comb and frame structure detection',
          ),
          const SizedBox(height: 12),
          if (image != null) ...[
            FutureBuilder<Uint8List>(
              future: image.readAsBytes(),
              builder: (context, snapshot) => snapshot.hasData
                  ? Image.memory(
                      snapshot.data!,
                      height: 160,
                      fit: BoxFit.contain,
                      semanticLabel:
                          'Selected ${outside ? 'bee' : 'frame'} photo',
                      errorBuilder: (_, error, stack) =>
                          const Text('Preview unavailable.'),
                    )
                  : Text(
                      snapshot.hasError
                          ? 'Preview unavailable.'
                          : 'Loading preview...',
                    ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(image.name, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  tooltip: 'Remove selected ${outside ? 'bee' : 'frame'} photo',
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                          if (outside) {
                            _outside = null;
                          } else {
                            _inside = null;
                          }
                          _result = null;
                        }),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
          BeeImageUploadZone(
            enabled: !_loading,
            onSelected: (file) => setState(() {
              if (outside) {
                _outside = file;
              } else {
                _inside = file;
              }
              _result = null;
              _error = null;
            }),
          ),
          TextButton.icon(
            onPressed: _loading
                ? null
                : () => _pick(outside: outside, source: ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Take a photo'),
          ),
        ],
      ),
    );
  }

  Widget _message(String message, {required bool isError}) => Container(
    padding: const EdgeInsets.all(12),
    color: isError
        ? AppColors.warning.withValues(alpha: .12)
        : AppColors.bgSecondary,
    child: Semantics(liveRegion: true, child: Text(message)),
  );
}
