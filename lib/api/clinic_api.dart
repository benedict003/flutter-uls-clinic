import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  bool get isForbidden => status == 403;
  bool get isConflict => status == 409;
  @override
  String toString() => message;
}

class SessionExpiredException extends ApiException {
  SessionExpiredException() : super('Your session ended. Please sign in again.', 401);
}

class ClinicApi {
  ClinicApi._();
  static final ClinicApi instance = ClinicApi._();

  final http.Client _client = http.Client();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const _kBaseUrl = 'clinic.baseUrl';
  static const _kCookie = 'clinic.session';
  static const _kCsrf = 'clinic.csrf';
  static final RegExp _cookiePattern = RegExp(r'clinic_session=([a-f0-9]{64})');

  /// The emulator uses 10.0.2.2; a real phone needs http://your-lan-ip:3000.
  String baseUrl = AppConfig.defaultBaseUrl;

  /// The clinic's "today" as reported by the server (Asia/Manila), not the phone clock.
  String? clinicToday;

  String? _sessionToken;
  String? _csrfToken;
  Map<String, dynamic>? user;

  /// Set by main.dart: fires on any 401 so the UI returns to login.
  VoidCallback? onSessionExpired;

  bool get signedIn => _sessionToken != null && user != null;
  String get role => user?['role']?.toString() ?? '';
  bool get isDoctor => role == 'doctor';
  bool get isNurse => role == 'nurse';
  String get displayName => user?['name']?.toString() ?? '';

  String get todayIso => clinicToday ?? localToday();

  // ── plumbing ────────────────────────────────────────────────────────────
  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers({bool write = false, bool json = false}) => {
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json',
    if (_sessionToken != null) 'Cookie': 'clinic_session=$_sessionToken',
    if (write && _csrfToken != null) 'X-CSRF-Token': _csrfToken!,
  };

  Future<Map<String, dynamic>> _request(
      String method,
      String path, {
        Map<String, dynamic>? body,
      }) async {
    final write = method != 'GET';
    try {
      final response = await _client
          .send(http.Request(method, _uri(path))
        ..headers.addAll(_headers(write: write, json: write))
        ..body = write ? jsonEncode(body ?? const <String, dynamic>{}) : '')
          .then(http.Response.fromStream)
          .timeout(AppConfig.requestTimeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException('$baseUrl did not answer within '
          '${AppConfig.requestTimeout.inSeconds}s. Is "npm start" still running?');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Cannot reach $baseUrl\n$e');
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode == 401) {
      onSessionExpired?.call();
      throw SessionExpiredException();
    }
    dynamic data;
    try {
      data = res.body.trim().isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (_) {
      data = {'error': res.body};
    }
    if (res.statusCode >= 400) {
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Request failed (HTTP ${res.statusCode}).';
      throw ApiException(message, res.statusCode);
    }
    return data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
  }

  Map<String, dynamic> get _nothing => const <String, dynamic>{};

  // ── connection ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> health() async {
    final data = await _request('GET', '/api/health');
    clinicToday = data['clinicToday']?.toString();
    return data;
  }

  /// Health check that ignores auth entirely; throws a readable error when down.
  Future<String> probe(String url) async {
    final saved = baseUrl;
    baseUrl = url.replaceAll(RegExp(r'/+$'), '');
    try {
      final data = await health();
      return 'Connected · ${data['service'] ?? 'backend'} · '
          'clinic today ${data['clinicToday']} (${data['timeZone']})';
    } catch (_) {
      baseUrl = saved;
      rethrow;
    }
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url.replaceAll(RegExp(r'/+$'), '');
    await _storage.write(key: _kBaseUrl, value: baseUrl);
  }

  // ── auth ────────────────────────────────────────────────────────────────
  Future<void> login(String username, String password) async {
    final res = await _client
        .post(
      _uri('/api/login'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username.trim(),
        'password': password,
        'remember': true,
      }),
    )
        .timeout(AppConfig.requestTimeout);

    final data = _decode(res); // throws on 401/403/429/400
    final token = _cookiePattern.firstMatch(res.headers['set-cookie'] ?? '')?.group(1);
    if (token == null) {
      throw ApiException('The server did not send a clinic_session cookie.');
    }

    _sessionToken = token;
    _csrfToken = data['csrfToken']?.toString();
    user = (data['user'] as Map?)?.cast<String, dynamic>();
    await _persist();
    await health(); // learns clinicToday; harmless if it fails
  }

  /// Called at app start: cookie from secure storage → fresh CSRF token.
  Future<bool> resume() async {
    baseUrl = await _storage.read(key: _kBaseUrl) ?? baseUrl;
    _sessionToken ??= await _storage.read(key: _kCookie);
    _csrfToken ??= await _storage.read(key: _kCsrf);
    try {
      clinicToday ??= (await health())['clinicToday']?.toString();
    } catch (_) {/* offline: the login screen will explain */}
    if (_sessionToken == null) return false;
    try {
      final data = await _request('GET', '/api/session');
      user = (data['user'] as Map?)?.cast<String, dynamic>();
      _csrfToken = data['csrfToken']?.toString() ?? _csrfToken;
      await _persist();
      return user != null;
    } on SessionExpiredException {
      await signOut();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    if (_sessionToken != null) {
      try {
        await _request('POST', '/api/logout'); // needs X-CSRF-Token (non-GET)
      } catch (_) {/* already dead */}
    }
    _sessionToken = null;
    _csrfToken = null;
    user = null;
    await _storage.delete(key: _kCookie);
    await _storage.delete(key: _kCsrf);
  }

  Future<void> _persist() async {
    await _storage.write(key: _kBaseUrl, value: baseUrl);
    if (_sessionToken != null) await _storage.write(key: _kCookie, value: _sessionToken);
    if (_csrfToken != null) await _storage.write(key: _kCsrf, value: _csrfToken);
  }

  // ── patients ────────────────────────────────────────────────────────────
  Future<List<dynamic>> searchPatients(String term) async {
    final data = await _request('GET',
        '/api/patients?search=${Uri.encodeQueryComponent(term)}');
    return (data['patients'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> patient(String id) async =>
      (await _request('GET', '/api/patients/$id'))['patient'] as Map<String, dynamic>;

  Future<Map<String, dynamic>> patientRecord(String id, {String schoolYear = ''}) async {
    final q = schoolYear.isEmpty ? '' : '?schoolYear=$schoolYear';
    return (await _request('GET', '/api/patients/$id/record$q'))['record']
    as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patientHistory(String id) async =>
      (await _request('GET', '/api/patients/$id/history'))['history']
      as Map<String, dynamic>;

  Future<Map<String, dynamic>> patientRequirements(String id) async =>
      (await _request('GET', '/api/patients/$id/requirements'))['requirements']
      as Map<String, dynamic>;

  Future<List<dynamic>> patientPrescriptions(String id) async =>
      ((await _request('GET', '/api/patients/$id/prescriptions'))['prescriptions']
      as List?) ?? const [];

  // ── visits ──────────────────────────────────────────────────────────────
  /// Doctor only: the exam queue (+ didNotProceed placed earlier).
  Future<Map<String, dynamic>> queue() => _request('GET', '/api/visits/queue');

  Future<List<dynamic>> visits({String search = '', String type = '', String schoolYear = ''}) async {
    final q = <String>[
      'search=${Uri.encodeQueryComponent(search)}',
      if (type.isNotEmpty) 'type=$type',
      if (schoolYear.isNotEmpty) 'schoolYear=$schoolYear',
      'copies=exclude',
    ].join('&');
    return ((await _request('GET', '/api/visits?$q'))['visits'] as List?) ?? const [];
  }

  /// Nurse only. BP is ONE string, e.g. '120/80'.
  Future<Map<String, dynamic>> triage(Map<String, dynamic> payload) async =>
      (await _request('POST', '/api/visits/triage', body: payload))['visit']
      as Map<String, dynamic>;

  /// Doctor only.
  Future<Map<String, dynamic>> completeVisit(int id, Map<String, dynamic> payload) async =>
      (await _request('POST', '/api/visits/$id/complete', body: payload))['visit']
      as Map<String, dynamic>;

  Future<void> requeue(int id) => _request('POST', '/api/visits/$id/requeue', body: _nothing);

  // ── prescriptions ───────────────────────────────────────────────────────
  Future<List<dynamic>> prescriptions({String status = 'pending'}) async =>
      ((await _request('GET', '/api/prescriptions?status=$status'))['prescriptions']
      as List?) ?? const [];

  Future<void> dispense(int id) =>
      _request('POST', '/api/prescriptions/$id/dispense', body: _nothing);

  /// Kept in sync with FREQUENCIES in backend/services/prescriptions.service.js
  static const List<String> frequencies = [
    'Once daily', 'Twice daily (BID)', 'Three times daily (TID)',
    'Four times daily (QID)', 'Every 4 hours', 'Every 6 hours', 'Every 8 hours',
    'At bedtime', 'As needed (PRN)', 'Single dose',
  ];

  // ── certificates & notifications ────────────────────────────────────────
  Future<List<dynamic>> certificates({String status = ''}) async {
    final q = status.isEmpty ? '' : '?status=${Uri.encodeQueryComponent(status)}';
    return ((await _request('GET', '/api/certificates$q'))['certificates'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> certificate(int id) =>
      _request('GET', '/api/certificates/$id');

  /// submit / approve / return / revise. `version` is the optimistic lock —
  /// reuse the version from the latest GET or you get a 409.
  Future<void> certificateAction(
      int id,
      String action, {
        required int version,
        String remarks = '',
      }) async {
    await _request('POST', '/api/certificates/$id/$action', body: {
      'version': version,
      if (remarks.isNotEmpty) 'remarks': remarks,
    });
  }

  Future<List<dynamic>> notifications() async =>
      ((await _request('GET', '/api/notifications'))['notifications'] as List?) ?? const [];

  Future<void> readNotification(int id) =>
      _request('POST', '/api/notifications/$id/read', body: _nothing);

  // ── reference & statistics ──────────────────────────────────────────────
  Future<Map<String, dynamic>> schoolYears() => _request('GET', '/api/school-years');

  Future<Map<String, dynamic>> statisticsSummary({String schoolYear = ''}) async {
    final q = schoolYear.isEmpty ? '' : '?schoolYear=$schoolYear';
    return (await _request('GET', '/api/statistics/summary$q'))['summary']
    as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> morbidity({String schoolYear = ''}) async {
    final q = schoolYear.isEmpty ? '' : '?schoolYear=$schoolYear';
    return (await _request('GET', '/api/statistics/morbidity$q'))['morbidity']
    as Map<String, dynamic>;
  }
}

/// Local fallback kept out of the getter so it stays testable.
String localToday() {
  final d = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}