import 'package:latlong2/latlong.dart';

import 'DriverApplicationApi.dart';

/// Fetches the road line between two points from DROP's server, for drawing on the map.
class RouteLineApi {
  static final Map<String, List<LatLng>> _cache = {};

  static String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)}>${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}';

  /// Returns the line, or an empty list when it cannot be loaded (the map then just shows the pins).
  static Future<List<LatLng>> fetch(LatLng from, LatLng to) async {
    final key = _key(from, to);
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final res = await DriverApplicationApi.getJson('/route/line?from=${from.latitude},${from.longitude}&to=${to.latitude},${to.longitude}');
      final raw = res['points'];
      if (raw is! List) return const [];
      final pts = <LatLng>[
        for (final p in raw)
          if (p is List && p.length >= 2) LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ];
      if (pts.length > 1) _cache[key] = pts;
      return pts;
    } catch (_) {
      return const [];
    }
  }
}
