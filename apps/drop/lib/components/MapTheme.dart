/// Pure light/dark map style resolution, shared by every map provider.
///
/// Kept free of Flutter and plugin imports so it can be unit-tested without a device.
class MapTheme {
  MapTheme._();

  static const String mapboxStreets = 'mapbox://styles/mapbox/streets-v12';
  static const String mapboxDark = 'mapbox://styles/mapbox/dark-v11';
  static const String libertyStyle = 'https://tiles.openfreemap.org/styles/liberty';

  /// Known Mapbox light styles and their dark counterparts. Any other (custom) style is left alone unless
  /// the admin configured an explicit dark style.
  static const Map<String, String> _mapboxPairs = {
    'mapbox://styles/mapbox/streets-v12': 'mapbox://styles/mapbox/dark-v11',
    'mapbox://styles/mapbox/streets-v11': 'mapbox://styles/mapbox/dark-v10',
    'mapbox://styles/mapbox/light-v11': 'mapbox://styles/mapbox/dark-v11',
    'mapbox://styles/mapbox/light-v10': 'mapbox://styles/mapbox/dark-v10',
    'mapbox://styles/mapbox/outdoors-v12': 'mapbox://styles/mapbox/dark-v11',
    'mapbox://styles/mapbox/navigation-day-v1': 'mapbox://styles/mapbox/navigation-night-v1',
    'mapbox://styles/mapbox/navigation-preview-day-v4': 'mapbox://styles/mapbox/navigation-preview-night-v4',
    'mapbox://styles/mapbox/navigation-guidance-day-v4': 'mapbox://styles/mapbox/navigation-guidance-night-v4',
  };

  static String mapbox({required bool dark, required String lightUri, String darkUri = ''}) {
    if (!dark) return lightUri;
    if (darkUri.startsWith('mapbox://styles/')) return darkUri;
    return _mapboxPairs[lightUri] ?? lightUri;
  }

  /// MapLibre/OpenFreeMap. The default Liberty style swaps to the DROP dark style hosted by the backend;
  /// a custom light style is respected unless Admin supplies a dark style.
  static String maplibre({required bool dark, required String lightUrl, String darkUrl = ''}) {
    if (!dark) return lightUrl;
    if (darkUrl.startsWith('https://')) return darkUrl;
    return lightUrl;
  }

  /// True when dark mode would change the style for this provider/config (so the map really goes dark).
  static bool hasDarkStyle({required String lightUrl, String darkUrl = ''}) => darkUrl.startsWith('https://') && darkUrl != lightUrl;
}
