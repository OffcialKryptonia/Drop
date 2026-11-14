import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Vehicle pictures for the map. Built-in pictures ship with the app; an admin can replace any of them
/// (or add more) in the Admin panel. Every picture, whatever its source or size, is resized here to the same
/// square so Google Maps, MapLibre and OpenStreetMap all draw it identically.
class VehicleIcons {
  static Map<String, String> _urls = const {};
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _pending = {};

  /// Admin-uploaded pictures by key, from the server's map settings.
  static void configure(Map<String, String> urls) {
    if (_sameUrls(urls)) return;
    _urls = urls;
    _cache.clear();
    _pending.clear();
  }

  static bool _sameUrls(Map<String, String> o) {
    if (o.length != _urls.length) return false;
    for (final e in o.entries) {
      if (_urls[e.key] != e.value) return false;
    }
    return true;
  }

  /// Side of the square, in pixels. Shown at half that size in logical pixels on a 2x screen.
  static const int size = 96;

  static const _builtIn = {'car', 'bike', 'keke', 'van', 'car_dispatch', 'bike_dispatch'};

  /// PNG bytes for the key, or null if nothing could be loaded.
  static Future<Uint8List?> load(String key) {
    final k = _urls.containsKey(key) || _builtIn.contains(key) ? key : 'car';
    final cached = _cache[k];
    if (cached != null) return Future.value(cached);
    return _pending[k] ??= _build(k).then((b) {
      if (b != null) _cache[k] = b;
      _pending.remove(k);
      return b;
    });
  }

  static Future<Uint8List?> _build(String key) async {
    Uint8List? raw;
    final url = _urls[key];
    if (url != null) {
      try {
        final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) raw = r.bodyBytes;
      } catch (_) {}
    }
    if (raw == null && _builtIn.contains(key)) {
      try {
        raw = (await rootBundle.load('assets/vehicle_icons/$key.png')).buffer.asUint8List();
      } catch (_) {}
    }
    if (raw == null) {
      if (key == 'car') return null;
      return load('car');
    }
    try {
      return await _fit(raw);
    } catch (_) {
      return key == 'car' ? null : load('car');
    }
  }

  /// Scales the picture to fit a size x size square (keeping its shape) and centres it on a transparent square.
  static Future<Uint8List> _fit(Uint8List raw) async {
    final probe = await (await ui.instantiateImageCodec(raw)).getNextFrame();
    final w = probe.image.width, h = probe.image.height;
    probe.image.dispose();
    final scale = size / (w > h ? w : h);
    final tw = (w * scale).round().clamp(1, size), th = (h * scale).round().clamp(1, size);
    final scaled = (await (await ui.instantiateImageCodec(raw, targetWidth: tw, targetHeight: th)).getNextFrame()).image;
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.drawImage(scaled, ui.Offset((size - tw) / 2, (size - th) / 2), ui.Paint()..filterQuality = ui.FilterQuality.high);
    final out = await rec.endRecording().toImage(size, size);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    scaled.dispose();
    out.dispose();
    return data!.buffer.asUint8List();
  }
}
