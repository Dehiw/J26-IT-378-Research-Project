import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_inference_api.dart';
import '../utils/theme.dart';

import 'package:intl/intl.dart';

import '../services/environment_fallback.dart';
import 'environment_source.dart';

/// Inference outputs and checkpoint-matched reports are deliberately separate.
class ModelAnalysisResults extends StatefulWidget {
  final String modelKey;
  final Map<String, dynamic> result;
  final XFile? image;
  final Future<Map<String, dynamic>>? reportFuture;
  const ModelAnalysisResults({
    super.key,
    required this.modelKey,
    required this.result,
    this.image,
    this.reportFuture,
  });
  @override
  State<ModelAnalysisResults> createState() => _ModelAnalysisResultsState();
}

class _ModelAnalysisResultsState extends State<ModelAnalysisResults> {
  late Future<Map<String, dynamic>> _report;
  Future<Uint8List>? _image;
  bool _normalized = false;
  int _mobileTab = 0;
  String _reportSource = 'unavailable';
  bool get _bee => widget.modelKey == 'model_a';
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _report =
        widget.reportFuture ??
        const ImageInferenceApi().fetchModelReport(widget.modelKey);
    _image = widget.image?.readAsBytes();
  }

  @override
  void didUpdateWidget(covariant ModelAnalysisResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result ||
        oldWidget.image != widget.image ||
        oldWidget.modelKey != widget.modelKey ||
        oldWidget.reportFuture != widget.reportFuture) {
      _load();
    }
  }

  Widget _title(String text, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        SourceDot(
          source: text == 'Prediction overview'
              ? dataSource(widget.result)
              : _reportSource,
          compact: true,
        ),
        const SizedBox(width: 8),
        Icon(icon, color: AppColors.darkGreen, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _panel(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: .04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: AppColors.bgCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
  Widget _empty(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.bgPrimary,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(color: AppColors.info)),
  );
  String _percent(dynamic n) => n is num && n.isFinite
      ? '${(n * 100).toStringAsFixed(1)}%'
      : 'Not available';
  String _classLabel(dynamic value) => switch (value?.toString()) {
    'healthy' => 'Healthy bee',
    'varroa_positive' => 'Varroa-positive indicator',
    _ => value?.toString() ?? 'Unknown',
  };
  Widget _score(String label, dynamic value) {
    if (value is! num || !value.isFinite) return Text('$label: Not available');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_classLabel(label)}  ${_percent(value)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: '$label model score ${_percent(value)}',
            child: LinearProgressIndicator(
              value: value.toDouble().clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: label.toLowerCase().contains('varroa')
                  ? AppColors.accent
                  : AppColors.darkGreen,
              backgroundColor: AppColors.bgElevated,
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (dataSource(widget.result) == 'demo') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            widget.result['demo_image_asset']?.toString() ??
                'lib/utils/images/05_bees_on_honeycomb.png',
            height: 180,
            width: double.infinity,
            fit: BoxFit.contain,
            semanticLabel: 'Prepared demo example image',
          ),
          const SizedBox(height: 8),
          const Text(
            'Demo example only. This is not an analysis of your uploaded photo.',
            style: TextStyle(
              color: AppColors.info,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return FutureBuilder<Uint8List>(
      future: _image,
      builder: (context, snapshot) {
        if (_image == null) {
          return _empty(
            'Uploaded photo unavailable. Original photos are not retained in history.',
          );
        }
        if (snapshot.hasError) return _empty('Image preview unavailable.');
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            snapshot.data!,
            width: double.infinity,
            height: 220,
            fit: BoxFit.contain,
            semanticLabel:
                'Your uploaded ${_bee ? 'individual bee' : 'hive frame'} photo',
            errorBuilder: (_, error, stack) =>
                _empty('Image preview unavailable.'),
          ),
        );
      },
    );
  }

  String _timestamp(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    return date == null
        ? 'Not recorded'
        : DateFormat('d MMM yyyy, HH:mm:ss').format(date.toLocal());
  }

  Widget _prediction() {
    final result = widget.result;
    final status = result['status'] ?? 'complete';
    final scores = result['class_scores'] as Map?;
    final predicted = result['predicted_class'];
    final detections = result['detections'] as List?;
    return _panel([
      _title('Prediction overview', Icons.image_search_outlined),
      if (dataSource(result) == 'cached')
        const Text(
          'Previous actual result. Waiting for a live refresh.',
          style: TextStyle(color: AppColors.info),
        ),
      _preview(),
      const SizedBox(height: 16),
      Text(
        _bee ? 'Individual bee - Model A' : 'Hive frame - Model B',
        style: const TextStyle(
          color: AppColors.darkGreen,
          fontWeight: FontWeight.w700,
        ),
      ),
      SelectableText('Model: ${displayIdentifier(result['model_version'])}'),
      const SizedBox(height: 12),
      if (status != 'complete')
        _empty(
          'Status: $status. ${result['message'] ?? 'Inference unavailable.'}',
        )
      else ...[
        if (predicted != null) ...[
          Chip(
            label: Text(
              '${dataSource(result) == 'demo' ? 'Example class' : 'Predicted class'}: ${_classLabel(predicted)}',
            ),
            backgroundColor: AppColors.lightGreenCard,
            side: BorderSide.none,
          ),
          Text(
            _percent(result['confidence'] ?? scores?[predicted]),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.darkGreen,
            ),
          ),
          Text(
            dataSource(result) == 'demo' ? 'Example score' : 'Model score',
            style: const TextStyle(color: AppColors.info),
          ),
        ],
        if (scores != null) ...[
          const SizedBox(height: 12),
          const Text(
            'Class scores',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          ...scores.entries.map((e) => _score(e.key.toString(), e.value)),
        ] else if (_bee)
          _empty('Class scores not returned by the model.'),
        if (!_bee) ...[
          Text(
            detections == null
                ? 'Detection count unavailable'
                : '${detections.length} structural detections',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (detections == null)
            _empty('Detection results not returned.')
          else if (detections.isEmpty)
            _empty(
              'No structures detected. This does not establish colony health.',
            )
          else
            ...detections.map(
              (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _score(
                    d['class_name']?.toString() ?? 'Unknown structure',
                    d['confidence'],
                  ),
                  if (d['bbox_xyxy'] != null)
                    Text(
                      'Box (x1, y1, x2, y2): ${d['bbox_xyxy']}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          const Text(
            'Detection scores are per object; this detector does not return a whole-image disease class distribution.',
          ),
        ],
      ],
      const SizedBox(height: 14),
      Text(
        '${dataSource(result) == 'demo' ? 'Example latency' : 'Inference latency'}: ${result['inference_duration_ms'] is num ? '${(result['inference_duration_ms'] as num).toStringAsFixed(1)} ms' : 'Not recorded'}',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.darkGreen,
        ),
      ),
      Text(
        'Analyzed: ${_timestamp(result['inference_timestamp'])}',
        style: const TextStyle(fontSize: 12, color: AppColors.info),
      ),
      const SizedBox(height: 10),
      const Text(
        'Screening output, not a confirmed diagnosis.',
        style: TextStyle(color: AppColors.info, fontWeight: FontWeight.w600),
      ),
      if (_bee)
        const Text(
          'Use individual-bee crops. Whole-hive and brood-frame images are not validated.',
          style: TextStyle(fontSize: 12, color: AppColors.info),
        ),
      ExpansionTile(
        title: const Text('Image details'),
        tilePadding: EdgeInsets.zero,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'File: ${widget.image?.name.isNotEmpty == true ? widget.image!.name : 'Not recorded'}\nImage ID: ${result['image_identifier'] ?? 'Not recorded'}\nDimensions: ${result['image_dimensions'] ?? 'Not recorded'}',
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _metric(String name, String value) => Container(
    width: 165,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.lightGreenCard,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.darkGreen,
          ),
        ),
      ],
    ),
  );
  Widget _performance(Map<String, dynamic> report) {
    final evaluation = report['evaluation'] as Map?;
    final perClass = evaluation?['per_class'] as Map?;
    final detectorMetrics = evaluation?['metrics'] as Map?;
    return _panel([
      _title('Model performance', Icons.bar_chart_outlined),
      if (dataSource(widget.result) == 'demo' && evaluation != null)
        const Text(
          'Evaluation describes the trained checkpoint, not the demo example.',
        ),
      if (evaluation == null) _empty('Test evaluation unavailable'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _metric('Test accuracy', _percent(evaluation?['accuracy'])),
          _metric(
            'Macro F1-score',
            _percent((perClass?['macro avg'] as Map?)?['f1-score']),
          ),
          _metric(
            'Weighted F1-score',
            _percent((perClass?['weighted avg'] as Map?)?['f1-score']),
          ),
          _metric(
            'Test images',
            evaluation?['test_count']?.toString() ?? 'Not available',
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        'Evaluated: ${_timestamp(evaluation?['evaluation_date'] ?? evaluation?['evaluated_at'])}',
      ),
      if (perClass != null)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Class')),
              DataColumn(label: Text('Precision')),
              DataColumn(label: Text('Recall')),
              DataColumn(label: Text('F1')),
              DataColumn(label: Text('Support')),
            ],
            rows: perClass.entries
                .where(
                  (e) =>
                      e.value is Map &&
                      e.key != 'macro avg' &&
                      e.key != 'weighted avg',
                )
                .map((e) {
                  final m = e.value as Map;
                  return DataRow(
                    cells: [
                      DataCell(Text(e.key.toString())),
                      DataCell(Text(_percent(m['precision']))),
                      DataCell(Text(_percent(m['recall']))),
                      DataCell(Text(_percent(m['f1-score']))),
                      DataCell(
                        Text(m['support']?.toString() ?? 'Not available'),
                      ),
                    ],
                  );
                })
                .toList(),
          ),
        ),
      if (!_bee)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Model B is an object detector. Classification accuracy and F1 metrics are unavailable unless explicitly exported; detection metrics are shown separately.',
          ),
        ),
      if (detectorMetrics != null)
        ...detectorMetrics.entries
            .where((e) => e.value is num)
            .map(
              (e) => Text('${e.key}: ${(e.value as num).toStringAsFixed(4)}'),
            ),
    ]);
  }

  Widget _history(Map<String, dynamic> report) {
    final rows = (report['history'] as List? ?? []).whereType<Map>().toList();
    return _panel([
      _title('Training history', Icons.show_chart),
      if (rows.isEmpty)
        _empty(
          'Training history unavailable. ${report['history_help'] ?? 'Save training_history.csv (Model A) or results.csv (Model B) alongside the training run.'}',
        )
      else ...[
        Text(
          '${rows.length} saved epochs. ${report['history_loss_label'] ?? 'Loss'}; epoch order follows the saved log.',
        ),
        _chart(rows, 'train_loss', 'val_loss', 'Loss'),
        if (rows.any(
          (r) => r['train_accuracy'] is num || r['val_accuracy'] is num,
        ))
          _chart(rows, 'train_accuracy', 'val_accuracy', 'Accuracy'),
        ExpansionTile(
          title: const Text('Saved epoch values'),
          tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Epoch')),
                  DataColumn(label: Text('Phase')),
                  DataColumn(label: Text('Training loss')),
                  DataColumn(label: Text('Validation loss')),
                  DataColumn(label: Text('Training accuracy')),
                  DataColumn(label: Text('Validation accuracy')),
                ],
                rows: rows
                    .map(
                      (r) => DataRow(
                        cells: [
                          DataCell(Text('${r['epoch'] ?? 'Unknown'}')),
                          DataCell(Text('${r['phase'] ?? '-'}')),
                          DataCell(
                            Text(
                              r['train_loss'] is num
                                  ? (r['train_loss'] as num).toStringAsFixed(4)
                                  : 'Not logged',
                            ),
                          ),
                          DataCell(
                            Text(
                              r['val_loss'] is num
                                  ? (r['val_loss'] as num).toStringAsFixed(4)
                                  : 'Not logged',
                            ),
                          ),
                          DataCell(Text(_percent(r['train_accuracy']))),
                          DataCell(Text(_percent(r['val_accuracy']))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        const Text(
          'Only logged series are shown. Validation metrics are separate from held-out test performance.',
          style: TextStyle(color: AppColors.info),
        ),
      ],
    ]);
  }

  Widget _chart(List<Map> rows, String train, String validation, String label) {
    List<FlSpot> spots(String field) => [
      for (var i = 0; i < rows.length; i++)
        if (rows[i][field] is num && (rows[i][field] as num).isFinite)
          FlSpot(i.toDouble() + 1, (rows[i][field] as num).toDouble()),
    ];
    final a = spots(train);
    final b = spots(validation);
    if (a.isEmpty && b.isEmpty) {
      return _empty('$label was not saved in this training log.');
    }
    final all = [...a, ...b];
    final minY = math.min(0.0, all.map((p) => p.y).reduce(math.min));
    final maxY = all.map((p) => p.y).reduce(math.max);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          Wrap(
            spacing: 16,
            children: [
              if (a.isNotEmpty) const Text('Green: training'),
              if (b.isNotEmpty) const Text('Gold: validation'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: math.max(2, rows.length).toDouble(),
                minY: minY,
                maxY: label == 'Accuracy'
                    ? 1
                    : math.max(.2, (maxY * 1.1 * 5).ceil() / 5),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('Saved epoch sequence'),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, meta) =>
                          v == 1 ||
                              (v - 1) % math.max(1, (rows.length / 4).ceil()) ==
                                  0
                          ? Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            )
                          : const SizedBox.shrink(),
                      reservedSize: 25,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: label == 'Accuracy'
                          ? .25
                          : math.max(.05, (maxY * 1.1 * 5).ceil() / 20),
                      getTitlesWidget: (v, meta) => Text(
                        label == 'Accuracy'
                            ? '${(v * 100).round()}%'
                            : v.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  if (a.isNotEmpty)
                    LineChartBarData(
                      spots: a,
                      color: AppColors.darkGreen,
                      barWidth: 2,
                      dotData: FlDotData(show: a.length == 1),
                    ),
                  if (b.isNotEmpty)
                    LineChartBarData(
                      spots: b,
                      color: AppColors.accent,
                      barWidth: 2,
                      dotData: FlDotData(show: b.length == 1),
                    ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _matrix(Map<String, dynamic> report) {
    final evaluation = report['evaluation'] as Map?;
    final matrix = evaluation?['confusion_matrix'] as List?;
    final labels = evaluation?['confusion_matrix_labels_order'] as List?;
    final valid =
        matrix != null &&
        labels != null &&
        labels.isNotEmpty &&
        matrix.length == labels.length &&
        matrix.every(
          (r) =>
              r is List &&
              r.length == labels.length &&
              r.every((v) => v is num && v.isFinite && v >= 0),
        );
    return _panel([
      _title('Confusion matrix', Icons.grid_on_outlined),
      if (!valid)
        _empty('No verified test confusion matrix available.')
      else ...[
        const Text('Rows: actual class. Columns: predicted class.'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Normalize each actual-class row'),
          value: _normalized,
          onChanged: (v) => setState(() => _normalized = v),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              const DataColumn(label: Text('Actual / predicted')),
              ...labels.map((l) => DataColumn(label: Text(l.toString()))),
            ],
            rows: [
              for (var i = 0; i < matrix.length; i++)
                DataRow(
                  cells: [
                    DataCell(Text(labels[i].toString())),
                    ...List.generate(labels.length, (j) {
                      final row = (matrix[i] as List).cast<num>();
                      final total = row.fold<num>(0, (a, b) => a + b);
                      return DataCell(
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: AppColors.darkGreen.withValues(
                            alpha:
                                .06 +
                                .45 *
                                    (row[j] /
                                        math.max(
                                          1,
                                          (matrix
                                              .expand((r) => r as List)
                                              .whereType<num>()
                                              .fold<num>(0, math.max)),
                                        )),
                          ),
                          child: Text(
                            _normalized
                                ? (total == 0
                                      ? '0.0%'
                                      : '${(row[j] / total * 100).toStringAsFixed(1)}%')
                                : row[j].toString(),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
            ],
          ),
        ),
      ],
    ]);
  }

  Widget _summary(Map<String, dynamic> report) {
    final summary = report['summary'] as Map? ?? {};
    final evaluation = report['evaluation'] as Map?;
    final limitations = widget.result['limitations'] as List? ?? [];
    String value(dynamic v) => displayIdentifier(v);
    return _panel([
      _title('Evaluation summary', Icons.assignment_outlined),
      const Text(
        'Screening guidance only. Confirm findings by inspection.',
        style: TextStyle(color: AppColors.info, fontWeight: FontWeight.w600),
      ),
      ExpansionTile(
        title: const Text('Training'),
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              'Run: ${value(report['run_id'])}\nCheckpoint: ${value(report['checkpoint_identifier'])}\nDataset: ${value(summary['dataset'])}\nArchitecture: ${value(summary['architecture'])}\nInput dimensions: ${value(summary['input_shape'])}\nClass mapping: ${value(summary['class_mapping'])}\nBatch size: ${value(summary['batch_size'])}\nPreprocessing: ${value(summary['preprocessing'])}',
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: const Text('Validation'),
        tilePadding: EdgeInsets.zero,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              'Best epoch: ${value(summary['best_epoch'])}\nPhase: ${value(summary['best_phase'])}\nValidation outputs: ${value(summary['best_validation'])}\nValidation results are used for selection and are not test metrics.',
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: const Text('Testing'),
        tilePadding: EdgeInsets.zero,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              evaluation == null
                  ? 'Not available \u2014 evaluation results not found. Run the model evaluate.py script against the held-out test split, using this checkpoint. Save its test_evaluation.json in this run/evaluation folder.'
                  : 'Split: ${evaluation['split'] ?? 'Not available'}\nDataset: ${evaluation['dataset'] ?? 'Not available'}\n${evaluation['interpretation_limit'] ?? ''}',
            ),
          ),
        ],
      ),
      ExpansionTile(
        title: const Text('Limitations'),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: false,
        children: [
          if (_bee)
            const Text(
              'The individual-bee model is not validated for whole-hive or brood-frame images. Local field-image performance has not been established.',
            ),
          if (!_bee)
            const Text(
              'Model B detects comb/frame structures. These labels are not disease diagnoses.',
            ),
          ...limitations.map(
            (l) => Align(alignment: Alignment.centerLeft, child: Text('- $l')),
          ),
          const Text(
            'Model scores are not calibrated disease probabilities. Missing evaluation results do not indicate good or poor performance.',
          ),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => EnvironmentRecovery(
    needed: () => _reportSource != 'live',
    onRetry: () async {
      if (_reportSource != 'live' && widget.reportFuture == null && mounted) {
        setState(_load);
      }
    },
    child: _buildPage(context),
  );
  Widget _buildPage(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _bee ? 'Model A analysis results' : 'Model B analysis results',
          style: const TextStyle(
            fontSize: 24,
            color: AppColors.darkGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _report,
          builder: (context, snapshot) {
            final report = snapshot.data ?? <String, dynamic>{};
            _reportSource = snapshot.hasData
                ? dataSource(report)
                : 'unavailable';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (snapshot.hasError)
                  _panel([
                    const Text(
                      'Model reports could not be loaded. Prediction outputs remain available.',
                    ),
                    TextButton.icon(
                      onPressed: () => setState(_load),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry reports'),
                    ),
                  ]),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final left = Column(
                      children: [
                        _prediction(),
                        const SizedBox(height: 16),
                        _matrix(report),
                      ],
                    );
                    final right = Column(
                      children: [
                        _performance(report),
                        const SizedBox(height: 16),
                        _history(report),
                      ],
                    );
                    if (constraints.maxWidth < 900) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < 3; i++)
                                ChoiceChip(
                                  label: Text(
                                    ['Overview', 'Evaluation', 'Training'][i],
                                  ),
                                  selected: _mobileTab == i,
                                  onSelected: (_) =>
                                      setState(() => _mobileTab = i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_mobileTab == 0) _prediction(),
                          if (_mobileTab == 1) ...[
                            _performance(report),
                            const SizedBox(height: 16),
                            _matrix(report),
                          ],
                          if (_mobileTab == 2) ...[
                            _history(report),
                            const SizedBox(height: 16),
                            _summary(report),
                          ],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 20),
                        Expanded(child: right),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (MediaQuery.sizeOf(context).width >= 900) _summary(report),
              ],
            );
          },
        ),
      ],
    ),
  );
}
