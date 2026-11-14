import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Where a point lands on a route line.
class RouteSnap {
  /// Index of the route point just before the snapped position.
  final int index;
  final LatLng point;
  final double meters;
  const RouteSnap(this.index, this.point, this.meters);
}

/// Small helpers for keeping a vehicle on its route line and clearing the part already driven.
class RouteGeometry {
  static const Distance _d = Distance();

  static double meters(LatLng a, LatLng b) => _d.as(LengthUnit.Meter, a, b);

  /// Compass bearing from a to b in degrees, 0 = north, clockwise.
  static double bearing(LatLng a, LatLng b) {
    final p1 = a.latitudeInRad, p2 = b.latitudeInRad;
    final dl = b.longitudeInRad - a.longitudeInRad;
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Nearest spot on the line to [p]. Works in a flat local plane, which is accurate at city scale.
  static RouteSnap? snap(List<LatLng> line, LatLng p) {
    if (line.length < 2) return null;
    final kx = math.cos(p.latitudeInRad) * 111320.0;
    const ky = 110540.0;
    RouteSnap? best;
    for (var i = 0; i < line.length - 1; i++) {
      final ax = (line[i].longitude - p.longitude) * kx, ay = (line[i].latitude - p.latitude) * ky;
      final bx = (line[i + 1].longitude - p.longitude) * kx, by = (line[i + 1].latitude - p.latitude) * ky;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      final t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      final px = ax + dx * t, py = ay + dy * t;
      final dist = math.sqrt(px * px + py * py);
      if (best == null || dist < best.meters) {
        best = RouteSnap(
          i,
          LatLng(line[i].latitude + (line[i + 1].latitude - line[i].latitude) * t, line[i].longitude + (line[i + 1].longitude - line[i].longitude) * t),
          dist,
        );
      }
    }
    return best;
  }

  /// The line from the snapped position to the end, so the part behind the vehicle disappears.
  static List<LatLng> remaining(List<LatLng> line, RouteSnap s) => [s.point, ...line.sublist(s.index + 1)];
}
