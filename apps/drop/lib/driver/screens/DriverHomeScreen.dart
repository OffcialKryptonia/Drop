import 'dart:async';
import 'dart:math' as math;

import 'package:drop/service/DriverApplicationApi.dart';
import 'package:drop/drop/design/drop_design.dart';
import 'package:drop/drop/widgets/drop_eta.dart';
import 'package:drop/drop/widgets/drop_extras.dart';
import 'package:drop/drop/widgets/drop_money.dart';
import 'package:drop/drop/widgets/drop_ride_ui.dart';
import 'package:drop/driver/screens/DriverNavigationScreen.dart';
import 'package:drop/drop/widgets/drop_sos_sheet.dart';
import 'package:drop/components/DropMap.dart';
import 'package:drop/components/LiveLocation.dart';
import 'package:drop/components/RegionWatcher.dart';
import 'package:drop/service/MapConfig.dart';
import 'package:drop/service/RegionApi.dart';
import 'package:drop/service/RideApi.dart';
import 'package:drop/service/ToneService.dart';
import 'package:drop/screens/DriverApplicationScreen.dart';
import 'package:drop/service/RouteLineApi.dart';
import 'package:drop/components/RouteGeometry.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../components/DrawerComponent.dart';
import '../utils/Colors.dart';
import 'DocumentsScreen.dart';
import 'WalletScreen.dart';

/// Home of driver mode. Online toggle with wallet and document checks done by the server,
/// location sharing only while online and while the app is open.
/// Ride requests (first driver to accept wins) and the active trip are shown here and refreshed every few seconds.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({Key? key}) : super(key: key);

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> with WidgetsBindingObserver {
  bool loading = true;
  bool busy = false;
  String? loadError;
  Map<String, dynamic> status = {};
  late final LiveLocation _live = LiveLocation(onFix: _onFix);
  final RegionWatcher _region = RegionWatcher();
  bool _sharing = false; // true while online: only then is the position sent to DROP
  DateTime _lastPing = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  int _secs = 0;
  bool _polling = false;
  List<Map<String, dynamic>> requests = [];
  Map<String, dynamic>? active;
  bool rideBusy = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DropMapController _map = DropMapController();
  MapConfig mapConfig = const MapConfig();
  List<List<LatLng>> regionBoundaries = const [];
  bool mapLoaded = false;
  LatLng? myPos;
  String? _fitKey;
  List<LatLng> _routeFull = const [];
  String? _routeKey;
  LatLng? _routeFrom;
  LatLng? _prevPos;
  double _heading = 0;
  String _iconKey = 'car';
  int _docsRequested = 0;
  final Map<int, int> _reqTotal = {}; // longest countdown seen per request, for the ring
  final Set<int> _expiredShown = {};

  bool get online => status['is_online'] == true;
  Map<String, dynamic> get wallet => Map<String, dynamic>.from((status['wallet'] ?? {}) as Map);
  Map<String, dynamic>? get block => status['online_block'] is Map ? Map<String, dynamic>.from(status['online_block'] as Map) : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    MapConfig.load().then((c) async {
      mapConfig = c;
      if (c.mapboxRegionBorderingEnabled) {
        try { regionBoundaries = await RegionApi.boundaries(); } catch (_) { regionBoundaries = const []; }
      }
      if (mounted) setState(() { mapConfig = c; mapLoaded = true; });
    });
    _locateMe();
    _load(resume: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secs++;
      if (_secs % 4 == 0) _pollRides();
      if (mounted && requests.any((r) => _secondsLeft(r) == 0 && _expiredShown.add((r['id'] as num?)?.toInt() ?? -1))) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _live.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(resume: true);
      _pollRides();
    }
  }

  void _say(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load({bool resume = false}) async {
    try {
      status = await DriverApplicationApi.driverStatus();
      loadError = null;
      if (resume && online) {
        _startSharing();
      }
    } on ApiFailure catch (e) {
      loadError = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final p = await DriverApplicationApi.driverProfile();
      final k = p['map_icon']?.toString();
      final n = (p['documents_requested'] as num?)?.toInt() ?? 0;
      if (mounted) setState(() { if (k != null && k.isNotEmpty) _iconKey = k; _docsRequested = n; });
    } catch (_) {}
  }

  /// Every real GPS fix (the icon itself glides between fixes, see LiveLocation).
  void _onFix(Position pos) async {
    final here = LatLng(pos.latitude, pos.longitude);
    if (mounted) setState(() { _trackHeading(pos); myPos = here; });
    _toneIfArrived(here);
    if (mounted) _region.check(context, here, onSwitched: () { _load(); _pollRides(); _loadProfile(); }, regionBoundaries: regionBoundaries, useMapboxGeometry: mapConfig.mapboxRegionBorderingEnabled, accuracyMeters: pos.accuracy);
    if (!_sharing) return;
    if (DateTime.now().difference(_lastPing).inSeconds < (active != null ? 5 : 20)) return;
    _lastPing = DateTime.now();
    try {
      await DriverApplicationApi.pingLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  /// Puts the driver on the map as soon as the phone knows where it is (only if location is already allowed).
  Future<void> _locateMe() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => myPos = LatLng(pos.latitude, pos.longitude));
      _map.animateTo(myPos!, zoom: 17);
      _live.start(seed: myPos); // the icon follows the phone from now on, online or not
    } catch (_) {}
  }

  LatLng _ll(dynamic p) {
    final m = _asMap(p);
    return LatLng(_num(m['lat']), _num(m['lng']));
  }

  /// Keeps the camera on what matters: the driver, plus the pickup or drop-off during a trip.
  void _refit() {
    final a = active;
    final me = myPos;
    final key = a == null ? 'idle' : '${a['id']}:${a['status']}';
    if (key == _fitKey) return;
    _fitKey = key;
    if (a == null) {
      if (me != null) _map.animateTo(me, zoom: 17);
      return;
    }
    final target = a['status'] == 'in_progress' ? _ll(a['dropoff']) : _ll(a['pickup']);
    _map.fitPoints([if (me != null) me, target]);
  }

  RouteSnap? get _mySnap {
    final me = _live.point ?? myPos;
    if (me == null) return null;
    final s = RouteGeometry.snap(_routeFull, me);
    return s != null && s.meters < 80 ? s : null;
  }

  /// The line still ahead: the part already driven is cleared.
  List<LatLng> get _route {
    final s = _mySnap;
    return s == null ? _routeFull : RouteGeometry.remaining(_routeFull, s);
  }

  /// The vehicle sits exactly on the route line when it is close to it.
  LatLng? get _vehiclePoint => _mySnap?.point ?? _live.point ?? myPos;

  /// Loads the road line: to the pickup while on the way, then pickup -> drop-off.
  void _syncRoute() {
    final a = active;
    if (a == null) {
      if (_routeFull.isNotEmpty || _routeKey != null) setState(() { _routeFull = const []; _routeKey = null; _routeFrom = null; });
      return;
    }
    final pick = _ll(a['pickup']);
    final drop = _ll(a['dropoff']);
    final me = myPos;
    final toPickup = (a['status'] == 'accepted' || a['status'] == 'arrived') && me != null;
    final waypoints = <LatLng>[toPickup ? me! : pick];
    if (toPickup) {
      waypoints.add(pick);
    } else {
      for (final stop in _stops(a)) {
        if (stop['status'] != 'completed') waypoints.add(LatLng(_num(stop['lat']), _num(stop['lng'])));
      }
      waypoints.add(drop);
    }
    final key = '${a['id']}:${toPickup ? 'toPickup' : 'trip'}:${waypoints.map((p) => '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}').join('|')}';
    final moved = toPickup && _routeFrom != null && RouteGeometry.meters(_routeFrom!, me!) > 250;
    if (key == _routeKey && !moved) return;
    final changed = key != _routeKey;
    _routeKey = key;
    _routeFrom = waypoints.first;
    if (changed) setState(() => _routeFull = const []);
    () async {
      final all = <LatLng>[];
      for (var i = 0; i < waypoints.length - 1; i++) {
        final segment = await RouteLineApi.fetch(waypoints[i], waypoints[i + 1]);
        if (segment.isNotEmpty) all.addAll(all.isEmpty ? segment : segment.skip(1));
      }
      if (mounted && _routeKey == key) setState(() => _routeFull = all);
    }();
  }

  /// Which way the vehicle faces: the phone's heading when moving, else the direction of the last movement.
  void _trackHeading(Position pos) {
    final now = LatLng(pos.latitude, pos.longitude);
    if (pos.speed > 1.5 && pos.heading >= 0) {
      _heading = pos.heading;
    } else if (_prevPos != null && RouteGeometry.meters(_prevPos!, now) >= 5) {
      _heading = RouteGeometry.bearing(_prevPos!, now);
    }
    _prevPos = now;
  }

  List<DropMarker> get _markers {
    final out = <DropMarker>[];
    final a = active;
    if (a != null) {
      if (a['status'] != 'in_progress') out.add(DropMarker(id: 'pickup', title: 'Pickup', color: Colors.green, point: _ll(a['pickup'])));
      for (final stop in _stops(a)) {
        out.add(DropMarker(id: 'stop-${stop['id']}', title: 'Stop ${stop['sequence']}', color: stop['status'] == 'completed' ? Colors.grey : Colors.orange, point: LatLng(_num(stop['lat']), _num(stop['lng']))));
      }
      out.add(DropMarker(id: 'drop', title: 'Drop-off', color: Colors.red, point: _ll(a['dropoff'])));
    } else if (online) {
      for (final r in requests) {
        out.add(DropMarker(id: 'req${r['id']}', title: 'Pickup', color: Colors.green, point: _ll(r['pickup'])));
      }
    }
    final v = _vehiclePoint;
    if (v != null) out.add(DropMarker(id: 'me', title: 'You', color: Colors.blue, point: v, iconKey: _iconKey, heading: _live.running ? _live.heading : _heading));
    return out;
  }

  Future<bool> _locationAllowed() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _say('Turn on your phone location to go online.');
      return false;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      _say('Allow location access for DROP in your phone settings to go online.');
      return false;
    }
    return true;
  }

  /// Foreground location only: while the driver is online and the app is open, the position is sent to DROP.
  void _startSharing() {
    _sharing = true;
    _live.start(seed: myPos);
  }

  void _stopSharing() {
    _sharing = false;
  }

  /// Flips the switch at once and confirms with the server in the background; undoes it with a message if refused.
  Future<void> _toggle(bool wantOnline) async {
    if (busy) return;
    final before = Map<String, dynamic>.from(status);
    if (wantOnline && !await _locationAllowed()) return;
    setState(() {
      busy = true;
      status = {...status, 'is_online': wantOnline};
    });
    try {
      if (wantOnline) {
        // Last known position is instant; a fresh fix is only waited for briefly.
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 8));
        if (mounted) setState(() => myPos = LatLng(pos!.latitude, pos.longitude));
        await DriverApplicationApi.setOnline(true, latitude: pos.latitude, longitude: pos.longitude);
        _startSharing();
      } else {
        _stopSharing();
        if (mounted) setState(() => requests = []);
        await DriverApplicationApi.setOnline(false);
      }
      _load(); // refresh wallet and blocks without holding the switch
    } on ApiFailure catch (e) {
      _say(e.message);
      if (mounted) setState(() => status = before);
      _load();
    } catch (_) {
      _say('Could not get your location. Please try again.');
      if (mounted) setState(() => status = before);
    }
    if (mounted) setState(() => busy = false);
  }

  // ---------- ride requests and the active trip ----------

  Map<String, dynamic> _asMap(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);

  List<Map<String, dynamic>> _stops(Map<String, dynamic> ride) =>
      (ride['stops'] is List ? (ride['stops'] as List) : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
        ..sort((a, b) => _num(a['sequence']).compareTo(_num(b['sequence'])));

  Map<String, dynamic>? _nextStop(Map<String, dynamic> ride) {
    for (final stop in _stops(ride)) {
      if (stop['status'] != 'completed') return stop;
    }
    return null;
  }

  Future<void> _arriveStop(Map<String, dynamic> ride, Map<String, dynamic> stop) async {
    await _rideAction(() => RideApi.arriveAtStop((ride['id'] as num).toInt(), (stop['id'] as num).toInt()));
  }

  Future<void> _completeStop(Map<String, dynamic> ride, Map<String, dynamic> stop) async {
    if (!await _confirm('Complete this stop?', 'Confirm that this passenger stop has been completed before continuing.', 'Complete stop')) return;
    await _rideAction(() => RideApi.completeStop((ride['id'] as num).toInt(), (stop['id'] as num).toInt()));
  }

  String _naira(dynamic v) => DropMoney.format(v);

  final Set<int> _heardRequests = {};
  bool _requestsPrimed = false;
  int? _arrivedFor;

  /// Rings once for each ride request that appears for the first time.
  void _toneForRequests(List<Map<String, dynamic>> list) {
    final ids = list.map((e) => (e['id'] as num?)?.toInt()).whereType<int>().toSet();
    final fresh = ids.difference(_heardRequests);
    _heardRequests.addAll(ids);
    if (_requestsPrimed && fresh.isNotEmpty && active == null) ToneService.play(ToneEvent.driverIncoming);
    _requestsPrimed = true;
  }

  /// Rings once when the driver gets within ~80 m of the drop-off during a trip.
  void _toneIfArrived(LatLng here) {
    final a = active;
    if (a == null || a['status'] != 'in_progress') return;
    final id = (a['id'] as num?)?.toInt();
    final nextStop = _nextStop(a);
    final target = nextStop == null ? _ll(a['dropoff']) : LatLng(_num(nextStop['lat']), _num(nextStop['lng']));
    if (id == null || _arrivedFor == id) return;
    if (Geolocator.distanceBetween(here.latitude, here.longitude, target.latitude, target.longitude) <= 80) {
      _arrivedFor = id;
      ToneService.play(ToneEvent.driverArrived);
    }
  }

  Future<void> _pollRides() async {
    if (_polling || !mounted || loading || (!online && active == null)) return;
    _polling = true;
    try {
      final r = await RideApi.driverRequests();
      final a = r['active'];
      final list = r['requests'];
      if (mounted) {
        final newRequests = list is List ? list.map(_asMap).toList() : <Map<String, dynamic>>[];
        setState(() {
          active = a is Map ? Map<String, dynamic>.from(a) : null;
          requests = newRequests;
        });
        _toneForRequests(newRequests);
      }
    } on ApiFailure {
      if (RideApi.lastCode == 'not_online') {
        if (mounted) setState(() => requests = []);
        _load();
      }
      // any other refusal or a missed poll is fine: the next poll catches up
    } catch (_) {}
    _polling = false;
  }

  Future<void> _rideAction(Future<Map<String, dynamic>> Function() call, {String? thenSay}) async {
    if (rideBusy) return;
    setState(() => rideBusy = true);
    try {
      await call();
      if (thenSay != null) _say(thenSay);
    } on ApiFailure catch (e) {
      _say(e.message);
    }
    await _pollRides();
    if (mounted) setState(() => rideBusy = false);
  }

  Future<void> _accept(Map<String, dynamic> r) async {
    final id = (r['id'] as num).toInt();
    await _rideAction(() => RideApi.accept(id));
  }

  Future<void> _decline(Map<String, dynamic> r) async {
    final id = (r['id'] as num).toInt();
    setState(() => requests = requests.where((x) => x['id'] != r['id']).toList());
    try {
      await RideApi.decline(id);
    } catch (_) {}
  }

  Future<bool> _confirm(String title, String text, String yes, {bool danger = false}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => DropSheet(
        maxHeightFactor: 0.6,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: DropColors.text(c))),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(fontSize: 15, height: 1.35, color: DropColors.mutedText(c))),
          const SizedBox(height: 20),
          DropActionButton(label: yes, primary: true, danger: danger, onPressed: () => Navigator.pop(c, true)),
          const SizedBox(height: 10),
          DropActionButton(label: 'Not yet', onPressed: () => Navigator.pop(c, false)),
        ]),
      ),
    );
    return ok == true;
  }

  Future<void> _complete(Map<String, dynamic> a) async {
    final id = (a['id'] as num).toInt();
    final cash = a['payment_method'] != 'wallet';
    if (!await _confirm('End the trip?', cash ? 'Make sure you have collected ${_naira(a['fare'])} in cash from the passenger.' : 'The fare will be paid from the passenger\'s wallet.', 'End trip')) return;
    if (rideBusy) return;
    setState(() => rideBusy = true);
    try {
      final res = _asMap((await RideApi.complete(id))['data']);
      ToneService.play(ToneEvent.driverPayment);
      _load(); // the wallet chip behind the receipt updates at once
      if (mounted) await _showReceipt(res, id);
    } on ApiFailure catch (e) {
      _say(e.message);
    }
    await _pollRides();
    await _load();
    if (mounted) setState(() => rideBusy = false);
  }

  Future<void> _cancelTrip(Map<String, dynamic> a) async {
    final id = (a['id'] as num).toInt();
    if (!await _confirm('Cancel this trip?', 'The request goes back to other drivers. Cancelling too often can affect your account.', 'Cancel trip', danger: true)) return;
    await _rideAction(() => RideApi.driverCancel(id), thenSay: 'Trip cancelled.');
  }

  Future<void> _startNavigation(double lat, double lng, String label) async {
    if (mapConfig.isMapbox && mapConfig.mapboxPublicToken.startsWith('pk.')) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => DriverNavigationScreen(
          mapConfig: mapConfig,
          destination: LatLng(lat, lng),
          destinationLabel: label,
          initialPosition: _live.point ?? myPos,
        ),
      ));
      return;
    }
    await _openMaps(lat, lng);
  }

  /// Turn-by-turn navigation in the driver's own navigation app. Follows the admin map switch:
  /// Google Maps in Google mode, otherwise any installed navigation app (or OpenStreetMap in the browser).
  Future<void> _openMaps(double lat, double lng) async {
    try {
      if (mapConfig.isGoogle) {
        await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'), mode: LaunchMode.externalApplication);
        return;
      }
      var opened = false;
      try {
        opened = await launchUrl(Uri.parse('geo:$lat,$lng?q=$lat,$lng'));
      } catch (_) {}
      if (!opened) {
        await launchUrl(Uri.parse('https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=;$lat,$lng'), mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      _say('Could not open a navigation app.');
    }
  }

  Future<void> _callRider(String? n) async {
    if (n == null || n.isEmpty) return;
    try {
      await launchUrl(Uri.parse('tel:$n'));
    } catch (_) {
      _say('Could not open the phone app.');
    }
  }

  int _secondsLeft(Map<String, dynamic> r) {
    final e = DateTime.tryParse(r['expires_at']?.toString() ?? '');
    if (e == null) return 0;
    final d = e.difference(DateTime.now().toUtc()).inSeconds;
    return d < 0 ? 0 : d;
  }

  /// What the driver sees when a trip ends: the earning first, then the breakdown and what to do about the money.
  Future<void> _showReceipt(Map<String, dynamic> res, int rideId) {
    final cash = res['collect_cash'] == true;
    final commission = DropMoney.toNum(res['commission']);
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => PopScope(
        canPop: false,
        child: DropSheet(
          maxHeightFactor: 0.92,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: DropColors.success.withValues(alpha: 0.14),
                child: Icon(Icons.check_rounded, color: DropColors.success, size: 34),
              ),
            ),
            const SizedBox(height: 12),
            Text('Trip complete', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: DropColors.text(c))),
            const SizedBox(height: 4),
            Text('You earned', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: DropColors.mutedText(c))),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: DropMoneyText(res['earning'], style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: DropColors.text(c))),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: DropColors.surface(c), borderRadius: BorderRadius.circular(16), border: Border.all(color: DropColors.hairline(c))),
              child: Column(children: [
                DropReceiptRow(label: 'Fare', amount: DropMoneyText(res['fare'])),
                DropReceiptRow(label: 'DROP commission', amount: DropMoneyText(-commission)),
                Divider(height: 12, color: DropColors.hairline(c)),
                DropReceiptRow(label: 'Your earning', amount: DropMoneyText(res['earning']), bold: true),
              ]),
            ),
            const SizedBox(height: 12),
            if (cash)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: DropColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: DropColors.primary, width: 1.2)),
                child: Row(children: [
                  Icon(Icons.payments_outlined, color: DropColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(style: TextStyle(fontSize: 16, color: DropColors.text(c)), children: [
                        const TextSpan(text: 'Collect '),
                        TextSpan(text: DropMoney.format(res['fare']), style: const TextStyle(fontWeight: FontWeight.w900)),
                        const TextSpan(text: ' in cash from the passenger.'),
                      ]),
                    ),
                  ),
                ]),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: DropColors.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.account_balance_wallet_outlined, color: DropColors.success),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Paid from the passenger’s wallet. Your earning has been added to your wallet.', style: TextStyle(fontSize: 15, color: DropColors.text(c)))),
                ]),
              ),
            if (cash && commission > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${DropMoney.format(commission)} DROP commission was taken from your wallet.', style: TextStyle(fontSize: 13, color: DropColors.mutedText(c))),
              ),
            const SizedBox(height: 16),
            DropActionButton(label: 'Done', primary: true, onPressed: () => Navigator.pop(c)),
            if (cash && commission > 0)
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen())).then((_) => _load());
                },
                child: const Text('View wallet'),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> r, {required int index, required int total}) {
    final pickup = _asMap(r['pickup']);
    final drop = _asMap(r['dropoff']);
    final id = (r['id'] as num?)?.toInt() ?? 0;
    final seen = _reqTotal[id] = math.max(_reqTotal[id] ?? 0, _secondsLeft(r));
    final cash = r['payment_method'] != 'wallet';
    final unit = (r['distance_unit'] ?? 'km').toString();
    final eta = r['pickup_eta_minutes'];
    final tripMin = _num(r['duration_minutes']).round();
    return DropSwipeDecision(
      enabled: !rideBusy,
      onAccept: () => _accept(r),
      onDecline: () => _decline(r),
      child: DropSheet(
      maxHeightFactor: 0.7,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (total > 1) Text('New request · ${index + 1} of $total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DropColors.mutedText(context))),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: DropMoneyText(r['fare'], style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: DropColors.text(context))),
              ),
              Text.rich(TextSpan(style: TextStyle(fontSize: 15, color: DropColors.mutedText(context)), children: [
                const TextSpan(text: 'You earn '),
                TextSpan(text: DropMoney.format(r['earning']), style: TextStyle(fontWeight: FontWeight.w800, color: DropColors.success)),
              ])),
            ]),
          ),
          const SizedBox(width: 12),
          DropCountdownRing(expiresAt: DateTime.tryParse(r['expires_at']?.toString() ?? ''), totalSeconds: seen),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          DropFactChip(icon: cash ? Icons.payments_outlined : Icons.account_balance_wallet_outlined, text: cash ? 'Cash' : 'Wallet'),
          DropFactChip(icon: Icons.my_location, text: '${_num(r['pickup_distance_km']).toStringAsFixed(1)} km${eta != null ? ' · $eta min' : ''} to pickup'),
          DropFactChip(icon: Icons.route, text: 'Trip ${_num(r['distance']).toStringAsFixed(1)} $unit · $tripMin min'),
        ]),
        const SizedBox(height: 14),
        DropStopTimeline(pickup: (pickup['address'] ?? '').toString(), dropoff: (drop['address'] ?? '').toString()),
        for (final stop in _stops(r))
          Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [const Icon(Icons.location_on_outlined, size: 16, color: Colors.orange), const SizedBox(width: 8), Expanded(child: Text('Stop ${stop['sequence']}: ${stop['address'] ?? 'Additional stop'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))])),
        const SizedBox(height: 10),
        Center(child: Text('Swipe down to accept \u00B7 up to decline', style: TextStyle(fontSize: 12, color: DropColors.mutedText(context)))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(flex: 2, child: DropActionButton(label: 'Decline', onPressed: rideBusy ? null : () => _decline(r))),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: DropActionButton(label: 'Accept', primary: true, loading: rideBusy, onPressed: rideBusy ? null : () => _accept(r))),
        ]),
      ]),
    ));
  }

  Widget _activeTrip(Map<String, dynamic> a) {
    final status = a['status']?.toString() ?? 'accepted';
    final pickup = _asMap(a['pickup']);
    final drop = _asMap(a['dropoff']);
    final rider = _asMap(a['rider']);
    final toDrop = status == 'in_progress';
    final nextStop = toDrop ? _nextStop(a) : null;
    final target = !toDrop ? pickup : (nextStop == null ? drop : {'lat': nextStop['lat'], 'lng': nextStop['lng'], 'address': nextStop['address']});
    final cash = a['payment_method'] != 'wallet';
    final name = (rider['first_name'] ?? '').toString();
    final phone = (rider['contact_number'] ?? '').toString();
    final pillText = status == 'accepted' ? 'Heading to pickup' : (status == 'arrived' ? 'Waiting for passenger' : 'Trip in progress');
    final pillColor = status == 'in_progress' ? DropColors.success : DropColors.primary;
    final pillIcon = status == 'accepted' ? Icons.navigation : (status == 'arrived' ? Icons.hourglass_top : Icons.directions_car);
    final primaryLabel = status == 'accepted' ? 'I have arrived' : (status == 'arrived' ? 'Start trip' : (nextStop == null ? 'Complete trip' : (nextStop['status'] == 'arrived' ? 'Complete stop' : 'I have arrived at stop')));
    return DropSheet(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Align(alignment: Alignment.centerLeft, child: DropStatusPill(text: pillText, color: pillColor, icon: pillIcon))),
          const SizedBox(width: 12),
          DropMoneyText(a['fare'], style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: DropColors.text(context))),
        ]),
        if (a['eta'] is Map) ...[
          const SizedBox(height: 10),
          DropEtaStrip(eta: _asMap(a['eta']), forDriver: true),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          DropFactChip(icon: cash ? Icons.payments_outlined : Icons.account_balance_wallet_outlined, text: cash ? 'Passenger pays cash' : 'Paid from wallet'),
          DropFactChip(icon: Icons.trending_up, text: 'You earn ${DropMoney.format(a['earning'])}', color: DropColors.success),
        ]),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            CircleAvatar(radius: 22, backgroundColor: DropColors.primary.withValues(alpha: 0.12), child: Text(name.characters.first.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: DropColors.primary))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: DropColors.text(context))),
                Text('Passenger', style: TextStyle(fontSize: 13, color: DropColors.mutedText(context))),
              ]),
            ),
            if (phone.isNotEmpty) DropRoundAction(icon: Icons.call, label: 'Call passenger', onPressed: () => _callRider(phone)),
          ]),
        ],
        const SizedBox(height: 14),
        DropStopTimeline(pickup: (pickup['address'] ?? '').toString(), dropoff: (drop['address'] ?? '').toString(), activeStop: toDrop ? 1 : 0),
        for (final stop in _stops(a))
          Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Icon(stop['status'] == 'completed' ? Icons.check_circle : Icons.location_on_outlined, color: stop['status'] == 'completed' ? DropColors.success : DropColors.primary, size: 18), const SizedBox(width: 8), Expanded(child: Text('Stop ${stop['sequence']}: ${stop['address'] ?? 'Additional stop'}', style: TextStyle(fontWeight: FontWeight.w700, color: DropColors.text(context)))), Text(stop['status']?.toString() ?? 'pending', style: TextStyle(fontSize: 12, color: DropColors.mutedText(context))) ])),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: DropActionButton(label: 'Navigate', icon: Icons.navigation_outlined, onPressed: () => _startNavigation(_num(target['lat']), _num(target['lng']), !toDrop ? 'Pickup' : (nextStop == null ? 'Drop-off' : 'Stop ${nextStop['sequence']}')))),
          const SizedBox(width: 12),
          Expanded(child: DropActionButton(label: 'SOS', icon: Icons.sos, danger: true, onPressed: () => showDropSos(context, rideId: (a['id'] as num?)?.toInt()))),
        ]),
        if (status == 'accepted' && a['extras_enabled'] != false) ...[
          const SizedBox(height: 10),
          DropActionButton(
            label: 'Add extra charge',
            icon: Icons.add_card,
            onPressed: () => showDropAddExtraSheet(context, rideId: (a['id'] as num).toInt()).then((sent) {
              if (sent) _say('Extra charge sent to the passenger.');
            }),
          ),
        ],
        const SizedBox(height: 10),
        DropActionButton(
          label: primaryLabel,
          primary: true,
          loading: rideBusy,
          onPressed: rideBusy
              ? null
              : () {
                  final id = (a['id'] as num).toInt();
                  if (status == 'accepted') _rideAction(() => RideApi.arrived(id));
                  if (status == 'arrived') _rideAction(() => RideApi.start(id));
                  if (status == 'in_progress') {
                    if (nextStop == null) { _complete(a); }
                    else if (nextStop['status'] == 'arrived') { _completeStop(a, nextStop); }
                    else { _arriveStop(a, nextStop); }
                  }
                },
        ),
        if (status != 'in_progress')
          Center(
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: rideBusy ? null : () => _cancelTrip(a),
              child: const Text('Cancel trip', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refit();
        _syncRoute();
      });
    }
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFEFEFEF),
      drawer: DrawerComponent(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
              ? _errorView()
              : Stack(children: [
                  Positioned.fill(
                    child: !mapLoaded
                        ? const ColoredBox(color: Color(0xFFEFEFEF))
                        : AnimatedBuilder(
                            animation: _live,
                            builder: (_, __) => DropMap(
                              provider: mapConfig.provider,
                              tileUrl: mapConfig.tileUrl,
                              styleUrl: mapConfig.styleUrl,
                              attribution: mapConfig.attribution,
                              mapboxStyleUri: mapConfig.mapboxStyleUri,
                              showRegionBorders: mapConfig.mapboxRegionBorderingEnabled,
                              regionBoundaries: regionBoundaries,
                              initialCenter: myPos ?? const LatLng(9.0765, 7.3986),
                              controller: _map,
                              markers: _markers,
                              routePoints: _route,
                            )),
                  ),
                  SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisSize: MainAxisSize.min, children: [_topBar(), if (_docsRequested > 0) _docsBanner()]))),
                  Align(alignment: Alignment.bottomCenter, child: SafeArea(top: false, child: _bottomPanel())),
                ]),
    );
  }

  /// DROP asked this driver to upload documents: tapping opens the page where they can.
  Widget _docsBanner() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: Colors.deepOrange,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DriverApplicationScreen()));
              DriverApplicationApi.driverProfile().then((p) {
                if (mounted) setState(() => _docsRequested = (p['documents_requested'] as num?)?.toInt() ?? 0);
              }).catchError((_) {});
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Icon(Icons.upload_file, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(_docsRequested == 1 ? 'DROP needs 1 document from you. Tap to upload.' : 'DROP needs $_docsRequested documents from you. Tap to upload.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
        ),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(resume: true), child: const Text('Try again')),
          ]),
        ),
      );

  Widget _roundButton(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: Colors.black87))),
      );

  /// Menu, online switch and wallet balance floating over the map.
  Widget _topBar() {
    final b = block;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        _roundButton(Icons.menu, () => _scaffoldKey.currentState?.openDrawer()),
        const SizedBox(width: 10),
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 0),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? Colors.green : Colors.grey)),
                const SizedBox(width: 6),
                // One line always: scale the word down instead of letting it wrap letter by letter on narrow phones.
                Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(online ? 'Online' : 'Offline', maxLines: 1, softWrap: false, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)))),
                busy
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : Transform.scale(
                        scale: 0.85,
                        child: Switch(
                        value: online,
                        activeColor: primaryColor,
                        onChanged: active != null ? null : ((online || b == null) ? _toggle : (_) => _say(b['message']?.toString() ?? 'You cannot go online yet.')),
                      )),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen())).then((_) => _load()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.account_balance_wallet_outlined, size: 16, color: primaryColor),
                const SizedBox(width: 4),
                Text(_naira(wallet['balance']), style: TextStyle(fontWeight: FontWeight.w800, color: DropMoney.toNum(wallet['balance']) < 0 ? Colors.red : null)),
              ]),
            ),
          ),
        ),
      ]),
      if (b != null && !online) Padding(padding: const EdgeInsets.only(top: 10), child: _blockCard(b)),
    ]);
  }

  /// What sits at the bottom of the map: the trip, the incoming request, or the go-online prompt.
  Widget _bottomPanel() {
    final a = active;
    if (a != null) return _activeTrip(a);
    if (!online) return Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: _offlineCard());
    final open = requests.where((r) => _secondsLeft(r) > 0).toList();
    if (open.isEmpty) return Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 20), child: _lookingPill());
    return _requestCard(open.first, index: 0, total: open.length);
  }

  Widget _offlineCard() {
    final b = block;
    return DropSheet(
      margin: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('You are offline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: DropColors.text(context))),
        const SizedBox(height: 4),
        Text(b == null ? 'Go online to start receiving ride requests.' : 'Fix the issue above to go online.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: DropColors.mutedText(context))),
        const SizedBox(height: 14),
        DropActionButton(label: 'Go online', primary: true, onPressed: busy ? null : () => b == null ? _toggle(true) : _say(b['message']?.toString() ?? 'You cannot go online yet.')),
      ]),
    );
  }

  Widget _lookingPill() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(color: dropIsDark(context) ? DropColors.nightSurface : Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text('Looking for requests\u2026', style: TextStyle(fontWeight: FontWeight.w700, color: DropColors.text(context))),
        ]),
      );

  Widget _blockCard(Map<String, dynamic> b) {
    final isDocs = b['code'] == 'documents_expired';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [
        Icon(Icons.info_outline, color: Colors.orange.shade800),
        const SizedBox(width: 12),
        Expanded(child: Text((b['message'] ?? 'You cannot go online yet.').toString())),
        if (isDocs) TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentsScreen(isShow: true))).then((_) => _load()), child: const Text('Documents')),
      ]),
    );
  }
}
