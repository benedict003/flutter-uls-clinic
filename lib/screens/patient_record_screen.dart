import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../utils/format.dart';
import '../widgets/brand.dart';
import '../widgets/state_views.dart';

class PatientRecordScreen extends StatefulWidget {
  const PatientRecordScreen({
    super.key,
    required this.patientId,
    required this.name,
  });

  final String patientId;
  final String name;

  @override
  State<PatientRecordScreen> createState() => _PatientRecordScreenState();
}

class _PatientRecordScreenState extends State<PatientRecordScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() =>
      ClinicApi.instance.patientRecord(widget.patientId);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: clinicAppBar(
          widget.name,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [Tab(text: 'Visits'), Tab(text: 'Profile')],
          ),
        ),
        body: ClinicBackground(
          veil: 0.97,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingView();
              }
              if (snapshot.hasError) {
                return ErrorView(error: snapshot.error!, onRetry: _reload);
              }
              final record = snapshot.data!;
              final visits = (record['visits'] as List?) ?? const [];
              return TabBarView(
                children: [
                  _visitsTab(visits),
                  _profileTab(record),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Visits tab ───────────────────────────────────────────────────────────
  Widget _visitsTab(List<dynamic> visits) {
    if (visits.isEmpty) {
      return const EmptyView(
        message: 'No visits recorded yet.',
        icon: Icons.event_busy_outlined,
      );
    }
    return Stack(
      children: [
        const Positioned.fill(
          child: SealWatermark(opacity: 0.05, size: 280),
        ),
        ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: visits.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) =>
              _VisitTile(visit: visits[i] as Map<String, dynamic>),
        ),
      ],
    );
  }

  // ── Profile tab ──────────────────────────────────────────────────────────
  Widget _profileTab(Map<String, dynamic> record) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Center(
          child: Column(
            children: [
              const BrandImage(BrandImages.seal, height: 76),
              const SizedBox(height: 10),
              Text(widget.name, style: Theme.of(context).textTheme.titleLarge),
              Text(widget.patientId,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _row('Patient ID', record['id']),
                _row('Category', record['category']),
                _row('College', record['college']),
                _row('Course', record['course']),
                _row('Year level', record['year']),
                _row('Visits', (record['visits'] as List?)?.length ?? 0),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _openHistory,
          icon: const Icon(Icons.history),
          label: const Text('Medical history'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openRequirements,
          icon: const Icon(Icons.checklist),
          label: const Text('Laboratory requirements'),
        ),
      ],
    );
  }

  Widget _row(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(dash(value))),
      ],
    ),
  );

  // ── Medical history ──────────────────────────────────────────────────────
  Future<void> _openHistory() async {
    final messenger = ScaffoldMessenger.of(context);
    Map<String, dynamic> history;
    try {
      history = await ClinicApi.instance.patientHistory(widget.patientId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandImage(BrandImages.seal, height: 28),
                  const SizedBox(width: 10),
                  Text('Medical history',
                      style: Theme.of(sheet).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in history.entries)
                      if (entry.value is bool)
                        CheckboxListTile(
                          dense: true,
                          value: entry.value as bool,
                          onChanged: null,
                          title: Text(_humanize(entry.key)),
                        )
                      else
                        ListTile(
                          dense: true,
                          title: Text(_humanize(entry.key)),
                          subtitle: Text(dash(entry.value)),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Laboratory requirements ──────────────────────────────────────────────
  Future<void> _openRequirements() async {
    final messenger = ScaffoldMessenger.of(context);
    Map<String, dynamic> requirements;
    try {
      requirements =
      await ClinicApi.instance.patientRequirements(widget.patientId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;

    final items = (requirements['items'] as List?) ?? const [];

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandImage(BrandImages.seal, height: 28),
                  const SizedBox(width: 10),
                  Text('Laboratory requirements',
                      style: Theme.of(sheet).textTheme.titleLarge),
                ],
              ),
              Text('${requirements['completed']} of '
                  '${requirements['required']} complete'),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final raw in items)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          (raw as Map)['done'] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: raw['done'] == true ? Colors.green : null,
                        ),
                        title: Text('${raw['label']}'),
                        subtitle: Text(
                          raw['applicable'] == false
                              ? 'Not applicable'
                              : prettyDate('${raw['date'] ?? ''}'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _humanize(String key) => key
    .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .replaceAll('_', ' ')
    .split(' ')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit});
  final Map<String, dynamic> visit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = '${visit['status']}';
    final isMissed = status == 'missed';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${visit['visitType']} · ${prettyDate('${visit['visitDate']}')}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isMissed ? theme.colorScheme.error : null,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Complaint: ${dash(visit['complaint'])}',
                style: theme.textTheme.bodySmall),
            Text('Diagnosis: ${dash(visit['diagnosis'])}',
                style: theme.textTheme.bodySmall),
            if ('${visit['bp'] ?? ''}'.isNotEmpty || visit['bmi'] != null)
              Text(
                'BP ${dash(visit['bp'])} · BMI ${dash(visit['bmi'])} '
                    '${visit['bmiStatus'] ?? ''}',
                style: theme.textTheme.bodySmall,
              ),
            if ('${visit['doctorName'] ?? ''}'.isNotEmpty)
              Text('Seen by ${visit['doctorName']}',
                  style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}