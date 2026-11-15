import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// The phone's real position and direction, smoothed so the map icon glides instead of jumping.
/// - Position: every GPS fix is a target; the shown point eases toward it about 12 times a second.
/// - Direction: GPS course while moving, the compass when slow or still, so the icon turns with the phone.
/// Listen to it (AnimatedBuilder) to redraw only the map.
class LiveLocation extends ChangeNotifier {
  /// Called for every real GPS fix (not every animation frame).
  final void Function(Position pos)? onFix;
  LiveLocation({this.onFix});

  LatLng? point;
  double heading = 0;
  LatLng? raw;
  double speed = 0;

  StreamSubscription<Position>? _gps;
  StreamSubscription<CompassEvent>? _compass;
  Timer? _tick;
  double _targetHeading = 0;
  double? _compassHeading;
  double? _course;
  bool _disposed = false;

  bool get running => _gps != null;

  void start({LatLng? seed}) {
    if (_gps != null) return;
    if (seed != null && point == null) {
      point = raw = seed;
      notifyListeners();
    }
    final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0, intervalDuration: const Duration(seconds: 1))
        : const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 1);
    _gps = Geolocator.getPositionStream(locationSettings: settings).listen(_onFix, onError: (_) {});
    try {
      _compass = FlutterCompass.events?.listen((e) {
        final h = e.heading;
        if (h != null) _compassHeading = (h + 360) % 360;
      }, onError: (_) {});
    } catch (_) {}
    _tick = Timer.periodic(const Duration(milliseconds: 80), (_) => _step());
  }

  void _onFix(Position p) {
    raw = LatLng(p.latitude, p.longitude);
    speed = p.speed < 0 ? 0 : p.speed;
    _course = p.speed > 1.5 && p.heading >= 0 ? p.heading : null;
    point ??= raw;
    onFix?.call(p);
  }

  void _step() {
    if (_disposed) return;
    final r = raw;
    if (r == null) return;
    var changed = false;

    // Direction: moving -> GPS course; otherwise the compass (the way the phone points).
    final want = _course ?? _compassHeading;
    if (want != null) _targetHeading = want;
    final diff = ((_targetHeading - heading + 540) % 360) - 180;
    if (diff.abs() > 0.5) {
      heading = (heading + diff * 0.3 + 360) % 360;
      changed = true;
    }

    // Position: glide toward the latest fix; jump if it is far away (first fix, or after a long gap).
    final p = point ?? r;
    final dLat = r.latitude - p.latitude, dLng = r.longitude - p.longitude;
    final meters = math.sqrt(dLat * dLat + dLng * dLng) * 111320;
    if (meters > 150) {
      point = r;
      changed = true;
    } else if (meters > 0.15) {
      point = LatLng(p.latitude + dLat * 0.3, p.longitude + dLng * 0.3);
      changed = true;
    } else if (meters > 0) {
      point = r;
    }
    if (changed) notifyListeners();
  }

  void stop() {
    _gps?.cancel();
    _gps = null;
    _compass?.cancel();
    _compass = null;
    _tick?.cancel();
    _tick = null;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
