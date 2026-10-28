import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../widgets/brand.dart';
import '../widgets/state_views.dart';

class _RxDraft {
  _RxDraft()
      : medicine = TextEditingController(),
        dose = TextEditingController(),
        durationDays = TextEditingController(text: '3'),
        quantity = TextEditingController(text: '1'),
        instructions = TextEditingController();

  final TextEditingController medicine;
  final TextEditingController dose;
  final TextEditingController durationDays;
  final TextEditingController quantity;
  final TextEditingController instructions;
  String frequency = ClinicApi.frequencies.first;

  bool get isEmpty =>
      medicine.text.trim().isEmpty &&
          dose.text.trim().isEmpty &&
          instructions.text.trim().isEmpty;

  void dispose() {
    for (final c in [medicine, dose, durationDays, quantity, instructions]) {
      c.dispose();
    }
  }
}

class CompleteVisitScreen extends StatefulWidget {
  const CompleteVisitScreen({super.key, required this.visit});
  final Map<String, dynamic> visit;

  @override
  State<CompleteVisitScreen> createState() => _CompleteVisitScreenState();
}

class _CompleteVisitScreenState extends State<CompleteVisitScreen> {
  final _form = GlobalKey<FormState>();
  final _diagnosis = TextEditingController();
  final _soap = TextEditingController();
  final _actions = TextEditingController();
  final _bpStatus = TextEditingController();
  final _screeningNote = TextEditingController();
  final List<_RxDraft> _items = <_RxDraft>[];

  String _checkupResult = 'Cleared';
  bool _confidential = false;
  bool _busy = false;

  bool get _isCheckup => '${widget.visit['visitType']}' == 'Checkup';

  @override
  void dispose() {
    for (final c in [_diagnosis, _soap, _actions, _bpStatus, _screeningNote]) {
      c.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    try {
      final rx = <Map<String, dynamic>>[];
      for (final item in _items) {
        if (item.isEmpty) continue;
        rx.add({
          'medicine': item.medicine.text.trim(),
          'dose': item.dose.text.trim(),
          'frequency': item.frequency,
          'durationDays': int.tryParse(item.durationDays.text.trim()) ?? 1,
          'quantity': int.tryParse(item.quantity.text.trim()) ?? 1,
          'instructions': item.instructions.text.trim(),
        });
      }

      await ClinicApi.instance.completeVisit(widget.visit['id'] as int, {
        'diagnosis': _diagnosis.text.trim(),
        'soapObjective': _soap.text.trim(),
        'actionsTaken': _actions.text.trim(),
        'confidential': _confidential,
        if (_bpStatus.text.trim().isNotEmpty) 'bpStatus': _bpStatus.text.trim(),
        if (_isCheckup) 'checkupResult': _checkupResult,
        if (_isCheckup && _checkupResult == 'Needs screening')
          'screenedNote': _screeningNote.text.trim(),
        if (rx.isNotEmpty) 'prescription': rx,
      });

      if (!mounted) return;
      navigator.pop(true);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: clinicAppBar('${v['patientName']}'),
      body: ClinicBackground(
        veil: 0.97,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              // ── Patient card ────────────────────────────────────────────
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const BrandImage(BrandImages.emblem, height: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${v['visitType']} · ${v['visitDate']}',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (v['urgent'] == true)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: theme.colorScheme.errorContainer,
                              label: const Text('URGENT',
                                  style: TextStyle(fontSize: 10)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Complaint: ${dash(v['complaint'])}'),
                      Text('Vitals: BP ${dash(v['bp'])} · '
                          'W ${dash(v['weightKg'])} kg · '
                          'H ${dash(v['heightCm'])} cm'),
                      Text('BMI ${dash(v['bmi'])} ${v['bmiStatus'] ?? ''}'),
                      if ('${v['initialDiagnosis'] ?? ''}'.isNotEmpty)
                        Text('Initial dx: ${v['initialDiagnosis']}'),
                      if ('${v['nurseNotes'] ?? ''}'.isNotEmpty)
                        Text('Nurse notes: ${v['nurseNotes']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Examination ─────────────────────────────────────────────
              Text('Examination', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              TextFormField(
                controller: _diagnosis,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Clinical diagnosis *',
                  border: OutlineInputBorder(),
                ),
                validator: (s) =>
                (s == null || s.trim().isEmpty) ? 'Diagnosis is required' : null,
              ),
              TextFormField(
                controller: _soap,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Pertinent P.E. / laboratory findings',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _actions,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Action taken',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bpStatus,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'BP status (Normal, Elevated, …)',
                  border: OutlineInputBorder(),
                ),
              ),

              // ── Checkup result ──────────────────────────────────────────
              if (_isCheckup) ...[
                const SizedBox(height: 4),
                _LabeledDropdown(
                  label: 'Checkup result',
                  value: _checkupResult,
                  items: const ['Cleared', 'Needs screening'],
                  onChanged: (v) =>
                      setState(() => _checkupResult = v ?? 'Cleared'),
                ),
                if (_checkupResult == 'Needs screening')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: _screeningNote,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        labelText: 'Screening note',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
              ],

              SwitchListTile(
                value: _confidential,
                onChanged: (v) => setState(() => _confidential = v),
                title: const Text('Confidential (doctors only)'),
                contentPadding: EdgeInsets.zero,
              ),

              const Divider(height: 28),

              // ── Prescription ────────────────────────────────────────────
              Row(
                children: [
                  Text('Prescription', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _items.length >= 10
                        ? null
                        : () => setState(() => _items.add(_RxDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add medicine'),
                  ),
                ],
              ),
              for (var i = 0; i < _items.length; i++)
                Card(
                  key: ValueKey(_items[i]),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Medicine ${i + 1}',
                                  style: theme.textTheme.labelLarge),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() {
                                _items.removeAt(i).dispose();
                              }),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: _items[i].medicine,
                          decoration: const InputDecoration(
                            labelText: 'Medicine name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _items[i].dose,
                          decoration: const InputDecoration(
                            labelText: 'Dose (e.g. 500 mg)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _LabeledDropdown(
                          label: 'Frequency',
                          value: _items[i].frequency,
                          items: ClinicApi.frequencies,
                          onChanged: (v) => setState(
                                  () => _items[i].frequency = v ?? ClinicApi.frequencies.first),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _items[i].durationDays,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Days',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (s) {
                                  final n = int.tryParse((s ?? '').trim());
                                  if (n == null || n < 1 || n > 365) return '1–365';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _items[i].quantity,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Qty',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (s) {
                                  final n = int.tryParse((s ?? '').trim());
                                  if (n == null || n < 1 || n > 1000) return '1–1000';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _items[i].instructions,
                          maxLength: 300,
                          decoration: const InputDecoration(
                            labelText: 'Instructions',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.task_alt),
                label: Text(_busy ? 'Saving…' : 'Complete visit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Version-proof dropdown: DropdownButton inside an InputDecorator, so it
/// compiles on every Flutter release (no `value`/`initialValue` churn).
class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          isDense: true,
          value: value,
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}