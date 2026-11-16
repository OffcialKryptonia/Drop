import 'package:flutter_test/flutter_test.dart';
import 'package:drop/service/MapConfig.dart';

void main() {
  group('MapConfig.fromApiResponse', () {
    test('selects Mapbox only when a public token is supplied', () {
      final config = MapConfig.fromApiResponse({
        'provider': 'mapbox',
        'mapbox_public_token': 'pk.test-public-token',
        'mapbox_style_uri': 'mapbox://styles/acme/drop-style',
        'mapbox_region_bordering_enabled': true,
      });
      expect(config.provider, 'mapbox');
      expect(config.isMapbox, isTrue);
      expect(config.mapboxPublicToken, 'pk.test-public-token');
      expect(config.mapboxStyleUri, 'mapbox://styles/acme/drop-style');
      expect(config.mapboxRegionBorderingEnabled, isTrue);
    });

    test('falls back to MapLibre when a Mapbox token is missing', () {
      final config = MapConfig.fromApiResponse({'provider': 'mapbox'});
      expect(config.provider, 'maplibre');
      expect(config.mapboxPublicToken, isEmpty);
    });

    test('preserves Google Maps and OSM/MapLibre selection', () {
      expect(MapConfig.fromApiResponse({'provider': 'google'}).provider, 'google');
      expect(MapConfig.fromApiResponse({'provider': 'osm'}).provider, 'maplibre');
    });

    test('rejects an invalid Mapbox style URI in favour of the default', () {
      final config = MapConfig.fromApiResponse({
        'provider': 'mapbox',
        'mapbox_public_token': 'pk.test',
        'mapbox_style_uri': 'https://example.com/style.json',
      });
      expect(config.mapboxStyleUri, MapConfig.defaultMapboxStyleUri);
    });
  });
}
