import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/Constants.dart';
import 'DriverApplicationApi.dart' show ApiFailure;

/// Passenger and driver ride endpoints of the DROP API. Prices are always computed by the server.
class RideApi {
  RideApi._();

  static Uri _uri(String path) => Uri.parse('$mBaseUrl$path');

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${prefs.getString(TOKEN) ?? ''}',
    };
  }

  static Map<String, dynamic> _handle(http.Response r) {
    Map<String, dynamic> body = {};
    try {
      final decoded = jsonDecode(utf8.decode(r.bodyBytes));
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final message = body['message']?.toString();
    final failure = ApiFailure(message == null || message.isEmpty ? 'Something went wrong (${r.statusCode}). Please try again.' : message);
    _lastCode = body['code']?.toString();
    throw failure;
  }

  /// Machine-readable code of the last refusal (e.g. 'request_gone'), so screens can react to it.
  static String? _lastCode;
  static String? get lastCode => _lastCode;

  static Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    _lastCode = null;
    try {
      return _handle(await call().timeout(const Duration(seconds: 30)));
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw ApiFailure('Could not reach DROP. Check your internet connection and try again.');
    }
  }

  static Future<Map<String, dynamic>> _get(String path) async => _send(() async => http.get(_uri(path), headers: await _headers()));

  static Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async =>
      _send(() async => http.post(_uri(path), headers: await _headers(), body: jsonEncode(body ?? {})));

  static Map<String, dynamic> _point(double lat, double lng, String address) => {'lat': lat, 'lng': lng, 'address': address};

  // ---- Passenger ----

  /// Ride types with fares, nearby drivers and pickup times for a trip. Nothing is saved.
  static Future<Map<String, dynamic>> estimate({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropLat,
    required double dropLng,
    required String dropAddress,
  }) =>
      _post('ride/estimate', {'pickup': _point(pickupLat, pickupLng, pickupAddress), 'dropoff': _point(dropLat, dropLng, dropAddress)});

  static Future<Map<String, dynamic>> request({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropLat,
    required double dropLng,
    required String dropAddress,
    required int serviceId,
    required String paymentMethod,
    List<int> optionIds = const [],
  }) =>
      _post('ride/request', {
        'pickup': _point(pickupLat, pickupLng, pickupAddress),
        'dropoff': _point(dropLat, dropLng, dropAddress),
        'service_id': serviceId,
        'payment_method': paymentMethod,
        'option_ids': optionIds,
      });

  /// The passenger's open ride, or null inside `data`.
  static Future<Map<String, dynamic>> current() => _get('ride/current');

  static Future<Map<String, dynamic>> cancel([String? reason]) => _post('ride/cancel', {if (reason != null && reason.isNotEmpty) 'reason': reason});

  static Future<Map<String, dynamic>> history() => _get('ride/history');

  /// A link someone can open to follow this trip live.
  static Future<Map<String, dynamic>> shareTrip() => _post('ride/share');

  static Future<Map<String, dynamic>> stopSharing() => _post('ride/share/stop');

  /// A payment link so someone else can pay this ride's fare (PayMyRide).
  static Future<Map<String, dynamic>> payLink() => _post('ride/pay-link');

  // ---- Forgot password (no login needed) ----

  static Future<Map<String, dynamic>> forgotPassword(String identifier) => _post('forgot-password', {'identifier': identifier});

  static Future<Map<String, dynamic>> resetPassword(String identifier, String code, String password) =>
      _post('reset-password', {'identifier': identifier, 'code': code, 'password': password});

  /// The signed-in user's currency (code, symbol, decimals).
  static Future<Map<String, dynamic>> currency() => _get('account/currency');

  // ---- Recovery email ----

  static Future<Map<String, dynamic>> emailStatus() => _get('account/email');

  static Future<Map<String, dynamic>> saveEmail(String email, String password) => _post('account/email', {'email': email, 'password': password});

  // ---- Driver ----

  /// The open ride (`active`) or nearby requests (`requests`).
  static Future<Map<String, dynamic>> driverRequests() => _get('driver/requests');

  static Future<Map<String, dynamic>> accept(int id) => _post('driver/requests/$id/accept');

  static Future<Map<String, dynamic>> decline(int id) => _post('driver/requests/$id/decline');

  static Future<Map<String, dynamic>> arrived(int id) => _post('driver/rides/$id/arrived');

  static Future<Map<String, dynamic>> start(int id) => _post('driver/rides/$id/start');

  static Future<Map<String, dynamic>> complete(int id) => _post('driver/rides/$id/complete');

  static Future<Map<String, dynamic>> driverCancel(int id) => _post('driver/rides/$id/cancel');

  static Future<Map<String, dynamic>> driverHistory() => _get('driver/rides/history');
}
