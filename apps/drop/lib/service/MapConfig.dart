import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxOptions;

import '../components/VehicleIcons.dart';
import '../utils/Constants.dart';

/// Runtime map provider configuration supplied by the Drop Admin Panel.
class MapConfig {
  final String provider;
  final String tileUrl;
  final String attribution;
  final String styleUrl;
  final String mapboxStyleUri;
  final String mapboxPublicToken;
  final bool mapboxRegionBorderingEnabled;
  final String? fallbackReason;

  const MapConfig({
    this.provider = 'maplibre',
    this.tileUrl = defaultTileUrl,
    this.attribution = '© OpenStreetMap contributors',
    this.styleUrl = defaultStyleUrl,
    this.mapboxStyleUri = defaultMapboxStyleUri,
    this.mapboxPublicToken = '',
    this.mapboxRegionBorderingEnabled = false,
    this.fallbackReason,
  });

  static const String defaultTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String defaultStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
  static const String defaultMapboxStyleUri = 'mapbox://styles/mapbox/streets-v12';

  bool get isGoogle => provider == 'google';
  bool get isMapLibre => provider == 'maplibre';
  bool get isMapbox => provider == 'mapbox';

  static MapConfig fromApiResponse(Map body) {
    final tile = body['osm_tile_url']?.toString() ?? '';
    final token = body['mapbox_public_token']?.toString() ?? '';
    final requestedProvider = body['provider']?.toString();
    final provider = requestedProvider == 'google'
        ? 'google'
        : requestedProvider == 'mapbox' && token.startsWith('pk.')
            ? 'mapbox'
            : 'maplibre';
    return MapConfig(
      provider: provider,
      tileUrl: tile.contains('{z}') ? tile : defaultTileUrl,
      attribution: body['attribution']?.toString() ?? '© OpenStreetMap contributors',
      styleUrl: body['maplibre_style_url']?.toString().startsWith('https://') == true ? body['maplibre_style_url'].toString() : defaultStyleUrl,
      mapboxStyleUri: body['mapbox_style_uri']?.toString().startsWith('mapbox://styles/') == true ? body['mapbox_style_uri'].toString() : defaultMapboxStyleUri,
      mapboxPublicToken: provider == 'mapbox' ? token : '',
      mapboxRegionBorderingEnabled: body['mapbox_region_bordering_enabled'] == true,
      fallbackReason: body['mapbox_fallback_reason']?.toString(),
    );
  }

  static MapConfig? _cached;

  static Future<MapConfig> load({bool refresh = false}) async {
    if (!refresh && _cached != null) return _cached!;
    try {
      final r = await http.get(Uri.parse('${mBaseUrl}map-config'), headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 8));
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      if (r.statusCode == 200 && body is Map) {
        final tile = body['osm_tile_url']?.toString() ?? '';
        _cached = fromApiResponse(body);
        if (_cached!.isMapbox) MapboxOptions.setAccessToken(_cached!.mapboxPublicToken);
        final icons = body['vehicle_icons'];
        VehicleIcons.configure(icons is Map ? {for (final e in icons.entries) e.key.toString(): e.value.toString()} : const {});
        return _cached!;
      }
    } catch (_) {}
    return const MapConfig();
  }

  static void clearCache() => _cached = null;
}
