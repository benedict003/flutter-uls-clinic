import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../utils/format.dart';
import '../widgets/state_views.dart';

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});
  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  String _status = 'pending';
  late Future<List<dynamic>> _future = ClinicApi.instance.prescriptions();

  void _load(String status) => setState(() {
    _status = status;
    _future = ClinicApi.instance.prescriptions(status: status);
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final s in ['pending', 'dispensed', 'cancelled'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    selected: _status == s,
                    onSelected: (_) => _load(s),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _load(_status),
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return ErrorView(
                      error: snapshot.error!, onRetry: () => _load(_status));
                }
                final rows = snapshot.data ?? const [];
                if (rows.isEmpty) {
                  return EmptyView(message: 'No $_status prescriptions.');
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final rx = rows[i] as Map<String, dynamic>;
                    final items = (rx['items'] as List?) ?? const [];
                    return ExpansionTile(
                      leading: CircleAvatar(child: Text('RX')),
                      title: Text('${rx['patientName']}'),
                      subtitle: Text(
                          'RX-${rx['id']} · ${prettyDate('${rx['visitDate']}')} · '
                              '${items.length} item(s)'),
                      children: [
                        for (final raw in items)
                          ListTile(
                            dense: true,
                            title: Text('${(raw as Map)['medicine']}'),
                            subtitle: Text('${raw['dose']} · ${raw['frequency']} · '
                                '${raw['durationDays']} day(s) · qty ${raw['quantity']}'
                                '${'${raw['instructions'] ?? ''}'.isEmpty ? '' : '\n${raw['instructions']}'}'),
                          ),
                        if (rx['status'] == 'pending')
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      try {
                                        await ClinicApi.instance
                                            .dispense(rx['id'] as int);
                                        _load(_status);
                                      } catch (e) {
                                        if (context.mounted) showError(context, e);
                                      }
                                    },
                                    icon: const Icon(Icons.local_pharmacy_outlined),
                                    label: const Text('Mark as dispensed'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}