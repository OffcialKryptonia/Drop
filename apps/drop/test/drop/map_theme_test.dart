import 'package:flutter_test/flutter_test.dart';
import 'package:drop/components/MapTheme.dart';
import 'package:drop/service/MapConfig.dart';

void main() {
  group('MapTheme.mapbox', () {
    test('light keeps the configured style', () {
      expect(MapTheme.mapbox(dark: false, lightUri: MapTheme.mapboxStreets), MapTheme.mapboxStreets);
    });
    test('dark maps known light styles to dark', () {
      expect(MapTheme.mapbox(dark: true, lightUri: MapTheme.mapboxStreets), MapTheme.mapboxDark);
      expect(MapTheme.mapbox(dark: true, lightUri: 'mapbox://styles/mapbox/navigation-day-v1'), 'mapbox://styles/mapbox/navigation-night-v1');
    });
    test('custom style stays unless admin supplies a dark one', () {
      const custom = 'mapbox://styles/acme/custom';
      expect(MapTheme.mapbox(dark: true, lightUri: custom), custom);
      expect(MapTheme.mapbox(dark: true, lightUri: custom, darkUri: 'mapbox://styles/acme/night'), 'mapbox://styles/acme/night');
    });
    test('switching back restores light', () {
      expect(MapTheme.mapbox(dark: false, lightUri: MapTheme.mapboxStreets, darkUri: 'mapbox://styles/acme/night'), MapTheme.mapboxStreets);
    });
  });
  group('MapTheme.maplibre', () {
    const dark = 'https://api.example.com/map-styles/drop-dark.json';
    test('uses the hosted dark style in dark mode only', () {
      expect(MapTheme.maplibre(dark: true, lightUrl: MapTheme.libertyStyle, darkUrl: dark), dark);
      expect(MapTheme.maplibre(dark: false, lightUrl: MapTheme.libertyStyle, darkUrl: dark), MapTheme.libertyStyle);
    });
    test('no dark style configured leaves light style (never an invented URL)', () {
      expect(MapTheme.maplibre(dark: true, lightUrl: MapTheme.libertyStyle), MapTheme.libertyStyle);
      expect(MapTheme.hasDarkStyle(lightUrl: MapTheme.libertyStyle), false);
    });
  });
  test('MapConfig parses dark style fields', () {
    final c = MapConfig.fromApiResponse({
      'provider': 'maplibre',
      'maplibre_dark_style_url': 'https://x.dev/map-styles/drop-dark.json',
      'mapbox_dark_style_uri': 'mapbox://styles/a/b',
    });
    expect(c.darkStyleUrl, 'https://x.dev/map-styles/drop-dark.json');
    expect(c.mapboxDarkStyleUri, 'mapbox://styles/a/b');
    expect(MapConfig.fromApiResponse({}).darkStyleUrl, '');
  });
}
