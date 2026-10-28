import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import '../widgets/state_views.dart';

/// One metric tile on the home screen.
class _Stat {
  const _Stat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onOpenTab});

  /// Switches the bottom-navigation tab (1 = Queue for a doctor, Triage for a nurse).
  final ValueChanged<int> onOpenTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = ClinicApi.instance;
    final summary = await api.statisticsSummary(schoolYear: 'current');
    final waiting = api.isDoctor
        ? ((await api.queue())['visits'] as List?)?.length ?? 0
        : (await api.visits()).length;
    final notifications = (await api.notifications()).length;
    return {
      'summary': summary,
      'waiting': waiting,
      'notifications': notifications,
    };
  }

  void _reload() => setState(() => _future = _load());

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

          final data = snapshot.data!;
          final summary = data['summary'] as Map<String, dynamic>;
          final outcomes = (summary['checkupOutcomes'] as Map?) ?? const {};
          final theme = Theme.of(context);

          final stats = <_Stat>[
            _Stat('Visits', '${summary['totalVisits'] ?? 0}',
                Icons.event_note_outlined),
            _Stat('Patients seen', '${summary['uniquePatients'] ?? 0}',
                Icons.people_outline),
            _Stat('Consultations', '${summary['consultations'] ?? 0}',
                Icons.medical_services_outlined),
            _Stat('Checkups', '${summary['checkups'] ?? 0}',
                Icons.fact_check_outlined),
            _Stat('Cleared', '${outcomes['cleared'] ?? 0}',
                Icons.verified_outlined),
            _Stat('Screening', '${outcomes['needsScreening'] ?? 0}',
                Icons.warning_amber_outlined),
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Branded header ───────────────────────────────────────────
              BrandBanner(
                title: 'Health Services Department',
                subtitle: 'Clinic today ${ClinicApi.instance.todayIso} · '
                    'signed in as ${ClinicApi.instance.role}',
                image: BrandImages.seal,
                imageHeight: 46,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ClinicApi.instance.isDoctor ? 'DOCTOR' : 'NURSE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Metrics ─────────────────────────────────────────────────
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.9,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final stat in stats)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(stat.icon, color: ClinicColors.navy, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(stat.value,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                          color: ClinicColors.ink,
                                          fontWeight: FontWeight.w700)),
                                  Text(stat.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Shortcuts ───────────────────────────────────────────────
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timelapse_outlined),
                  title: Text(ClinicApi.instance.isDoctor
                      ? 'Waiting for the doctor'
                      : 'Completed visits listed'),
                  subtitle: Text('${data['waiting']} record(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onOpenTab(1),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_none),
                  title: const Text('Notifications'),
                  subtitle: Text('${data['notifications']} total'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showNotifications(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showNotifications(BuildContext context) async {
    try {
      final items = await ClinicApi.instance.notifications();
      if (!context.mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
          child: SizedBox(
            height: 440,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      SafeAsset(kEmblemAsset, height: 26),
                      SizedBox(width: 10),
                      Text(
                        'Notifications',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? const EmptyView(
                    message: 'No notifications yet.',
                    icon: Icons.notifications_off_outlined,
                  )
                      : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = (items[i] as Map).cast<String, dynamic>();
                      final unread = n['readAt'] == null;
                      return ListTile(
                        leading: Icon(
                          unread
                              ? Icons.mark_email_unread_outlined
                              : Icons.mark_email_read_outlined,
                          color: unread ? ClinicColors.flame : null,
                        ),
                        title: Text('${n['message']}'),
                        subtitle: Text(
                            '${n['createdAt']}'.split('T').first),
                        onTap: () async {
                          try {
                            await ClinicApi.instance
                                .readNotification(n['id'] as int);
                            if (sheet.mounted) {
                              Navigator.of(sheet).pop();
                            }
                            _reload();
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          }
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
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}