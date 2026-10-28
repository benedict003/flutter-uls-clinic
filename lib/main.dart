import 'package:flutter/material.dart';

import 'api/clinic_api.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() => runApp(const SlcClinicApp());

class SlcClinicApp extends StatefulWidget {
  const SlcClinicApp({super.key});

  @override
  State<SlcClinicApp> createState() => _SlcClinicAppState();
}

class _SlcClinicAppState extends State<SlcClinicApp> {
  /// Resolves once at startup: restores the session cookie and asks /api/session
  /// whether that session is still valid.
  late final Future<bool> _boot;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();

    // Any 401 from anywhere in the app drops us back to the login screen.
    ClinicApi.instance.onSessionExpired = () {
      if (!mounted || !_signedIn) return;
      setState(() => _signedIn = false);
    };

    _boot = ClinicApi.instance.resume().then((ok) {
      if (mounted) setState(() => _signedIn = ok);
      return ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SLC Clinic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: FutureBuilder<bool>(
        future: _boot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (_signedIn) {
            return HomeShell(
              key: const ValueKey('home'),
              onSignOut: () => setState(() => _signedIn = false),
            );
          }
          return LoginScreen(
            key: const ValueKey('login'),
            onSignedIn: () => setState(() => _signedIn = true),
          );
        },
      ),
    );
  }
}