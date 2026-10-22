import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/apiary_model.dart';
import '../services/IT23183186_workspace_api.dart';
import '../utils/theme.dart';
import '../widgets/IT23183186_colony_ui.dart';

class IT23183186ColonyObservationScreen extends StatefulWidget {
  final HiveModel hive;
  final ColonyWorkspaceApi api;
  const IT23183186ColonyObservationScreen({
    super.key,
    required this.hive,
    this.api = const ColonyWorkspaceApi(),
  });
  @override
  State<IT23183186ColonyObservationScreen> createState() => _ObservationState();
}

class _ObservationState extends State<IT23183186ColonyObservationScreen> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController(),
      _broodFrames = TextEditingController(),
      _population = TextEditingController();
  DateTime _date = DateTime.now();
  final Map<String, String> _values = {
    for (final k in ['queen', 'food_stores', 'brood', 'bee_activity', 'forage'])
      k: 'not_checked',
  };
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _notes.dispose();
    _broodFrames.dispose();
    _population.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_values.values.every((v) => v == 'not_checked') &&
        _notes.text.trim().isEmpty &&
        _broodFrames.text.isEmpty &&
        _population.text.isEmpty) {
      setState(() => _error = 'Record at least one observation before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.observe(widget.hive.id, {
        ..._values,
        'observed_on': DateFormat('yyyy-MM-dd').format(_date),
        'notes': _notes.text.trim(),
        'brood_frames': int.tryParse(_broodFrames.text),
        'estimated_population': int.tryParse(_population.text),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Observation was not saved. Check your connection and retry.';
        });
      }
    }
  }

  Widget _select(String key, String label, Map<String, String> options) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          initialValue: _values[key],
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: {'not_checked': 'Not checked', ...options}.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: _saving ? null : (v) => setState(() => _values[key] = v!),
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(
      title: const Text('Record colony observations'),
      backgroundColor: AppColors.bgPrimary,
    ),
    body: SafeArea(
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.hive.name, style: colonyText(26, FontWeight.w800)),
              const SizedBox(height: 8),
              const ColonyNotice(
                'These are your inspection observations. They remain separate from sensor measurements and model findings.',
              ),
              if (_error != null) ColonyNotice(_error!, error: true),
              ColonySection(
                title: 'Inspection details',
                icon: Icons.fact_check_outlined,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (date != null && mounted) {
                              setState(() => _date = date);
                            }
                          },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(DateFormat('d MMM yyyy').format(_date)),
                  ),
                  const SizedBox(height: 16),
                  _select('queen', 'Queen evidence', {
                    'seen': 'Queen seen',
                    'eggs_seen': 'Eggs or young larvae seen',
                    'not_seen': 'Queen not seen',
                  }),
                  _select('food_stores', 'Food stores', {
                    'light': 'Light',
                    'adequate': 'Adequate',
                    'heavy': 'Heavy',
                  }),
                  _select('brood', 'Brood pattern', {
                    'consistent': 'Consistent',
                    'patchy': 'Patchy',
                    'not_seen': 'No brood seen',
                  }),
                  _select('bee_activity', 'Observed bee activity', {
                    'low': 'Lower than usual',
                    'usual': 'Usual for this hive',
                    'high': 'Higher than usual',
                  }),
                  _select('forage', 'Local flowering / forage', {
                    'observed': 'Observed',
                    'not_observed': 'Not observed',
                  }),
                ],
              ),
              ColonySection(
                title: 'Optional counts & notes',
                icon: Icons.edit_note_outlined,
                children: [
                  TextFormField(
                    controller: _broodFrames,
                    keyboardType: TextInputType.number,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: 'Brood frames',
                      helperText:
                          'Out of ${widget.hive.numFrames} saved frames',
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? null
                        : int.tryParse(v) == null ||
                              int.parse(v) < 0 ||
                              int.parse(v) > widget.hive.numFrames
                        ? 'Enter a valid frame count.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _population,
                    keyboardType: TextInputType.number,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Estimated bee population',
                      helperText:
                          'Your estimate; not a measured colony population',
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? null
                        : int.tryParse(v) == null ||
                              int.parse(v) < 0 ||
                              int.parse(v) > 1000000
                        ? 'Enter a valid estimate.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notes,
                    maxLength: 2000,
                    maxLines: 4,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Inspection notes',
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save observation'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
