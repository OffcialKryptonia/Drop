import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../service/DriverApplicationApi.dart' show ApiFailure;
import '../service/RegionApi.dart';

/// Watches the phone's position and, when it crosses into another DROP region, asks the person to confirm
/// the change. Used by both the Passenger and Driver home screens.
class RegionWatcher {
  /// Regions the person said "Not now" to, so we do not ask again until the app restarts.
  static final Set<int> _declined = {};
  static bool _asking = false;

  LatLng? _lastAt;
  DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;
  int? _lastPolygonIndex;
  bool _hasPolygonSample = false;
  DateTime _lastBoundaryProbe = DateTime.fromMillisecondsSinceEpoch(0);

  /// Call with every position. Normal server checks remain throttled at ~700 m / 90 seconds;
  /// a reliable Mapbox GeoJSON boundary transition may request an earlier server check.
  Future<void> check(
    BuildContext context,
    LatLng here, {
    required VoidCallback onSwitched,
    List<List<LatLng>> regionBoundaries = const [],
    bool useMapboxGeometry = false,
    double accuracyMeters = double.infinity,
  }) async {
    if (_busy || _asking) return;
    final now = DateTime.now();
    var crossedBoundary = false;
    // Mapbox receives the same service-region GeoJSON used by the server. A reliable local
    // polygon transition (GPS accuracy <= 80m and within 100m of an edge) can request an
    // earlier server check; it can never authorise a region change by itself.
    if (useMapboxGeometry && regionBoundaries.isNotEmpty && accuracyMeters <= 80) {
      final candidate = RegionApi.containingPolygonIndex(here, regionBoundaries) ?? -1;
      crossedBoundary = _hasPolygonSample && candidate != _lastPolygonIndex &&
          RegionApi.isNearBoundary(here, regionBoundaries, withinMeters: 100) &&
          now.difference(_lastBoundaryProbe).inSeconds >= 20;
      _lastPolygonIndex = candidate;
      _hasPolygonSample = true;
      if (crossedBoundary) _lastBoundaryProbe = now;
    }
    final moved = _lastAt == null ? double.infinity : const Distance()(_lastAt!, here);
    final waited = now.difference(_lastCheck).inSeconds;
    if (moved < 700 && waited < 90 && !crossedBoundary) return;
    _busy = true;
    _lastAt = here;
    _lastCheck = DateTime.now();
    try {
      final r = await RegionApi.at(here.latitude, here.longitude);
      if (r['needs_confirm'] != true) return;
      final region = Map<String, dynamic>.from(r['region'] as Map);
      final id = (region['id'] as num).toInt();
      if (_declined.contains(id) || !context.mounted) return;
      final current = r['current'] is Map ? (r['current'] as Map)['name']?.toString() : null;
      final service = r['service'] is Map ? (r['service'] as Map)['name']?.toString() : null;
      final canSwitch = r['can_switch'] != false;
      _asking = true;
      final yes = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('You are now in ${region['name']}'),
          content: Text(!canSwitch
              ? '${region['name']} has no ride type that matches yours yet, so you cannot work there. You stay in ${current ?? 'your region'}.'
              : 'Ride types and prices depend on the region. Switch${current != null ? ' from $current' : ''} to ${region['name']}?${service != null ? '\n\nYou will drive as $service.' : ''}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(canSwitch ? (current != null ? 'Stay in $current' : 'Not now') : 'OK')),
            if (canSwitch) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Switch to ${region['name']}')),
          ],
        ),
      );
      _asking = false;
      if (yes != true) {
        _declined.add(id);
        return;
      }
      try {
        final s = await RegionApi.switchTo(id, here.latitude, here.longitude);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s['message']?.toString() ?? 'Region changed.')));
        onSwitched();
      } on ApiFailure catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      // Offline or the server is busy: try again at the next check.
    } finally {
      _asking = false;
      _busy = false;
    }
  }
}
