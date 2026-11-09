import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/Constants.dart';

/// Which map service the app should draw, as decided in the admin (Maps page).
class MapConfig {
  /// 'google' or 'osm'.
  final String provider;
  final String tileUrl;
  final String attribution;

  const MapConfig({this.provider = 'osm', this.tileUrl = defaultTileUrl, this.attribution = '© OpenStreetMap contributors'});

  static const String defaultTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  bool get isGoogle => provider == 'google';

  static MapConfig? _cached;

  /// Falls back to OpenStreetMap when the server cannot be reached: it needs no key, so the map still shows.
  static Future<MapConfig> load({bool refresh = false}) async {
    if (!refresh && _cached != null) return _cached!;
    try {
      final r = await http.get(Uri.parse('${mBaseUrl}map-config'), headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 8));
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      if (r.statusCode == 200 && body is Map) {
        final tile = body['osm_tile_url']?.toString() ?? '';
        _cached = MapConfig(
          provider: body['provider'] == 'google' ? 'google' : 'osm',
          tileUrl: tile.contains('{z}') ? tile : defaultTileUrl,
          attribution: body['attribution']?.toString() ?? '© OpenStreetMap contributors',
        );
        return _cached!;
      }
    } catch (_) {}
    return const MapConfig();
  }
}
