import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../widgets/brand.dart';
import 'certificates_screen.dart';
import 'dashboard_screen.dart';
import 'patients_screen.dart';
import 'prescriptions_screen.dart';
import 'queue_screen.dart';
import 'settings_screen.dart';
import 'triage_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_Tab> get _tabs {
    final api = ClinicApi.instance;
    return [
      const _Tab('Home', Icons.dashboard_outlined, Icons.dashboard),
      if (api.isDoctor)
        const _Tab('Queue', Icons.assignment_outlined, Icons.assignment)
      else
        const _Tab('Triage', Icons.monitor_heart_outlined, Icons.monitor_heart),
      const _Tab('Patients', Icons.people_outline, Icons.people),
      const _Tab('Rx', Icons.medication_outlined, Icons.medication),
      const _Tab('More', Icons.more_horiz, Icons.more_horiz),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final safeIndex = _index.clamp(0, tabs.length - 1);

    final screens = <Widget>[
      DashboardScreen(onOpenTab: (i) => setState(() => _index = i)),
      ClinicApi.instance.isDoctor ? const QueueScreen() : const TriageScreen(),
      const PatientsScreen(),
      const PrescriptionsScreen(),
      _MoreScreen(onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      appBar: clinicAppBar(
        tabs[safeIndex].label,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${ClinicApi.instance.displayName} · ${ClinicApi.instance.role}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
      // veil: 0.72 -> photo clearly visible behind every tab.
      body: ClinicBackground(
        veil: 0.45,
        child: IndexedStack(index: safeIndex, children: screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selected),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.selected);
  final String label;
  final IconData icon;
  final IconData selected;
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen({required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final api = ClinicApi.instance;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: BrandBanner(
            title: api.displayName,
            subtitle: '${api.role} · @${api.user?['username']}',
            image: BrandImages.seal,
            imageHeight: 34,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: const Text('Certificates'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CertificatesScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: const Text('Server & session'),
          subtitle: Text(api.baseUrl),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
          title: const Text('Sign out'),
          onTap: () async {
            await ClinicApi.instance.signOut();
            onSignOut();
          },
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 28, 16, 0),
          child: Column(
            children: [
              BrandImage(BrandImages.seal, height: 52),
              SizedBox(height: 8),
              Text('University of La Salette, Inc.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text('Health Services Department', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}