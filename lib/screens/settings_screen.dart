import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../config/app_config.dart';
import '../widgets/brand.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url =
  TextEditingController(text: ClinicApi.instance.baseUrl);

  bool _busy = false;
  bool _ok = false;
  String? _message;
  Map<String, dynamic>? _health;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _message = null;
      _health = null;
    });
    try {
      final summary = await ClinicApi.instance.probe(_url.text);
      final health = await ClinicApi.instance.health();
      if (!mounted) return;
      setState(() {
        _ok = true;
        _message = summary;
        _health = health;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _message = '$e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ClinicApi.instance.setBaseUrl(_url.text);
    messenger.showSnackBar(const SnackBar(content: Text('Server saved.')));
    if (widget.embedded && navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Center(
          child: Column(
            children: [
              BrandImage(BrandImages.seal, height: 64),
              SizedBox(height: 8),
              Text('University of La Salette, Inc.',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text('Health Services Department',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'API base URL',
            prefixIcon: Icon(Icons.dns_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.smartphone, size: 16),
              label: const Text('Emulator 10.0.2.2'),
              onPressed: () => setState(
                      () => _url.text = 'http://10.0.2.2:${AppConfig.port}'),
            ),
            ActionChip(
              avatar: const Icon(Icons.desktop_windows_outlined, size: 16),
              label: const Text('localhost'),
              onPressed: () => setState(
                      () => _url.text = 'http://localhost:${AppConfig.port}'),
            ),
            ActionChip(
              avatar: const Icon(Icons.phone_android, size: 16),
              label: const Text('USB phone (adb reverse)'),
              onPressed: () => setState(
                      () => _url.text = 'http://localhost:${AppConfig.port}'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _test,
                icon: _busy
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.bolt),
                label: Text(_busy ? 'Testing…' : 'Test connection'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: 16),
          Card(
            color: _ok
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.errorContainer,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_ok ? Icons.check_circle_outline : Icons.cloud_off),
                      const SizedBox(width: 8),
                      Text(_ok ? 'Reachable' : 'Not reachable'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_message!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
        if (_health != null) ...[
          const SizedBox(height: 12),
          Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in _health!.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('${e.key}: ${e.value}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),
        ],
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_user_outlined),
          title: const Text('Session'),
          subtitle: Text(
            ClinicApi.instance.signedIn
                ? 'Signed in as ${ClinicApi.instance.displayName} '
                '(${ClinicApi.instance.role})'
                : 'Not signed in',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: const Text('Build'),
          subtitle: const Text('Flutter release build · debug mode'),
        ),
      ],
    );

    final title = widget.embedded ? 'Server' : 'Server & session';

    return Scaffold(
      appBar: clinicAppBar(title),
      body: ClinicBackground(veil: 0.97, child: content),
    );
  }
}