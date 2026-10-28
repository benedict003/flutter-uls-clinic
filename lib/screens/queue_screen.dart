import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../utils/format.dart';
import '../widgets/state_views.dart';
import 'complete_visit_screen.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});
  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  late Future<Map<String, dynamic>> _future = ClinicApi.instance.queue();

  void _reload() => setState(() => _future = ClinicApi.instance.queue());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!, onRetry: _reload);
          }
          final visits = (snapshot.data!['visits'] as List?) ?? const [];
          final earlier = (snapshot.data!['didNotProceed'] as List?) ?? const [];
          if (visits.isEmpty && earlier.isEmpty) {
            return const EmptyView(
              message: 'Nobody is waiting. Triage by the nurse lands here.',
              icon: Icons.check_circle_outline,
            );
          }
          return ListView(
            children: [
              if (visits.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('TODAY\'S QUEUE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              for (final raw in visits) _tile(context, raw as Map<String, dynamic>, true),
              if (earlier.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text('DID NOT PROCEED',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              for (final raw in earlier) _tile(context, raw as Map<String, dynamic>, false),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> v, bool today) {
    final id = v['id'] as int;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: v['urgent'] == true
            ? Theme.of(context).colorScheme.error
            : null,
        child: Text(initials('${v['patientName']}')),
      ),
      title: Text('${v['patientName']}'),
      subtitle: Text([
        '${v['visitType']}',
        prettyDate('${v['visitDate']}'),
        if ('${v['complaint'] ?? ''}'.isNotEmpty) '${v['complaint']}',
        if (today && v['daysLeft'] != null) '${v['daysLeft']} day(s) left',
      ].join(' · ')),
      isThreeLine: true,
      trailing: today
          ? const Icon(Icons.chevron_right)
          : TextButton(
        onPressed: v['canRequeue'] == true
            ? () async {
          try {
            await ClinicApi.instance.requeue(id);
            _reload();
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        }
            : null,
        child: const Text('Re-queue'),
      ),
      onTap: today
          ? () async {
        final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => CompleteVisitScreen(visit: v),
        ));
        if (done == true) _reload();
      }
          : null,
    );
  }
}