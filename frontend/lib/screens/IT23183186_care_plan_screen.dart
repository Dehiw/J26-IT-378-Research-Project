import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/apiary_model.dart';
import '../services/IT23183186_workspace_api.dart';
import '../utils/theme.dart';
import '../widgets/IT23183186_colony_ui.dart';

class IT23183186CarePlanScreen extends StatefulWidget {
  final HiveModel hive;
  final ColonyWorkspaceApi api;
  const IT23183186CarePlanScreen({
    super.key,
    required this.hive,
    this.api = const ColonyWorkspaceApi(),
  });
  @override
  State<IT23183186CarePlanScreen> createState() => _CarePlanState();
}

class _CarePlanState extends State<IT23183186CarePlanScreen> {
  final _form = GlobalKey<FormState>();
  final _notes = TextEditingController(),
      _product = TextEditingController(),
      _advisor = TextEditingController();
  String _action = 'inspect';
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;
  static const actions = {
    'inspect': 'Inspect the colony',
    'check_food': 'Review food stores',
    'monitor_mites': 'Arrange a mite assessment',
    'verify_sensor': 'Verify a sensor reading',
    'contact_expert': 'Contact a bee-health expert',
    'treatment_record': 'Record expert-directed treatment',
  };
  @override
  void dispose() {
    _notes.dispose();
    _product.dispose();
    _advisor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.plan(widget.hive.id, {
        'action': _action,
        'due_on': DateFormat('yyyy-MM-dd').format(_date),
        'notes': _notes.text.trim(),
        'product': _product.text.trim(),
        'advisor': _advisor.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Care plan was not saved. Check your connection and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(
      title: const Text('Plan hive care'),
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
              const SizedBox(height: 12),
              const ColonyNotice(
                'Make a follow-up plan from your observations. Model findings and weather are preliminary decision support.',
              ),
              if (_error != null) ColonyNotice(_error!, error: true),
              ColonySection(
                title: 'Next action',
                icon: Icons.task_alt,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _action,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Management action',
                    ),
                    items: actions.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _action = v!),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(
                                const Duration(days: 730),
                              ),
                            );
                            if (d != null && mounted) setState(() => _date = d);
                          },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      'Follow up: ${DateFormat('d MMM yyyy').format(_date)}',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_action == 'treatment_record') ...[
                    const ColonyNotice(
                      'Record a plan agreed with a qualified expert. This app does not select a medicine, dose, or legal treatment label.',
                    ),
                    TextFormField(
                      controller: _product,
                      enabled: !_saving,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Expert-advised product / procedure',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter the advised product or procedure.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _advisor,
                      enabled: !_saving,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'Advising expert',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Record who advised the treatment.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _notes,
                    enabled: !_saving,
                    maxLength: 2000,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Plan and follow-up notes',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Add a short note for this plan.'
                        : null,
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(_saving ? 'Saving...' : 'Save care plan'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
