import 'DriverApplicationApi.dart';
import 'package:latlong2/latlong.dart';

/// Which DROP region a phone is in, and moving a person's service region when they cross a border.
class RegionApi {
  static Future<Map<String, dynamic>> at(double lat, double lng) =>
      DriverApplicationApi.getJson('region/at?lat=$lat&lng=$lng');

  /// Public shape data for optional Mapbox region overlays. It is advisory/rendering data only;
  /// the Worker/PostGIS endpoints remain authoritative for membership and switching.
  static Future<List<List<LatLng>>> boundaries() async {
    final response = await DriverApplicationApi.getJson('region/boundaries');
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

  static Future<Map<String, dynamic>> switchTo(int regionId, double lat, double lng) =>
      DriverApplicationApi.putJson('region/me', {'region_id': regionId, 'lat': lat, 'lng': lng});
}
