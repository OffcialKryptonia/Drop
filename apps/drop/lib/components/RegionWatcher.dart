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

  /// Call with every position. It only contacts the server after ~700 m of movement or 90 seconds.
  Future<void> check(BuildContext context, LatLng here, {required VoidCallback onSwitched}) async {
    if (_busy || _asking) return;
    final moved = _lastAt == null ? double.infinity : const Distance()(_lastAt!, here);
    final waited = DateTime.now().difference(_lastCheck).inSeconds;
    if (moved < 700 && waited < 90) return;
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
