import 'package:flutter/foundation.dart';

class AppConfig {
  /// The port your backend prints after `npm start` (backend/.env PORT).
  static const int port = 3000;

  /// Real phone on the same Wi-Fi: 'http://192.168.1.20:3000' (your IPv4 from ipconfig).
  static const String hostOverride = '';

  static String get defaultBaseUrl {
    if (hostOverride.isNotEmpty) return hostOverride;
    if (kIsWeb) return 'http://localhost:$port';
    // The Android emulator reaches the PC's localhost through 10.0.2.2
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:$port';
    return 'http://localhost:$port';
  }

  static const Duration requestTimeout = Duration(seconds: 25);
}