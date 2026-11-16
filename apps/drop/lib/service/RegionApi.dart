import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'DriverApplicationApi.dart';

/// Which DROP region a phone is in, and moving a person's service region when they cross a border.
class RegionApi {
  static Future<Map<String, dynamic>> at(double lat, double lng) =>
      DriverApplicationApi.getJson('region/at?lat=$lat&lng=$lng');

  /// Public shape data for optional Mapbox region overlays. It is advisory/rendering data only;
  /// the Worker/PostGIS endpoints remain authoritative for membership and switching.
  static Future<List<List<LatLng>>> boundaries() async {
    final response = await DriverApplicationApi.getJson('region/boundaries').timeout(const Duration(seconds: 8));
    final features = response['features'];
    if (features is! List) return const [];
    final result = <List<LatLng>>[];
    for (final feature in features) {
      if (feature is! Map) continue;
      final geometry = feature['geometry'];
      if (geometry is! Map || geometry['type'] != 'Polygon') continue;
      final rings = geometry['coordinates'];
      if (rings is! List || rings.isEmpty || rings.first is! List) continue;
      final points = <LatLng>[];
      for (final pair in rings.first as List) {
        if (pair is List && pair.length >= 2 && pair[0] is num && pair[1] is num) {
          points.add(LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()));
        }
      }
      if (points.length >= 4) result.add(points);
    }
    return result;
  }

  /// Returns the index of the first polygon containing the point, or null when outside all polygons.
  /// This client result is only a boundary-crossing hint; the server re-checks every proposed switch.
  static int? containingPolygonIndex(LatLng point, List<List<LatLng>> polygons) {
    for (var i = 0; i < polygons.length; i++) {
      final ring = polygons[i];
      var inside = false;
      for (var j = 0, k = ring.length - 1; j < ring.length; k = j++) {
        final a = ring[j], b = ring[k];
        final crosses = ((a.latitude > point.latitude) != (b.latitude > point.latitude)) &&
            (point.longitude < (b.longitude - a.longitude) * (point.latitude - a.latitude) /
                ((b.latitude - a.latitude).abs() < 1e-12 ? 1e-12 : (b.latitude - a.latitude)) + a.longitude);
        if (crosses) inside = !inside;
      }
      if (inside) return i;
    }
    return null;
  }

  /// Great-circle approximation of distance to polygon edges. Used only to confirm a local
  /// candidate transition is near an actual service boundary before asking the server early.
  static bool isNearBoundary(LatLng point, List<List<LatLng>> polygons, {double withinMeters = 100}) {
    const metersPerDegree = 111320.0;
    final longitudeScale = metersPerDegree * math.cos(point.latitude * math.pi / 180);
    for (final ring in polygons) {
      for (var i = 0; i < ring.length - 1; i++) {
        final a = ring[i], b = ring[i + 1];
        final ax = (a.longitude - point.longitude) * longitudeScale;
        final ay = (a.latitude - point.latitude) * metersPerDegree;
        final bx = (b.longitude - point.longitude) * longitudeScale;
        final by = (b.latitude - point.latitude) * metersPerDegree;
        final dx = bx - ax, dy = by - ay;
        final denominator = dx * dx + dy * dy;
        final t = denominator == 0 ? 0.0 : (-(ax * dx + ay * dy) / denominator).clamp(0.0, 1.0);
        final distance = ((ax + t * dx) * (ax + t * dx) + (ay + t * dy) * (ay + t * dy));
        if (distance <= withinMeters * withinMeters) return true;
      }
    }
    return false;
  }

  static Future<Map<String, dynamic>> switchTo(int regionId, double lat, double lng) =>
      DriverApplicationApi.putJson('region/me', {'region_id': regionId, 'lat': lat, 'lng': lng});
}
