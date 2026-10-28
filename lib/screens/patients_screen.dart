import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../utils/format.dart';
import '../widgets/state_views.dart';
import 'patient_record_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _search = TextEditingController();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ClinicApi.instance.searchPatients('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = ClinicApi.instance.searchPatients(_search.text));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _reload(),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search name or student ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _reload,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return ErrorView(error: snapshot.error!, onRetry: _reload);
                }
                final rows = snapshot.data ?? const [];
                if (rows.isEmpty) {
                  return const EmptyView(message: 'No patient matched that search.');
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = rows[i] as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(child: Text(initials(p['name']?.toString()))),
                      title: Text('${p['name']}'),
                      subtitle: Text([
                        '${p['id']}',
                        dash(p['college']),
                        dash(p['year']),
                        if (p['lastVisit'] != null) 'last ${prettyDate('${p['lastVisit']}')}',
                      ].join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            PatientRecordScreen(patientId: '${p['id']}', name: '${p['name']}'),
                      )),
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