import 'DriverApplicationApi.dart';

/// Which DROP region a phone is in, and moving a person's service region when they cross a border.
class RegionApi {
  /// Region at this point, the person's current region, and whether to ask them to switch.
  static Future<Map<String, dynamic>> at(double lat, double lng) => DriverApplicationApi.getJson('region/at?lat=$lat&lng=$lng');

  /// The person accepted the change.
  static Future<Map<String, dynamic>> switchTo(int regionId, double lat, double lng) =>
      DriverApplicationApi.putJson('region/me', {'region_id': regionId, 'lat': lat, 'lng': lng});
}
