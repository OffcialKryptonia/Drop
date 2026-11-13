import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../service/MapConfig.dart';

/// Downloads the visible area around the driver's current location for offline map viewing.
/// This stores map tiles only; ride requests, tracking and payments still require connectivity.
class OfflineMapsScreen extends StatefulWidget {
  const OfflineMapsScreen({Key? key}) : super(key: key);

  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends State<OfflineMapsScreen> {
  bool _loading = true;
  bool _downloading = false;
  double _progress = 0;
  String? _message;
  List<ml.OfflineRegion> _regions = [];
  String _styleUrl = MapConfig.defaultStyleUrl;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    if (kIsWeb) {
      if (mounted) setState(() {
        _loading = false;
        _message = 'Offline map downloads are available on Android and iOS only.';
      });
      return;
    }
    try {
      final config = await MapConfig.load();
      final regions = await ml.getListOfRegions();
      if (!mounted) return;
      setState(() {
        _styleUrl = config.styleUrl;
        _regions = regions;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _message = 'Could not read saved maps: $e';
      });
    }
  }

  Future<void> _downloadNearbyArea() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _message = 'Getting your location…';
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to select the area around you.');
      }
      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      const radius = 0.10; // Roughly an 11 km radius; keeps the download manageable.
      final south = math.max(-85.0, position.latitude - radius);
      final north = math.min(85.0, position.latitude + radius);
      final west = math.max(-180.0, position.longitude - radius);
      final east = math.min(180.0, position.longitude + radius);
      final definition = ml.OfflineRegionDefinition(
        bounds: ml.LatLngBounds(
          southwest: ml.LatLng(south, west),
          northeast: ml.LatLng(north, east),
        ),
        minZoom: 9,
        maxZoom: 14,
        mapStyleUrl: _styleUrl,
        includeIdeographs: false,
      );
      if (mounted) setState(() => _message = 'Downloading nearby map…');
      await ml.downloadOfflineRegion(
        definition,
        metadata: {
          'name': 'Nearby area',
          'latitude': position.latitude,
          'longitude': position.longitude,
          'savedAt': DateTime.now().toIso8601String(),
        },
        onEvent: (status) {
          if (!mounted) return;
          if (status is ml.InProgress) {
            final total = status.requiredResourceCount;
            final completed = status.completedResourceCount;
            setState(() => _progress = total > 0 ? completed / total : 0);
          } else if (status is ml.Success) {
            setState(() {
              _progress = 1;
              _message = 'Map download completed.';
            });
          } else if (status is ml.Error) {
            setState(() => _message = 'Download failed: ${status.cause.message}');
          }
        },
      );
      await _loadRegions();
      if (mounted) setState(() => _message = 'Nearby map saved for offline viewing.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not download the map: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _deleteRegion(ml.OfflineRegion region) async {
    try {
      await ml.deleteOfflineRegion(region.id);
      await _loadRegions();
      if (mounted) setState(() => _message = 'Offline map deleted.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not delete this map: $e');
    }
  }

  String _regionName(ml.OfflineRegion region) {
    final metadata = region.metadata;
    final name = metadata['name'];
    return name?.toString().isNotEmpty == true ? name.toString() : 'Saved map ${region.id}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline maps')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Save the map around your current location so streets remain visible when your phone temporarily has no internet.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _downloading || kIsWeb ? null : _downloadNearbyArea,
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: Text(_downloading ? 'Downloading map…' : 'Download nearby area'),
                  ),
                ),
                if (_downloading) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                  const SizedBox(height: 6),
                  Text('${(_progress * 100).round()}%'),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, style: TextStyle(color: _message!.startsWith('Could not') || _message!.startsWith('Download failed') ? Colors.red : Colors.black87)),
                ],
                const SizedBox(height: 24),
                Text('Saved areas (${_regions.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (_regions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No offline maps saved yet.'),
                  ),
                for (final region in _regions)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: Text(_regionName(region)),
                      subtitle: Text('Zoom ${region.definition.minZoom.toStringAsFixed(0)}–${region.definition.maxZoom.toStringAsFixed(0)}'),
                      trailing: IconButton(
                        tooltip: 'Delete offline map',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _downloading ? null : () => _deleteRegion(region),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Offline maps store map imagery and labels only. Requesting a ride, live driver tracking, route updates and payments still need an internet connection. Downloaded areas can use device storage.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
    );
  }
}
