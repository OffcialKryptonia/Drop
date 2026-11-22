import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/Constants.dart';
import 'net/net_policy.dart';

/// Something the server (or the network) refused, with a message fit to show the person.
class ApiFailure implements Exception {
  final String message;
  final Map<String, String> fields;

  ApiFailure(this.message, [this.fields = const {}]);

  /// HTTP status when the server answered (null for network failures).
  int? status;

  /// The device was offline, so nothing was sent.
  bool offline = false;

  /// The request timed out *after* it may have reached the server. The result is unknown: check before trying again.
  bool unconfirmed = false;

  bool timedOut = false;

  /// A gateway or availability error that is worth one more try for a read.
  bool get retriable => status != null && (status == 502 || status == 503 || status == 504);

  @override
  String toString() => message;
}

/// Calls the driver application endpoints of the DROP API.
class DriverApplicationApi {
  DriverApplicationApi._();

  static Uri _uri(String path, [Map<String, String>? query]) => Uri.parse('$mBaseUrl$path').replace(queryParameters: query);

  static Future<Map<String, String>> _headers({String? contentType}) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer ${prefs.getString(TOKEN) ?? ''}',
      if (contentType != null) 'Content-Type': contentType,
    };
  }

  static Map<String, dynamic> _handle(http.Response r) {
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(utf8.decode(r.bodyBytes));
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final fields = <String, String>{};
    final errors = body['errors'];
    if (errors is Map) {
      errors.forEach((k, v) {
        if (v is List && v.isNotEmpty) fields[k.toString()] = v.first.toString();
      });
    }
    final message = body['message']?.toString();
    throw ApiFailure(message == null || message.isEmpty ? 'Something went wrong (${r.statusCode}). Please try again.' : message, fields)..status = r.statusCode;
  }

  /// Reads are shared and retried; everything else is a write: refused offline, never retried, never queued.
  /// Uploads (photos, documents) get a longer allowance.
  static Future<Map<String, dynamic>> _send(Future<http.Response> Function() call, {String? readKey, Duration? timeout}) {
    if (readKey != null) return NetGate.read('d:$readKey', (t) async => _handle(await call().timeout(t)));
    return NetGate.write((t) async => _handle(await call().timeout(t)), timeout: timeout ?? const Duration(seconds: 25));
  }

  /// Address suggestions from DROP's shared place-search provider (Google when configured, otherwise OpenStreetMap).
  /// The returned coordinates are provider-independent and can be rendered by the active map.
  static Future<List<Map<String, dynamic>>> searchPlaces(String query, {double? latitude, double? longitude}) async {
    final q = <String, String>{'q': query.trim()};
    if (latitude != null && longitude != null) {
      q['lat'] = latitude.toString();
      q['lng'] = longitude.toString();
    }
    final response = await _send(() async => http.get(_uri('places/search', q), headers: await _headers()), readKey: 'places/search?${q['q']}');
    final data = response['data'];
    if (data is! List) return const [];
    return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  /// Ride types, required documents and rules (minimum age, licence years, upload size).
  static Future<Map<String, dynamic>> requirements() async => _send(() async => http.get(_uri('driver/requirements'), headers: await _headers()), readKey: 'driver/requirements');

  /// The person's draft, review status and per-document status.
  static Future<Map<String, dynamic>> application() async => _send(() async => http.get(_uri('driver/application'), headers: await _headers()), readKey: 'driver/application');

  static Future<void> savePersonal({required String firstName, required String lastName, required String dateOfBirth}) async {
    await _send(() async => http.put(
          _uri('driver/application/personal'),
          headers: await _headers(contentType: 'application/json'),
          body: jsonEncode({'first_name': firstName, 'last_name': lastName, 'date_of_birth': dateOfBirth}),
        ));
  }

  static Future<void> saveVehicle(Map<String, dynamic> vehicle) async {
    await _send(() async => http.put(
          _uri('driver/application/vehicle'),
          headers: await _headers(contentType: 'application/json'),
          body: jsonEncode(vehicle),
        ));
  }

  static Future<void> uploadPhoto(Uint8List bytes) async {
    await _send(() async => http.put(_uri('driver/application/photo'), headers: await _headers(contentType: 'application/octet-stream'), body: bytes), timeout: const Duration(seconds: 90));
  }

  static Future<void> uploadDocument(int documentId, Uint8List bytes, {String? expireDate}) async {
    await _send(() async => http.put(
          _uri('driver/documents/$documentId', expireDate == null ? null : {'expire_date': expireDate}),
          headers: await _headers(contentType: 'application/octet-stream'),
          body: bytes,
        ), timeout: const Duration(seconds: 90));
  }

  static Future<void> submit() async {
    await _send(() async => http.post(_uri('driver/application/submit'), headers: await _headers()));
  }

  // ---- driver mode: online state ----

  /// Online state, wallet against the minimum, and why going online may be blocked.
  static Future<Map<String, dynamic>> driverStatus() async => _send(() async => http.get(_uri('driver/status'), headers: await _headers()), readKey: 'driver/status');

  static Future<void> setOnline(bool online, {double? latitude, double? longitude}) async {
    await _send(() async => http.post(
          _uri('driver/online'),
          headers: await _headers(contentType: 'application/json'),
          body: jsonEncode({'online': online, if (latitude != null) 'latitude': latitude, if (longitude != null) 'longitude': longitude}),
        ));
  }

  static Future<void> pingLocation(double latitude, double longitude) async {
    await _send(() async => http.post(
          _uri('driver/location'),
          headers: await _headers(contentType: 'application/json'),
          body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
        ));
  }

  // ---- driver mode: profile, payouts ----

  /// Referral code, ride type and vehicle.
  static Future<Map<String, dynamic>> driverProfile() async => _send(() async => http.get(_uri('driver/profile'), headers: await _headers()), readKey: 'driver/profile');

  /// Balance, smallest payout, bank account and payout history.
  static Future<Map<String, dynamic>> payouts() async => _send(() async => http.get(_uri('driver/payouts'), headers: await _headers()), readKey: 'driver/payouts');

  static Future<String> requestPayout(num amount) async {
    final r = await _send(() async => http.post(
          _uri('save-withdrawrequest'),
          headers: await _headers(contentType: 'application/json'),
          body: jsonEncode({'amount': amount}),
        ));
    return r['message']?.toString() ?? 'Payout requested.';
  }

  // ---- plain helpers for other small features (SOS, complaints) ----

  static Future<Map<String, dynamic>> getJson(String path) async => _send(() async => http.get(_uri(path), headers: await _headers()), readKey: path);

  static Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body) async =>
      _send(() async => http.put(_uri(path), headers: await _headers(contentType: 'application/json'), body: jsonEncode(body)));

  static Future<Map<String, dynamic>> deleteJson(String path) async => _send(() async => http.delete(_uri(path), headers: await _headers()));

  static Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async =>
      _send(() async => http.post(_uri(path), headers: await _headers(contentType: 'application/json'), body: jsonEncode(body)));
}
