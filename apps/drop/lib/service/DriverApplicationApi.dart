import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/Constants.dart';

/// Something the server (or the network) refused, with a message fit to show the person.
class ApiFailure implements Exception {
  final String message;
  final Map<String, String> fields;

  ApiFailure(this.message, [this.fields = const {}]);

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
    throw ApiFailure(message == null || message.isEmpty ? 'Something went wrong (${r.statusCode}). Please try again.' : message, fields);
  }

  static Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    try {
      return _handle(await call().timeout(const Duration(seconds: 60)));
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw ApiFailure('Could not reach DROP. Check your internet connection and try again.');
    }
  }

  /// Ride types, required documents and rules (minimum age, licence years, upload size).
  static Future<Map<String, dynamic>> requirements() async => _send(() async => http.get(_uri('driver/requirements'), headers: await _headers()));

  /// The person's draft, review status and per-document status.
  static Future<Map<String, dynamic>> application() async => _send(() async => http.get(_uri('driver/application'), headers: await _headers()));

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
    await _send(() async => http.put(_uri('driver/application/photo'), headers: await _headers(contentType: 'application/octet-stream'), body: bytes));
  }

  static Future<void> uploadDocument(int documentId, Uint8List bytes, {String? expireDate}) async {
    await _send(() async => http.put(
          _uri('driver/documents/$documentId', expireDate == null ? null : {'expire_date': expireDate}),
          headers: await _headers(contentType: 'application/octet-stream'),
          body: bytes,
        ));
  }

  static Future<void> submit() async {
    await _send(() async => http.post(_uri('driver/application/submit'), headers: await _headers()));
  }

  // ---- driver mode: online state ----

  /// Online state, wallet against the minimum, and why going online may be blocked.
  static Future<Map<String, dynamic>> driverStatus() async => _send(() async => http.get(_uri('driver/status'), headers: await _headers()));

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
}
