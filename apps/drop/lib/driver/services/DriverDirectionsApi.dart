import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A single manoeuvre returned by the Mapbox Directions API.
class DriverManeuver {
  final String instruction;
  final String roadName;
  final String type;
  final String modifier;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng location;

  const DriverManeuver({
    required this.instruction,
    required this.roadName,
    required this.type,
    required this.modifier,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
  });

  factory DriverManeuver.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] is Map ? Map<String, dynamic>.from(json['maneuver'] as Map) : <String, dynamic>{};
    final location = maneuver['location'] is List ? maneuver['location'] as List : const [];
    final point = location.length >= 2
        ? LatLng((location[1] as num).toDouble(), (location[0] as num).toDouble())
        : const LatLng(0, 0);
    return DriverManeuver(
      instruction: maneuver['instruction']?.toString() ?? 'Continue',
      roadName: json['name']?.toString() ?? '',
      type: maneuver['type']?.toString() ?? 'continue',
      modifier: maneuver['modifier']?.toString() ?? '',
      distanceMeters: (json['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['duration'] as num?)?.toDouble() ?? 0,
      location: point,
    );
  }
}

/// A Mapbox driving route with its geometry, summary and turn-by-turn steps.
class DriverDirectionsRoute {
  final List<LatLng> points;
  final List<DriverManeuver> maneuvers;
  final double distanceMeters;
  final double durationSeconds;

  const DriverDirectionsRoute({
    required this.points,
    required this.maneuvers,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  static Future<DriverDirectionsRoute> fetch({
    required LatLng origin,
    required LatLng destination,
    required String publicToken,
  }) async {
    if (!publicToken.startsWith('pk.')) {
      throw const FormatException('A valid Mapbox public token is not configured.');
    }
    final coordinates = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/driving-traffic/$coordinates',
      {
        'access_token': publicToken,
        'steps': 'true',
        'voice_instructions': 'true',
        'banner_instructions': 'true',
        'voice_units': 'metric',
        'language': 'en',
        'geometries': 'geojson',
        'overview': 'full',
        'alternatives': 'false',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200 || body is! Map || body['routes'] is! List || (body['routes'] as List).isEmpty) {
      final message = body is Map ? body['message']?.toString() : null;
      throw FormatException(message ?? 'Mapbox could not find a driving route.');
    }
    final route = Map<String, dynamic>.from((body['routes'] as List).first as Map);
    final geometry = route['geometry'] is Map ? Map<String, dynamic>.from(route['geometry'] as Map) : <String, dynamic>{};
    final coordinatesList = geometry['coordinates'] is List ? geometry['coordinates'] as List : const [];
    final points = <LatLng>[
      for (final coordinate in coordinatesList)
        if (coordinate is List && coordinate.length >= 2)
          LatLng((coordinate[1] as num).toDouble(), (coordinate[0] as num).toDouble()),
    ];
    final legs = route['legs'] is List ? route['legs'] as List : const [];
    final steps = legs.isNotEmpty && legs.first is Map && (legs.first as Map)['steps'] is List
        ? (legs.first as Map)['steps'] as List
        : const [];
    final maneuvers = <DriverManeuver>[
      for (final step in steps)
        if (step is Map) DriverManeuver.fromJson(Map<String, dynamic>.from(step)),
    ];
    if (points.length < 2) throw const FormatException('Mapbox returned an incomplete route.');
    return DriverDirectionsRoute(
      points: points,
      maneuvers: maneuvers,
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
    );
  }
}
