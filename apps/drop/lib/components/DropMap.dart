import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as g;
import 'package:latlong2/latlong.dart' as ll;

/// A pin on the map.
class DropMarker {
  final String id;
  final ll.LatLng point;
  final String title;
  final Color color;

  const DropMarker({required this.id, required this.point, this.title = '', this.color = Colors.red});
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
  final ll.LatLng initialCenter;
  final double initialZoom;
  final List<DropMarker> markers;
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
    this.initialZoom = 15,
    this.markers = const [],
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
  final fm.MapController _osm = fm.MapController();
  bool _osmReady = false;
  Timer? _idle;
  late ll.LatLng _center;

  bool get _isGoogle => widget.provider == 'google';

  @override
  void initState() {
    super.initState();
    _center = widget.initialCenter;
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(DropMap old) {
    super.didUpdateWidget(old);
    widget.controller?._state = this;
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
      } else if (_osmReady) {
        _osm.fitCamera(fm.CameraFit.bounds(bounds: fm.LatLngBounds(ll.LatLng(south, west), ll.LatLng(north, east)), padding: const EdgeInsets.all(80)));
      }
    } catch (_) {}
  }

  void _moved(ll.LatLng c) {
    _center = c;
    widget.onMove?.call(c);
    _idle?.cancel();
    if (!_isGoogle) _idle = Timer(const Duration(milliseconds: 450), () => widget.onIdle?.call(_center));
  }

  @override
  Widget build(BuildContext context) => _isGoogle ? _googleMap() : _osmMap();

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
      markers: {
        for (final m in widget.markers)
          g.Marker(
            markerId: g.MarkerId(m.id),
            position: g.LatLng(m.point.latitude, m.point.longitude),
            infoWindow: g.InfoWindow(title: m.title),
            icon: g.BitmapDescriptor.defaultMarkerWithHue(HSVColor.fromColor(m.color).hue),
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
        fm.MarkerLayer(markers: [
          for (final m in widget.markers)
            fm.Marker(point: m.point, width: 44, height: 44, alignment: Alignment.topCenter, child: Icon(Icons.location_pin, color: m.color, size: 40)),
        ]),
        fm.SimpleAttributionWidget(source: Text(widget.attribution)),
      ],
    );
  }
}
