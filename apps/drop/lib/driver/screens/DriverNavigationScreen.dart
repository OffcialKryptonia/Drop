import 'dart:async';

import 'package:drop/components/DropMap.dart';
import 'package:drop/components/LiveLocation.dart';
import 'package:drop/components/RouteGeometry.dart';
import 'package:drop/driver/services/DriverDirectionsApi.dart';
import 'package:drop/service/MapConfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Full-screen, high-visibility in-app navigation for an active driver leg.
/// Location updates are foreground-only and use the same permissions as Driver mode.
class DriverNavigationScreen extends StatefulWidget {
  final MapConfig mapConfig;
  final LatLng destination;
  final String destinationLabel;
  final LatLng? initialPosition;

  const DriverNavigationScreen({
    super.key,
    required this.mapConfig,
    required this.destination,
    required this.destinationLabel,
    this.initialPosition,
  });

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  final DropMapController _map = DropMapController();
  final FlutterTts _tts = FlutterTts();
  final Set<String> _spokenCues = <String>{};
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _position;
  DriverDirectionsRoute? _route;
  int _maneuverIndex = 0;
  bool _loading = true;
  bool _rerouting = false;
  String? _error;
  DateTime _lastRouteRequest = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCameraUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    _configureVoice();
    _loadRoute();
    _startLocation();
  }

  Future<void> _configureVoice() async {
    try {
      await _tts.setLanguage('en-NG');
      await _tts.setSpeechRate(0.46);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {
      try { await _tts.setLanguage('en-US'); } catch (_) {}
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5),
      ).listen(_onPosition, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _loadRoute({bool reroute = false}) async {
    final origin = _position ?? widget.initialPosition;
    if (origin == null) {
      if (mounted) setState(() { _loading = false; _error = 'Waiting for your GPS location. Turn on location and try again.'; });
      return;
    }
    if (reroute && DateTime.now().difference(_lastRouteRequest).inSeconds < 15) return;
    _lastRouteRequest = DateTime.now();
    if (mounted) setState(() { _loading = true; _rerouting = reroute; _error = null; });
    try {
      final route = await DriverDirectionsRoute.fetch(
        origin: origin,
        destination: widget.destination,
        publicToken: widget.mapConfig.mapboxPublicToken,
      );
      if (!mounted) return;
      setState(() { _route = route; _maneuverIndex = 0; _loading = false; _rerouting = false; _error = null; });
      _map.fitPoints(route.points);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _rerouting = false; _error = e.toString().replaceFirst('FormatException: ', ''); });
    }
  }

  double _distanceToNextTurn(LatLng here, DriverDirectionsRoute route) {
    final nextIndex = (_maneuverIndex + 1).clamp(0, route.maneuvers.length - 1);
    return RouteGeometry.meters(here, route.maneuvers[nextIndex].location);
  }

  double _routeBearing(LatLng here, DriverDirectionsRoute route) {
    final snap = RouteGeometry.snap(route.points, here);
    final next = ((snap?.index ?? 0) + 1).clamp(0, route.points.length - 1);
    return RouteGeometry.bearing(here, route.points[next]);
  }

  Future<void> _speakUpcomingTurn(LatLng here, DriverDirectionsRoute route) async {
    if (route.maneuvers.isEmpty || _maneuverIndex + 1 >= route.maneuvers.length) return;
    final nextIndex = _maneuverIndex + 1;
    final meters = _distanceToNextTurn(here, route);
    final threshold = meters <= 160 ? 160 : meters <= 550 ? 550 : 0;
    if (threshold == 0) return;
    final cue = '$nextIndex-$threshold';
    if (!_spokenCues.add(cue)) return;
    final instruction = route.maneuvers[nextIndex].instruction;
    try {
      await _tts.stop();
      await _tts.speak(threshold == 550 ? 'In 500 metres, $instruction' : 'In 150 metres, $instruction');
    } catch (_) {}
  }

  void _onPosition(Position position) {
    final here = LatLng(position.latitude, position.longitude);
    if (!mounted) return;
    setState(() => _position = here);
    final route = _route;
    if (route == null) return;
    final snap = RouteGeometry.snap(route.points, here);
    if (snap != null && snap.meters > 65) {
      _loadRoute(reroute: true);
      return;
    }
    if (snap != null) {
      var next = _maneuverIndex;
      // Maneuver coordinates mark the start of each step. Advance only when
      // the vehicle reaches the NEXT step, not when it remains near the last one.
      while (next + 1 < route.maneuvers.length &&
          RouteGeometry.meters(here, route.maneuvers[next + 1].location) < 35) {
        next++;
      }
      if (next != _maneuverIndex) setState(() => _maneuverIndex = next);
      _speakUpcomingTurn(here, route);
    }
    if (DateTime.now().difference(_lastCameraUpdate).inMilliseconds > 900) {
      _lastCameraUpdate = DateTime.now();
      final heading = position.speed >= 2 && position.heading >= 0 ? position.heading : _routeBearing(here, route);
      _map.followDriver(here, zoom: 17.5, bearing: heading, pitch: 55);
    }
  }

  String _distance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.round()} m';

  double get _remainingMeters {
    final route = _route;
    if (route == null || _position == null) return route?.distanceMeters ?? 0;
    final snap = RouteGeometry.snap(route.points, _position!);
    if (snap == null) return route.distanceMeters;
    final points = RouteGeometry.remaining(route.points, snap);
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) { total += RouteGeometry.meters(points[i], points[i + 1]); }
    return total;
  }

  String _duration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} hr ${minutes % 60} min';
  }

  List<LatLng> get _remainingRoute {
    final route = _route;
    if (route == null) return const [];
    final position = _position;
    if (position == null) return route.points;
    final snap = RouteGeometry.snap(route.points, position);
    return snap == null || snap.meters > 80 ? route.points : RouteGeometry.remaining(route.points, snap);
  }

  List<DropMarker> get _markers => [
    if (_position != null) DropMarker(id: 'driver', title: 'You', point: _position!, color: Colors.blue),
    DropMarker(id: 'destination', title: widget.destinationLabel, point: widget.destination, color: Colors.red),
  ];

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final maneuver = route == null || route.maneuvers.isEmpty
        ? null
        : route.maneuvers[(_maneuverIndex + 1).clamp(0, route.maneuvers.length - 1)];
    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: Stack(children: [
        Positioned.fill(
          child: DropMap(
            provider: widget.mapConfig.provider,
            tileUrl: widget.mapConfig.tileUrl,
            attribution: widget.mapConfig.attribution,
            styleUrl: widget.mapConfig.styleUrl,
            mapboxStyleUri: widget.mapConfig.mapboxStyleUri,
            initialCenter: _position ?? widget.destination,
            initialZoom: 16,
            controller: _map,
            markers: _markers,
            routePoints: _remainingRoute,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Material(
                color: const Color(0xFF111C25),
                borderRadius: BorderRadius.circular(18),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: const Color(0xFF263B4B), borderRadius: BorderRadius.circular(14)),
                      child: Icon(_maneuverIcon(maneuver?.modifier ?? maneuver?.type ?? ''), color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_loading ? (_rerouting ? 'Recalculating route…' : 'Finding route…') : (maneuver?.instruction ?? 'Follow the highlighted route'),
                        style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                      if (maneuver != null && maneuver.roadName.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(maneuver.roadName, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                      if (route != null && route.maneuvers.length > _maneuverIndex + 1 && _position != null)
                        Padding(padding: const EdgeInsets.only(top: 5), child: Text('Next turn in ${_distance(_distanceToNextTurn(_position!, route))}', style: const TextStyle(color: Color(0xFF8CC8FF), fontSize: 14, fontWeight: FontWeight.w700))),
                      if (_error != null)
                        Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 13))),
                    ])),
                    IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close, color: Colors.white)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Material(
                color: const Color(0xFF111C25),
                borderRadius: BorderRadius.circular(20),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(child: _metric('DISTANCE LEFT', route == null ? '—' : _distance(_remainingMeters), Icons.route)),
                      Expanded(child: _metric('EST. TIME', route == null ? '—' : _duration(route.durationSeconds * (_remainingMeters / (route.distanceMeters <= 0 ? 1 : route.distanceMeters)).clamp(0.0, 1.0)), Icons.schedule)),
                      Expanded(child: _metric('DESTINATION', widget.destinationLabel, Icons.flag_outlined)),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38), padding: const EdgeInsets.symmetric(vertical: 13)),
                        onPressed: _loading ? null : () => _loadRoute(reroute: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recalculate'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2676D2), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
                        onPressed: () { if (_position != null) _map.animateTo(_position!, zoom: 17); },
                        icon: const Icon(Icons.my_location),
                        label: const Text('Recenter'),
                      )),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
        if (_loading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
      ]),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.lightBlueAccent, size: 18),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: .5)),
      const SizedBox(height: 3),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  IconData _maneuverIcon(String kind) {
    final value = kind.toLowerCase();
    if (value.contains('left')) return Icons.turn_left;
    if (value.contains('right')) return Icons.turn_right;
    if (value.contains('uturn')) return Icons.u_turn_left;
    if (value.contains('roundabout')) return Icons.roundabout_left;
    if (value.contains('arrive')) return Icons.flag;
    return Icons.straight;
  }
}
