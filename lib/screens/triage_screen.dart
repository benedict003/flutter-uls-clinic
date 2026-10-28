import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../utils/format.dart';
import '../widgets/brand.dart';
import '../widgets/state_views.dart';

class TriageScreen extends StatefulWidget {
  const TriageScreen({super.key});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  final _form = GlobalKey<FormState>();
  final _patientId = TextEditingController();
  final _complaint = TextEditingController();
  final _bp = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _pulse = TextEditingController();
  final _temperature = TextEditingController();
  final _initialDiagnosis = TextEditingController();
  final _nurseNotes = TextEditingController();
  final _labSource = TextEditingController();

  String _visitType = 'Consultation';
  late String _visitDate = ClinicApi.instance.todayIso;
  bool _urgent = false;
  bool _busy = false;

  bool get _isConsultation => _visitType == 'Consultation';

  @override
  void dispose() {
    for (final c in [
      _patientId, _complaint, _bp, _weight, _height, _pulse,
      _temperature, _initialDiagnosis, _nurseNotes, _labSource,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPatient() async {
    final chosen = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _PatientPicker(),
    );
    if (chosen != null) {
      _patientId.text = '${chosen['id']}';
      setState(() {});
    }
  }

  Future<void> _pickDate() async {
    final parts = _visitDate.split('-').map(int.parse).toList();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(parts[0], parts[1], parts[2]),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _visitDate = isoDate(picked));
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ClinicApi.instance.triage({
        'patientId': _patientId.text.trim(),
        'visitType': _visitType,
        'visitDate': _visitDate,
        'complaint': _complaint.text.trim(),
        if (_bp.text.trim().isNotEmpty) 'bp': _bp.text.trim(),
        if (_weight.text.trim().isNotEmpty)
          'weight': double.parse(_weight.text.trim()),
        if (_height.text.trim().isNotEmpty)
          'height': double.parse(_height.text.trim()),
        if (_pulse.text.trim().isNotEmpty)
          'pulseRate': int.parse(_pulse.text.trim()),
        if (_temperature.text.trim().isNotEmpty)
          'temperature': double.parse(_temperature.text.trim()),
        'initialDiagnosis': _initialDiagnosis.text.trim(),
        'nurseNotes': _nurseNotes.text.trim(),
        'labSourceName': _labSource.text.trim(),
        'urgent': _urgent,
      });

      messenger.showSnackBar(const SnackBar(
        content: Text('Triage recorded — the patient is in the doctor queue.'),
      ));

      _complaint.clear();
      _bp.clear();
      _weight.clear();
      _height.clear();
      _pulse.clear();
      _temperature.clear();
      _initialDiagnosis.clear();
      _nurseNotes.clear();
      _labSource.clear();
      _patientId.clear();
      if (mounted) setState(() => _urgent = false);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const BrandBanner(
            title: 'New triage',
            subtitle: 'Record vitals for the doctor queue',
            imageHeight: 34,
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextFormField(
                    controller: _patientId,
                    readOnly: true,
                    onTap: _pickPatient,
                    decoration: const InputDecoration(
                      labelText: 'Patient',
                      hintText: 'Tap to search',
                      prefixIcon: Icon(Icons.person_search),
                      border: OutlineInputBorder(),
                    ),
                    validator: (_) =>
                    _patientId.text.trim().isEmpty ? 'Choose a patient' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _visitType,
                    decoration: const InputDecoration(
                      labelText: 'Visit type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Consultation', child: Text('Consultation')),
                      DropdownMenuItem(value: 'Checkup', child: Text('Checkup')),
                    ],
                    onChanged: (v) =>
                        setState(() => _visitType = v ?? 'Consultation'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event),
                      label: Text('Visit date: ${prettyDate(_visitDate)}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _complaint,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText:
                      _isConsultation ? 'Complaint *' : 'Complaint',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (_) =>
                    _isConsultation && _complaint.text.trim().isEmpty
                        ? 'Complaint is required for a consultation'
                        : null,
                  ),
                  TextFormField(
                    controller: _bp,
                    decoration: InputDecoration(
                      labelText: _isConsultation
                          ? 'Blood pressure * (e.g. 120/80)'
                          : 'Blood pressure (optional)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) {
                        return _isConsultation ? 'Blood pressure is required' : null;
                      }
                      if (!RegExp(r'^\d{2,3}/\d{2,3}$').hasMatch(t)) {
                        return 'Use the form 120/80';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _weight,
                          keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: _isConsultation ? 'Weight kg *' : 'Weight kg',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) {
                              return _isConsultation ? 'Required' : null;
                            }
                            final n = double.tryParse(t);
                            if (n == null || n < 1 || n > 500) return '1–500';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _height,
                          keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: _isConsultation ? 'Height cm *' : 'Height cm',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) {
                              return _isConsultation ? 'Required' : null;
                            }
                            final n = double.tryParse(t);
                            if (n == null || n < 30 || n > 300) return '30–300';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pulse,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Pulse rate',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null;
                            final n = int.tryParse(t);
                            if (n == null || n < 20 || n > 250) return '20–250';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _temperature,
                          keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Temp °C',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null;
                            final n = double.tryParse(t);
                            if (n == null || n < 30 || n > 45) return '30–45';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _initialDiagnosis,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Initial diagnosis',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  TextFormField(
                    controller: _nurseNotes,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Nurse notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  TextFormField(
                    controller: _labSource,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Outside laboratory (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    value: _urgent,
                    onChanged: (v) => setState(() => _urgent = v),
                    title: const Text('Urgent'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.save_outlined),
            label: Text(_busy ? 'Saving…' : 'Record triage'),
          ),
        ],
      ),
    );
  }
}

class _PatientPicker extends StatefulWidget {
  const _PatientPicker();

  @override
  State<_PatientPicker> createState() => _PatientPickerState();
}

class _PatientPickerState extends State<_PatientPicker> {
  final _search = TextEditingController();
  late Future<List<dynamic>> _future = ClinicApi.instance.searchPatients('');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: 500,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  onSubmitted: (v) => setState(
                          () => _future = ClinicApi.instance.searchPatients(v)),
                  decoration: const InputDecoration(
                    hintText: 'Search name or ID',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingView();
                    }
                    if (snapshot.hasError) {
                      return ErrorView(error: snapshot.error!);
                    }
                    final rows = snapshot.data ?? const [];
                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = rows[i] as Map<String, dynamic>;
                        return ListTile(
                          leading: ClinicAvatar(label: p['name']?.toString()),
                          title: Text('${p['name']}'),
                          subtitle: Text('${p['id']} · ${dash(p['college'])}'),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}