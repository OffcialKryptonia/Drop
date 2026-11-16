import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import 'VehicleIcons.dart';

class DropMarker {
  final String id;
  final ll.LatLng point;
  final String title;
  final Color color;
  final String? iconKey;
  final double heading;
  const DropMarker({required this.id, required this.point, this.title = '', this.color = Colors.red, this.iconKey, this.heading = 0});
}

class DropMapController {
  _DropMapState? _state;
  void animateTo(ll.LatLng point, {double zoom = 17}) => _state?._animateTo(point, zoom);
  void followDriver(ll.LatLng point, {double zoom = 17.5, double bearing = 0, double pitch = 55}) => _state?._followDriver(point, zoom, bearing, pitch);
  void fitPoints(List<ll.LatLng> points) => _state?._fit(points);
}

/// Shared map renderer for Passenger and Driver modes: Google, MapLibre/OSM, or Mapbox.
class DropMap extends StatefulWidget {
  final String provider;
  final String tileUrl;
  final String attribution;
  final String styleUrl;
  final String mapboxStyleUri;
  final bool showRegionBorders;
  final List<List<ll.LatLng>> regionBoundaries;
  final ll.LatLng initialCenter;
  final double initialZoom;
  final List<DropMarker> markers;
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
    this.mapboxStyleUri = 'mapbox://styles/mapbox/streets-v12',
    this.showRegionBorders = false,
    this.regionBoundaries = const [],
    this.initialZoom = 17,
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
  mb.MapboxMap? _mapbox;
  mb.PointAnnotationManager? _mbPoints;
  mb.CircleAnnotationManager? _mbCircles;
  mb.PolylineAnnotationManager? _mbLines;
  mb.PolygonAnnotationManager? _mbPolygons;
  bool _mapboxStyleReady = false;
  bool _mapboxFailed = false;
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

  void _ensureIcons() {
    for (final m in widget.markers) {
      final key = m.iconKey;
      if (key == null || _icons.containsKey(key)) continue;
      VehicleIcons.load(key).then((bytes) {
        if (bytes == null || !mounted) return;
        setState(() => _icons[key] = bytes);
        if (_isMapLibre && _mapLibreStyleReady) _syncMapLibreMarkers();
        if (widget.provider == 'mapbox' && _mapboxStyleReady) _syncMapboxAnnotations();
      });
    }
  }

  @override
  void didUpdateWidget(DropMap old) {
    super.didUpdateWidget(old);
    widget.controller?._state = this;
    _ensureIcons();
    if (_isMapLibre && _mapLibreStyleReady && (old.markers != widget.markers || old.routePoints != widget.routePoints)) _syncMapLibreMarkers();
    if (widget.provider == 'mapbox' && _mapboxStyleReady &&
        (old.markers != widget.markers || old.routePoints != widget.routePoints || old.regionBoundaries != widget.regionBoundaries || old.showRegionBorders != widget.showRegionBorders)) {
      _syncMapboxAnnotations();
    }
    if (old.provider != widget.provider) {
      _mapboxFailed = false;
      _mapboxStyleReady = false;
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
      } else if (widget.provider == 'mapbox' && _mapboxFailed && _mapLibreReady) {
        _mapLibre?.animateCamera(ml.CameraUpdate.newLatLngZoom(ml.LatLng(p.latitude, p.longitude), zoom));
      } else if (widget.provider == 'mapbox' && !_mapboxFailed && _mapbox != null) {
        _mapbox!.flyTo(mb.CameraOptions(center: mb.Point(coordinates: mb.Position(p.longitude, p.latitude)), zoom: zoom), mb.MapAnimationOptions(duration: 650, startDelay: 0));
      } else if (_osmReady) {
        _osm.move(p, zoom);
      }
    } catch (_) {}
  }

  void _followDriver(ll.LatLng point, double zoom, double bearing, double pitch) {
    try {
      if (_isGoogle) {
        _google?.animateCamera(g.CameraUpdate.newCameraPosition(g.CameraPosition(target: g.LatLng(point.latitude, point.longitude), zoom: zoom, bearing: bearing, tilt: pitch)));
      } else if (_isMapLibre && _mapLibreReady) {
        _mapLibre?.animateCamera(ml.CameraUpdate.newCameraPosition(ml.CameraPosition(target: ml.LatLng(point.latitude, point.longitude), zoom: zoom, bearing: bearing, tilt: pitch)));
      } else if (widget.provider == 'mapbox' && _mapboxFailed && _mapLibreReady) {
        _mapLibre?.animateCamera(ml.CameraUpdate.newCameraPosition(ml.CameraPosition(target: ml.LatLng(point.latitude, point.longitude), zoom: zoom, bearing: bearing, tilt: pitch)));
      } else if (widget.provider == 'mapbox' && !_mapboxFailed && _mapbox != null) {
        _mapbox!.flyTo(mb.CameraOptions(center: mb.Point(coordinates: mb.Position(point.longitude, point.latitude)), zoom: zoom, bearing: bearing, pitch: pitch), mb.MapAnimationOptions(duration: 700, startDelay: 0));
      } else if (_osmReady) {
        _osm.move(point, zoom);
      }
    } catch (_) {}
  }

  void _fit(List<ll.LatLng> points) {
    if (points.isEmpty) return;
    final south = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final north = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final west = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final east = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    if (south == north && west == east) { _animateTo(points.first, 17); return; }
    final center = ll.LatLng((south + north) / 2, (west + east) / 2);
    final span = math.max((north - south).abs(), (east - west).abs());
    final zoom = span <= 0.01 ? 14.0 : span <= 0.05 ? 12.0 : span <= 0.2 ? 10.0 : 8.0;
    try {
      if (_isGoogle) {
        _google?.animateCamera(g.CameraUpdate.newLatLngBounds(g.LatLngBounds(southwest: g.LatLng(south, west), northeast: g.LatLng(north, east)), 80));
      } else if (_isMapLibre && _mapLibreReady) {
        _mapLibre?.animateCamera(ml.CameraUpdate.newLatLngZoom(ml.LatLng(center.latitude, center.longitude), zoom));
      } else if (widget.provider == 'mapbox' && _mapboxFailed && _mapLibreReady) {
        _mapLibre?.animateCamera(ml.CameraUpdate.newLatLngZoom(ml.LatLng(center.latitude, center.longitude), zoom));
      } else if (widget.provider == 'mapbox' && !_mapboxFailed && _mapbox != null) {
        _mapbox!.flyTo(mb.CameraOptions(center: mb.Point(coordinates: mb.Position(center.longitude, center.latitude)), zoom: zoom), mb.MapAnimationOptions(duration: 650, startDelay: 0));
      } else if (_osmReady) {
        _osm.fitCamera(fm.CameraFit.bounds(bounds: fm.LatLngBounds(ll.LatLng(south, west), ll.LatLng(north, east)), padding: const EdgeInsets.all(80)));
      }
    } catch (_) {}
  }

  void _moved(ll.LatLng c) {
    _center = c;
    widget.onMove?.call(c);
    _idle?.cancel();
    if (!_isGoogle && !_isMapLibre && (widget.provider != 'mapbox' || _mapboxFailed)) _idle = Timer(const Duration(milliseconds: 450), () => widget.onIdle?.call(_center));
  }

  @override
  Widget build(BuildContext context) {
    if (_isGoogle) return _googleMap();
    if (_isMapLibre) return _mapLibreMap();
    if (widget.provider == 'mapbox') {
      if (_mapboxFailed) return Stack(children: [_mapLibreMap(), const Positioned(left: 8, right: 8, bottom: 8, child: Material(color: Colors.black87, borderRadius: BorderRadius.all(Radius.circular(8)), child: Padding(padding: EdgeInsets.all(8), child: Text('Mapbox is unavailable. Showing OpenStreetMap instead.', style: TextStyle(color: Colors.white, fontSize: 12)))))]);
      return _mapboxMap();
    }
    return _osmMap();
  }

  Future<void> _onMapboxCreated(mb.MapboxMap map) async {
    _mapbox = map;
    try {
      _mbPolygons = await map.annotations.createPolygonAnnotationManager();
      _mbLines = await map.annotations.createPolylineAnnotationManager();
      _mbCircles = await map.annotations.createCircleAnnotationManager();
      _mbPoints = await map.annotations.createPointAnnotationManager();
      if (_mapboxStyleReady) await _syncMapboxAnnotations();
    } catch (_) {
      if (mounted) setState(() => _mapboxFailed = true);
    }
  }

  Future<void> _syncMapboxAnnotations() async {
    final map = _mapbox;
    final points = _mbPoints, circles = _mbCircles, lines = _mbLines, polygons = _mbPolygons;
    if (!_mapboxStyleReady || map == null || points == null || circles == null || lines == null || polygons == null) return;
    try {
      await points.deleteAll();
      await circles.deleteAll();
      await lines.deleteAll();
      await polygons.deleteAll();
      if (widget.showRegionBorders) {
        for (final ring in widget.regionBoundaries) {
          if (ring.length < 4) continue;
          final coordinates = ring.map((p) => mb.Position(p.longitude, p.latitude)).toList();
          if (coordinates.first.lng != coordinates.last.lng || coordinates.first.lat != coordinates.last.lat) coordinates.add(coordinates.first);
          await polygons.create(mb.PolygonAnnotationOptions(
            geometry: mb.Polygon(coordinates: [coordinates]),
            fillColor: const Color(0xFF1769AA).toARGB32(),
            fillOpacity: 0.08,
            fillOutlineColor: const Color(0xFF1769AA).toARGB32(),
          ));
        }
      }
      if (widget.routePoints.length > 1) {
        await lines.create(mb.PolylineAnnotationOptions(
          geometry: mb.LineString(coordinates: widget.routePoints.map((p) => mb.Position(p.longitude, p.latitude)).toList()),
          lineColor: const Color(0xFF1A73E8).toARGB32(),
          lineWidth: 5,
          lineOpacity: 0.9,
          lineJoin: mb.LineJoin.ROUND,
        ));
      }
      for (final marker in widget.markers) {
        final geometry = mb.Point(coordinates: mb.Position(marker.point.longitude, marker.point.latitude));
        final bytes = marker.iconKey == null ? null : _icons[marker.iconKey!];
        if (bytes != null) {
          await points.create(mb.PointAnnotationOptions(
            geometry: geometry,
            image: bytes,
            iconSize: VehicleIcons.logical / VehicleIcons.size,
            iconRotate: marker.heading,
            iconAnchor: mb.IconAnchor.CENTER,
          ));
        } else {
          await circles.create(mb.CircleAnnotationOptions(
            geometry: geometry,
            circleRadius: 8,
            circleColor: marker.color.toARGB32(),
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 2,
          ));
        }
      }
    } catch (_) {
      // A transient style reload can interrupt annotations; the style callback retries.
    }
  }

  Widget _mapboxMap() => mb.MapWidget(
    key: ValueKey('drop-mapbox-${widget.mapboxStyleUri}'),
    styleUri: widget.mapboxStyleUri,
    viewport: mb.CameraViewportState(
      center: mb.Point(coordinates: mb.Position(widget.initialCenter.longitude, widget.initialCenter.latitude)),
      zoom: widget.initialZoom,
    ),
    onMapCreated: _onMapboxCreated,
    onStyleLoadedListener: (_) { _mapboxStyleReady = true; _syncMapboxAnnotations(); },
    onCameraChangeListener: (event) {
      final c = event.cameraState.center.coordinates;
      _moved(ll.LatLng(c.lat.toDouble(), c.lng.toDouble()));
    },
    onMapIdleListener: (_) => widget.onIdle?.call(_center),
    onMapLoadErrorListener: (_) { if (mounted) setState(() => _mapboxFailed = true); },
  );

  String _colorHex(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  Future<void> _syncMapLibreMarkers() async {
    if (!_mapLibreStyleReady || _mapLibre == null) return;
    try {
      await _mapLibre!.clearLines();
      await _mapLibre!.clearCircles();
      await _mapLibre!.clearSymbols();
      if (widget.routePoints.length > 1) {
        await _mapLibre!.addLine(ml.LineOptions(geometry: [for (final p in widget.routePoints) ml.LatLng(p.latitude, p.longitude)], lineColor: '#1A73E8', lineWidth: 5, lineOpacity: 0.9, lineJoin: 'round'));
      }
      for (final marker in widget.markers) {
        final bytes = marker.iconKey == null ? null : _icons[marker.iconKey!];
        if (bytes != null) {
          final name = 'veh_${marker.iconKey}';
          if (_mlImages.add(name)) await _mapLibre!.addImage(name, bytes);
          await _mapLibre!.addSymbol(ml.SymbolOptions(geometry: ml.LatLng(marker.point.latitude, marker.point.longitude), iconImage: name, iconSize: VehicleIcons.logical / VehicleIcons.size, iconRotate: marker.heading, iconAnchor: 'center'));
        } else {
          await _mapLibre!.addCircle(ml.CircleOptions(geometry: ml.LatLng(marker.point.latitude, marker.point.longitude), circleRadius: 8, circleColor: _colorHex(marker.color), circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2));
        }
      }
    } catch (_) {}
  }

  Widget _mapLibreMap() => ml.MapLibreMap(
    styleString: widget.styleUrl,
    initialCameraPosition: ml.CameraPosition(target: ml.LatLng(widget.initialCenter.latitude, widget.initialCenter.longitude), zoom: widget.initialZoom),
    trackCameraPosition: true,
    onMapCreated: (controller) { _mapLibre = controller; _mapLibreReady = true; },
    onStyleLoadedCallback: () { _mapLibreStyleReady = true; _mlImages.clear(); _syncMapLibreMarkers(); },
    onCameraMove: (position) => _moved(ll.LatLng(position.target.latitude, position.target.longitude)),
    onCameraIdle: () => widget.onIdle?.call(_center),
  );

  Widget _googleMap() => g.GoogleMap(
    initialCameraPosition: g.CameraPosition(target: g.LatLng(widget.initialCenter.latitude, widget.initialCenter.longitude), zoom: widget.initialZoom),
    onMapCreated: (c) => _google = c,
    myLocationEnabled: widget.showMyLocation,
    myLocationButtonEnabled: false,
    zoomControlsEnabled: false,
    mapToolbarEnabled: false,
    onCameraMove: (p) => _moved(ll.LatLng(p.target.latitude, p.target.longitude)),
    onCameraIdle: () => widget.onIdle?.call(_center),
    polylines: {if (widget.routePoints.length > 1) g.Polyline(polylineId: const g.PolylineId('route'), points: [for (final p in widget.routePoints) g.LatLng(p.latitude, p.longitude)], color: const Color(0xFF1A73E8), width: 5, jointType: g.JointType.round, startCap: g.Cap.roundCap, endCap: g.Cap.roundCap)},
    markers: {for (final m in widget.markers) g.Marker(
      markerId: g.MarkerId(m.id), position: g.LatLng(m.point.latitude, m.point.longitude), infoWindow: g.InfoWindow(title: m.title),
      icon: m.iconKey != null && _icons[m.iconKey!] != null ? g.BitmapDescriptor.bytes(_icons[m.iconKey!]!, width: VehicleIcons.logical) : g.BitmapDescriptor.defaultMarkerWithHue(HSVColor.fromColor(m.color).hue),
      anchor: m.iconKey != null && _icons[m.iconKey!] != null ? const Offset(0.5, 0.5) : const Offset(0.5, 1.0),
      rotation: m.iconKey != null ? m.heading : 0, flat: m.iconKey != null, zIndexInt: m.iconKey != null ? 2 : 1,
    )},
  );

  Widget _osmMap() => fm.FlutterMap(
    mapController: _osm,
    options: fm.MapOptions(initialCenter: widget.initialCenter, initialZoom: widget.initialZoom, onMapReady: () => _osmReady = true, onPositionChanged: (camera, hasGesture) => _moved(camera.center)),
    children: [
      fm.TileLayer(urlTemplate: widget.tileUrl, userAgentPackageName: 'com.kryptonia.drop'),
      if (widget.routePoints.length > 1) fm.PolylineLayer(polylines: [fm.Polyline(points: widget.routePoints, strokeWidth: 5, color: const Color(0xFF1A73E8), strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round)]),
      fm.MarkerLayer(markers: [for (final m in widget.markers)
        if (m.iconKey != null && _icons[m.iconKey!] != null) fm.Marker(point: m.point, width: VehicleIcons.logical, height: VehicleIcons.logical, alignment: Alignment.center, child: Transform.rotate(angle: m.heading * math.pi / 180, child: Image.memory(_icons[m.iconKey!]!, gaplessPlayback: true)))
        else fm.Marker(point: m.point, width: 44, height: 44, alignment: Alignment.topCenter, child: Icon(Icons.location_pin, color: m.color, size: 40))]),
      fm.SimpleAttributionWidget(source: Text(widget.attribution)),
    ],
  );
}
