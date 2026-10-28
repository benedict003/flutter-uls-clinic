import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ClinicApi.instance.login(_username.text, _password.text);
      if (!mounted) return;
      widget.onSignedIn();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Full-bleed campus photo. If the asset is missing, fades to transparent
  /// so the navy gradient underneath shows — never a grey placeholder.
  Widget _campusBackground() {
    return const BrandImage(
      BrandImages.campus,          // ← the list, not kCampusAsset
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      cacheWidth: 1200,
      showFallback: false,         // a failed photo must paint nothing, not an icon
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1 · Base gradient — visible whenever the photo does not load.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [ClinicColors.navy, ClinicColors.navyDeep],
              ),
            ),
          ),

          // 2 · Campus photo.
          _campusBackground(),

          // 3 · Scrim — dark at the top and bottom, lighter in the middle.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 0.70, 1.0],
                colors: [
                  Color.fromRGBO(14, 35, 80, 0.82),
                  Color.fromRGBO(14, 35, 80, 0.55),
                  Color.fromRGBO(14, 35, 80, 0.72),
                  Color.fromRGBO(14, 35, 80, 0.94),
                ],
              ),
            ),
          ),

          // 4 · Content.
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandHeader(onDark: true, showEmblem: true),
                      const SizedBox(height: 22),
                      Card(
                        elevation: 10,
                        shadowColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          child: Form(
                            key: _form,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.lock_outline,
                                        size: 20, color: ClinicColors.navy),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Clinic staff sign in',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: ClinicColors.ink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _username,
                                  autocorrect: false,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Username',
                                    prefixIcon: Icon(Icons.person_outline),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Enter your username'
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(_obscure
                                          ? Icons.visibility
                                          : Icons.visibility_off),
                                    ),
                                  ),
                                  validator: (v) =>
                                  (v == null || v.isEmpty)
                                      ? 'Enter your password'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                      : const Text('Sign in'),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(_error!,
                                        style: theme.textTheme.bodySmall),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                              const SettingsScreen(embedded: true)));
                          if (mounted) setState(() {});
                        },
                        icon: const Icon(Icons.dns_outlined,
                            size: 18, color: Colors.white70),
                        label: Text(
                          ClinicApi.instance.baseUrl,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      Text(
                        'Emulator: http://10.0.2.2:${AppConfig.port}   ·   '
                            'Phone: http://<pc-ip>:${AppConfig.port}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}