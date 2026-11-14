import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'VehicleIcons.dart';

/// A pin on the map.
class DropMarker {
  final String id;
  final ll.LatLng point;
  final String title;
  final Color color;

  /// When set, the marker is drawn as this vehicle picture (see VehicleIcons) instead of a pin.
  final String? iconKey;

  /// Which way the vehicle faces, in degrees clockwise from north.
  final double heading;

  const DropMarker({required this.id, required this.point, this.title = '', this.color = Colors.red, this.iconKey, this.heading = 0});
}

/// Moves the map without the screen caring which map service is underneath.
class DropMapController {
  _DropMapState? _state;

  void animateTo(ll.LatLng point, {double zoom = 15}) => _state?._animateTo(point, zoom);

  /// Zooms so all points are visible.
  void fitPoints(List<ll.LatLng> points) => _state?._fit(points);
}

/// One map widget for the whole app: Google Maps or OpenStreetMap, chosen by the admin (see MapConfig).
/// Both look and behave the same to the screens that use it.
class DropMap extends StatefulWidget {
  /// 'google' or 'osm'.
  final String provider;
  final String tileUrl;
  final String attribution;
  final String styleUrl;
  final ll.LatLng initialCenter;
  final double initialZoom;
  final List<DropMarker> markers;
  /// Road line to draw (pickup to drop-off). Empty means no line.
  final List<ll.LatLng> routePoints;
  final bool showMyLocation;
  final void Function(ll.LatLng center)? onMove;
  final void Function(ll.LatLng center)? onIdle;
  final DropMapController? controller;

  const DropMap({
    Key? key,
    required this.provider,
    required this.tileUrl,
    required this.initialCenter,
    this.attribution = '© OpenStreetMap contributors',
    this.styleUrl = 'https://tiles.openfreemap.org/styles/liberty',
    this.initialZoom = 15,
    this.markers = const [],
    this.routePoints = const [],
    this.showMyLocation = false,
    this.onMove,
    this.onIdle,
    this.controller,
  }) : super(key: key);

  @override
  State<DropMap> createState() => _DropMapState();
}

class _DropMapState extends State<DropMap> {
  g.GoogleMapController? _google;
  ml.MapLibreMapController? _mapLibre;
  bool _mapLibreReady = false;
  bool _mapLibreStyleReady = false;
  final fm.MapController _osm = fm.MapController();
  bool _osmReady = false;
  Timer? _idle;
  final Map<String, Uint8List> _icons = {};
  final Set<String> _mlImages = {};
  late ll.LatLng _center;

  bool get _isGoogle => widget.provider == 'google';
  bool get _isMapLibre => widget.provider == 'maplibre';

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
    widget.controller?._state = this;
    _ensureIcons();
  }

  /// Loads every vehicle picture the markers need, once, then redraws.
  void _ensureIcons() {
    for (final m in widget.markers) {
      final key = m.iconKey;
      if (key == null || _icons.containsKey(key)) continue;
      VehicleIcons.load(key).then((bytes) {
        if (bytes == null || !mounted) return;
        setState(() => _icons[key] = bytes);
        if (_isMapLibre && _mapLibreStyleReady) _syncMapLibreMarkers();
      });
    }
  }

  @override
  void didUpdateWidget(DropMap old) {
    super.didUpdateWidget(old);
    widget.controller?._state = this;
    _ensureIcons();
    if (_isMapLibre && _mapLibreStyleReady && (old.markers != widget.markers || old.routePoints != widget.routePoints)) {
      _syncMapLibreMarkers();
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    if (widget.controller?._state == this) widget.controller?._state = null;
    super.dispose();
  }

  void _animateTo(ll.LatLng p, double zoom) {
    try {
      if (_isGoogle) {
        _google?.animateCamera(g.CameraUpdate.newLatLngZoom(g.LatLng(p.latitude, p.longitude), zoom));
      } else if (_isMapLibre && _mapLibreReady) {
        _mapLibre?.animateCamera(ml.CameraUpdate.newLatLngZoom(ml.LatLng(p.latitude, p.longitude), zoom));
      } else if (_osmReady) {
        _osm.move(p, zoom);
      }
    } catch (_) {}
  }

  void _fit(List<ll.LatLng> points) {
    if (points.isEmpty) return;
    final south = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final north = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final west = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final east = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    if (south == north && west == east) {
      _animateTo(points.first, 15);
      return;
    }
    try {
      if (_isGoogle) {
        _google?.animateCamera(g.CameraUpdate.newLatLngBounds(g.LatLngBounds(southwest: g.LatLng(south, west), northeast: g.LatLng(north, east)), 80));
      } else if (_isMapLibre && _mapLibreReady) {
        final center = ll.LatLng((south + north) / 2, (west + east) / 2);
        final span = (north - south).abs() > (east - west).abs() ? (north - south).abs() : (east - west).abs();
        final zoom = span <= 0.01 ? 14.0 : (span <= 0.05 ? 12.0 : (span <= 0.2 ? 10.0 : 8.0));
        _mapLibre?.animateCamera(ml.CameraUpdate.newLatLngZoom(ml.LatLng(center.latitude, center.longitude), zoom));
      } else if (_osmReady) {
        _osm.fitCamera(fm.CameraFit.bounds(bounds: fm.LatLngBounds(ll.LatLng(south, west), ll.LatLng(north, east)), padding: const EdgeInsets.all(80)));
      }
    } catch (_) {}
  }

  void _moved(ll.LatLng c) {
    _center = c;
    widget.onMove?.call(c);
    _idle?.cancel();
    if (!_isGoogle && !_isMapLibre) _idle = Timer(const Duration(milliseconds: 450), () => widget.onIdle?.call(_center));
  }

  @override
  Widget build(BuildContext context) {
    if (_isGoogle) return _googleMap();
    if (_isMapLibre) return _mapLibreMap();
    return _osmMap();
  }

  String _colorHex(Color color) => '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';

  Future<void> _syncMapLibreMarkers() async {
    if (!_mapLibreStyleReady || _mapLibre == null) return;
    try {
      await _mapLibre!.clearLines();
      await _mapLibre!.clearCircles();
      await _mapLibre!.clearSymbols();
      if (widget.routePoints.length > 1) {
        await _mapLibre!.addLine(ml.LineOptions(
          geometry: [for (final p in widget.routePoints) ml.LatLng(p.latitude, p.longitude)],
          lineColor: '#1A73E8',
          lineWidth: 5,
          lineOpacity: 0.9,
          lineJoin: 'round',
        ));
      }
      for (final marker in widget.markers) {
        final bytes = marker.iconKey == null ? null : _icons[marker.iconKey!];
        if (bytes != null) {
          final name = 'veh_${marker.iconKey}';
          if (_mlImages.add(name)) await _mapLibre!.addImage(name, bytes);
          await _mapLibre!.addSymbol(ml.SymbolOptions(
            geometry: ml.LatLng(marker.point.latitude, marker.point.longitude),
            iconImage: name,
            iconSize: 0.5,
            iconRotate: marker.heading,
            iconAnchor: 'center',
          ));
          continue;
        }
        await _mapLibre!.addCircle(ml.CircleOptions(
          geometry: ml.LatLng(marker.point.latitude, marker.point.longitude),
          circleRadius: 8,
          circleColor: _colorHex(marker.color),
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ));
      }
    } catch (_) {
      // A style reload can temporarily make annotations unavailable; the next style callback retries.
    }
  }

  Widget _mapLibreMap() {
    return ml.MapLibreMap(
      styleString: widget.styleUrl,
      initialCameraPosition: ml.CameraPosition(
        target: ml.LatLng(widget.initialCenter.latitude, widget.initialCenter.longitude),
        zoom: widget.initialZoom,
      ),
      trackCameraPosition: true,
      onMapCreated: (controller) {
        _mapLibre = controller;
        _mapLibreReady = true;
      },
      onStyleLoadedCallback: () {
        _mapLibreStyleReady = true;
        _mlImages.clear();
        _syncMapLibreMarkers();
      },
      onCameraMove: (position) => _moved(ll.LatLng(position.target.latitude, position.target.longitude)),
      onCameraIdle: () => widget.onIdle?.call(_center),
    );
  }

  Widget _googleMap() {
    return g.GoogleMap(
      initialCameraPosition: g.CameraPosition(target: g.LatLng(widget.initialCenter.latitude, widget.initialCenter.longitude), zoom: widget.initialZoom),
      onMapCreated: (c) => _google = c,
      myLocationEnabled: widget.showMyLocation,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onCameraMove: (p) => _moved(ll.LatLng(p.target.latitude, p.target.longitude)),
      onCameraIdle: () => widget.onIdle?.call(_center),
      polylines: {
        if (widget.routePoints.length > 1)
          g.Polyline(
            polylineId: const g.PolylineId('route'),
            points: [for (final p in widget.routePoints) g.LatLng(p.latitude, p.longitude)],
            color: const Color(0xFF1A73E8),
            width: 5,
            jointType: g.JointType.round,
            startCap: g.Cap.roundCap,
            endCap: g.Cap.roundCap,
          ),
      },
      markers: {
        for (final m in widget.markers)
          g.Marker(
            markerId: g.MarkerId(m.id),
            position: g.LatLng(m.point.latitude, m.point.longitude),
            infoWindow: g.InfoWindow(title: m.title),
            icon: m.iconKey != null && _icons[m.iconKey!] != null
                ? g.BitmapDescriptor.bytes(_icons[m.iconKey!]!, width: VehicleIcons.size / 2)
                : g.BitmapDescriptor.defaultMarkerWithHue(HSVColor.fromColor(m.color).hue),
            anchor: m.iconKey != null && _icons[m.iconKey!] != null ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
            rotation: m.iconKey != null ? m.heading : 0,
            flat: m.iconKey != null,
            zIndexInt: m.iconKey != null ? 2 : 1,
          ),
      },
    );
  }

  Widget _osmMap() {
    return fm.FlutterMap(
      mapController: _osm,
      options: fm.MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        onMapReady: () => _osmReady = true,
        onPositionChanged: (camera, hasGesture) => _moved(camera.center),
      ),
      children: [
        fm.TileLayer(urlTemplate: widget.tileUrl, userAgentPackageName: 'com.kryptonia.drop'),
        if (widget.routePoints.length > 1)
          fm.PolylineLayer(polylines: [fm.Polyline(points: widget.routePoints, strokeWidth: 5, color: const Color(0xFF1A73E8), strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round)]),
        fm.MarkerLayer(markers: [
          for (final m in widget.markers)
            if (m.iconKey != null && _icons[m.iconKey!] != null)
              fm.Marker(
                point: m.point,
                width: VehicleIcons.size / 2,
                height: VehicleIcons.size / 2,
                alignment: Alignment.center,
                child: Transform.rotate(angle: m.heading * math.pi / 180, child: Image.memory(_icons[m.iconKey!]!, gaplessPlayback: true)),
              )
            else
              fm.Marker(point: m.point, width: 44, height: 44, alignment: Alignment.topCenter, child: Icon(Icons.location_pin, color: m.color, size: 40)),
        ]),
        fm.SimpleAttributionWidget(source: Text(widget.attribution)),
      ],
    );
  }
}
