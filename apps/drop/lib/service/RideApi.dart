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
    List<Map<String, dynamic>> stops = const [],
  }) =>
      _post('ride/estimate', {'pickup': _point(pickupLat, pickupLng, pickupAddress), 'dropoff': _point(dropLat, dropLng, dropAddress), 'stops': stops});

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
    List<Map<String, dynamic>> stops = const [],
  }) =>
      _post('ride/request', {
        'pickup': _point(pickupLat, pickupLng, pickupAddress),
        'dropoff': _point(dropLat, dropLng, dropAddress),
        'stops': stops,
        'service_id': serviceId,
        'payment_method': paymentMethod,
        'option_ids': optionIds,
      });

  /// Server-controlled maximum number of additional passenger stops (zero disables them).
  static Future<int> stopLimit() async {
    final response = await _get('ride/stop-settings');
    final data = response['data'];
    if (data is! Map) return 0;
    final value = data['max_additional_stops'];
    return value is num ? value.toInt().clamp(0, 20).toInt() : 0;
  }

  /// Ride types open at the passenger's location, with drivers nearby (no fares yet).
  static Future<Map<String, dynamic>> rideTypes(double lat, double lng) => _get('ride/types?lat=$lat&lng=$lng');

  /// The passenger's open ride, or null inside `data`.
  static Future<Map<String, dynamic>> current() => _get('ride/current');

  static Future<Map<String, dynamic>> cancel([String? reason]) => _post('ride/cancel', {if (reason != null && reason.isNotEmpty) 'reason': reason});

  static Future<Map<String, dynamic>> history() => _get('ride/history');

  /// The passenger's numbered receipt for a finished trip.
  static Future<Map<String, dynamic>> receipt(int id) => _get('ride/$id/receipt');

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

  /// Rate the driver of a completed ride, 1 to 5 stars.
  static Future<Map<String, dynamic>> rate(dynamic rideId, int stars, [String? comment]) =>
      _post('ride/rating', {'ride_request_id': rideId, 'rating': stars, if (comment != null && comment.isNotEmpty) 'comment': comment});

  // ---- Recovery email ----

  static Future<Map<String, dynamic>> emailStatus() => _get('account/email');

  static Future<Map<String, dynamic>> saveEmail(String email, String password) => _post('account/email', {'email': email, 'password': password});

  // ---- Driver ----

  /// The open ride (`active`) or nearby requests (`requests`).
  static Future<Map<String, dynamic>> driverRequests() => _get('driver/requests');

  static Future<Map<String, dynamic>> accept(int id) => _post('driver/requests/$id/accept');

  static Future<Map<String, dynamic>> decline(int id) => _post('driver/requests/$id/decline');

  static Future<Map<String, dynamic>> arrived(int id) => _post('driver/rides/$id/arrived');

  /// Verify the passenger's four-digit pickup code before starting a ride.
  static Future<Map<String, dynamic>> verifyPickup(int id, String code) => _post('driver/rides/$id/verify-pickup', {'code': code});

  /// Driver: arrive at the next server-ordered additional stop.
  static Future<Map<String, dynamic>> arriveAtStop(int rideId, int stopId) =>
      _post('driver/rides/$rideId/stops/$stopId/arrived');

  /// Driver: confirm completion of the currently arrived additional stop.
  static Future<Map<String, dynamic>> completeStop(int rideId, int stopId) =>
      _post('driver/rides/$rideId/stops/$stopId/complete');

  static Future<Map<String, dynamic>> start(int id) => _post('driver/rides/$id/start');

  static Future<Map<String, dynamic>> complete(int id) => _post('driver/rides/$id/complete');

  static Future<Map<String, dynamic>> driverCancel(int id) => _post('driver/rides/$id/cancel');

  static Future<Map<String, dynamic>> driverHistory() => _get('driver/rides/history');

  /// The driver's numbered receipt for a finished trip (fare, commission, earning).
  static Future<Map<String, dynamic>> driverReceipt(int id) => _get('driver/rides/$id/receipt');

  // ---- Extra charges after a trip (toll, parking, waiting) ----

  /// Driver: add an extra charge to a finished trip. The passenger is asked to approve it.
  static Future<Map<String, dynamic>> proposeExtra(int rideId, {required int typeId, required double amount, String? note}) =>
      _post('driver/rides/$rideId/extras', {'type_id': typeId, 'amount': amount, if (note != null && note.isNotEmpty) 'note': note});

  /// Driver: extras on a trip, whether one can still be added, and how much more is allowed.
  static Future<Map<String, dynamic>> driverExtras(int rideId) => _get('driver/rides/$rideId/extras');

  /// Passenger: extra charges waiting for an answer, plus the wallet balance.
  static Future<Map<String, dynamic>> pendingExtras() => _get('ride/extras/pending');

  static Future<Map<String, dynamic>> payExtra(int id, String method) => _post('ride/extras/$id/pay', {'method': method});

  static Future<Map<String, dynamic>> declineExtra(int id) => _post('ride/extras/$id/decline');
}
