import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/Constants.dart';

/// Which map service the app should draw, as decided in the admin (Maps page).
class MapConfig {
  /// 'google' or 'osm'.
  final String provider;
  final String tileUrl;
  final String attribution;
  final String styleUrl;

  const MapConfig({
    this.provider = 'maplibre',
    this.tileUrl = defaultTileUrl,
    this.attribution = '© OpenStreetMap contributors',
    this.styleUrl = defaultStyleUrl,
  });

  static const String defaultTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String defaultStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  bool get isGoogle => provider == 'google';
  bool get isMapLibre => provider == 'maplibre';

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
          provider: body['provider'] == 'google' ? 'google' : 'maplibre',
          tileUrl: tile.contains('{z}') ? tile : defaultTileUrl,
          attribution: body['attribution']?.toString() ?? '© OpenStreetMap contributors',
          styleUrl: body['maplibre_style_url']?.toString().startsWith('https://') == true
              ? body['maplibre_style_url'].toString()
              : defaultStyleUrl,
        );
        return _cached!;
      }
    } catch (_) {}
    return const MapConfig();
  }
}
