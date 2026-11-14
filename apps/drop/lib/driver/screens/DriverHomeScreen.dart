import 'dart:async';

import 'package:drop/service/DriverApplicationApi.dart';
import 'package:drop/drop/widgets/drop_sos_sheet.dart';
import 'package:drop/components/DropMap.dart';
import 'package:drop/service/MapConfig.dart';
import 'package:drop/service/RideApi.dart';
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
  StreamSubscription<Position>? _positionSub;
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
  bool mapLoaded = false;
  LatLng? myPos;
  String? _fitKey;
  List<LatLng> _routeFull = const [];
  String? _routeKey;
  LatLng? _routeFrom;
  LatLng? _prevPos;
  double _heading = 0;
  String _iconKey = 'car';

  bool get online => status['is_online'] == true;
  Map<String, dynamic> get wallet => Map<String, dynamic>.from((status['wallet'] ?? {}) as Map);
  Map<String, dynamic>? get block => status['online_block'] is Map ? Map<String, dynamic>.from(status['online_block'] as Map) : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DriverApplicationApi.driverProfile().then((p) {
      final k = p['map_icon']?.toString();
      if (k != null && k.isNotEmpty && mounted) setState(() => _iconKey = k);
    }).catchError((_) {});
    MapConfig.load().then((c) {
      if (mounted) setState(() {
        mapConfig = c;
        mapLoaded = true;
      });
    });
    _locateMe();
    _load(resume: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secs++;
      if (_secs % 4 == 0) _pollRides();
      if (mounted && requests.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
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

  /// Puts the driver on the map as soon as the phone knows where it is (only if location is already allowed).
  Future<void> _locateMe() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() => myPos = LatLng(pos.latitude, pos.longitude));
      _map.animateTo(myPos!, zoom: 15);
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
      if (me != null) _map.animateTo(me, zoom: 15);
      return;
    }
    final target = a['status'] == 'in_progress' ? _ll(a['dropoff']) : _ll(a['pickup']);
    _map.fitPoints([if (me != null) me, target]);
  }

  RouteSnap? get _mySnap {
    final me = myPos;
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
  LatLng? get _vehiclePoint => _mySnap?.point ?? myPos;

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
    final LatLng from = toPickup ? me! : pick;
    final to = toPickup ? pick : drop;
    final key = '${a['id']}:${toPickup ? 'toPickup' : 'trip'}';
    final moved = toPickup && _routeFrom != null && RouteGeometry.meters(_routeFrom!, me!) > 250;
    if (key == _routeKey && !moved) return;
    final changed = key != _routeKey;
    _routeKey = key;
    _routeFrom = from;
    if (changed) setState(() => _routeFull = const []);
    RouteLineApi.fetch(from, to).then((pts) {
      if (mounted && _routeKey == key) setState(() => _routeFull = pts);
    });
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
      out.add(DropMarker(id: 'drop', title: 'Drop-off', color: Colors.red, point: _ll(a['dropoff'])));
    } else if (online) {
      for (final r in requests) {
        out.add(DropMarker(id: 'req${r['id']}', title: 'Pickup', color: Colors.green, point: _ll(r['pickup'])));
      }
    }
    final v = _vehiclePoint;
    if (v != null) out.add(DropMarker(id: 'me', title: 'You', color: Colors.blue, point: v, iconKey: _iconKey, heading: _heading));
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

  /// Foreground location only: the stream runs while the app is open and the driver is online.
  void _startSharing() {
    if (_positionSub != null) return;
    _positionSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15)).listen((pos) async {
      if (mounted) setState(() { _trackHeading(pos); myPos = LatLng(pos.latitude, pos.longitude); });
      if (DateTime.now().difference(_lastPing).inSeconds < (active != null ? 5 : 20)) return;
      _lastPing = DateTime.now();
      try {
        await DriverApplicationApi.pingLocation(pos.latitude, pos.longitude);
      } catch (_) {}
    }, onError: (_) {});
  }

  void _stopSharing() {
    _positionSub?.cancel();
    _positionSub = null;
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

  String _naira(dynamic v) {
    final n = _num(v);
    final t = n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2);
    final parts = t.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '\u20A6$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  Future<void> _pollRides() async {
    if (_polling || !mounted || loading || (!online && active == null)) return;
    _polling = true;
    try {
      final r = await RideApi.driverRequests();
      final a = r['active'];
      final list = r['requests'];
      if (mounted) {
        setState(() {
          active = a is Map ? Map<String, dynamic>.from(a) : null;
          requests = list is List ? list.map(_asMap).toList() : <Map<String, dynamic>>[];
        });
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

  Future<bool> _confirm(String title, String text, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
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
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Trip complete'),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fare ${_naira(res['fare'])}'),
              Text('DROP commission ${_naira(res['commission'])}'),
              Text('Your earning ${_naira(res['earning'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (res['collect_cash'] == true) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Collect ${_naira(res['fare'])} in cash from the passenger.', style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
      }
    } on ApiFailure catch (e) {
      _say(e.message);
    }
    await _pollRides();
    await _load();
    if (mounted) setState(() => rideBusy = false);
  }

  Future<void> _cancelTrip(Map<String, dynamic> a) async {
    final id = (a['id'] as num).toInt();
    if (!await _confirm('Cancel this trip?', 'The request goes back to other drivers. Cancelling too often can affect your account.', 'Cancel trip')) return;
    await _rideAction(() => RideApi.driverCancel(id), thenSay: 'Trip cancelled.');
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

  Widget _addrRow(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text.isEmpty ? 'Selected place' : text)),
        ]),
      );

  Widget _requestCard(Map<String, dynamic> r) {
    final pickup = _asMap(r['pickup']);
    final drop = _asMap(r['dropoff']);
    final left = _secondsLeft(r);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: primaryColor, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_naira(r['fare']), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
          Text('${left}s', style: TextStyle(color: left < 20 ? Colors.red : Colors.grey.shade700, fontWeight: FontWeight.w700)),
        ]),
        Text('You earn ${_naira(r['earning'])} \u00B7 ${r['payment_method'] == 'wallet' ? 'wallet' : 'cash'}', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Text('Pickup ${_num(r['pickup_distance_km']).toStringAsFixed(1)} km away (~${r['pickup_eta_minutes']} min) \u00B7 trip ${_num(r['distance']).toStringAsFixed(1)} ${r['distance_unit'] ?? 'km'}, ~${_num(r['duration_minutes']).round()} min',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        _addrRow(Icons.my_location, Colors.green, (pickup['address'] ?? '').toString()),
        _addrRow(Icons.location_on, primaryColor, (drop['address'] ?? '').toString()),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: rideBusy ? null : () => _decline(r), child: const Text('Decline'))),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              onPressed: rideBusy ? null : () => _accept(r),
              child: rideBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Accept', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _activeTrip(Map<String, dynamic> a) {
    final status = a['status']?.toString() ?? 'accepted';
    final pickup = _asMap(a['pickup']);
    final drop = _asMap(a['dropoff']);
    final rider = _asMap(a['rider']);
    final toDrop = status == 'in_progress';
    final title = status == 'accepted' ? 'Go to the pickup point' : (status == 'arrived' ? 'Waiting for the passenger' : 'Trip in progress');
    final target = toDrop ? drop : pickup;
    final cash = a['payment_method'] != 'wallet';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.green, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          Text(_naira(a['fare']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        Text(cash ? 'Passenger pays cash \u00B7 you earn ${_naira(a['earning'])}' : 'Paid from wallet \u00B7 you earn ${_naira(a['earning'])}', style: TextStyle(color: Colors.grey.shade700)),
        if ((rider['first_name'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(rider['first_name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700))),
              if ((rider['contact_number'] ?? '').toString().isNotEmpty) IconButton(onPressed: () => _callRider(rider['contact_number'].toString()), icon: Icon(Icons.call, color: primaryColor)),
            ]),
          ),
        _addrRow(Icons.my_location, Colors.green, (pickup['address'] ?? '').toString()),
        _addrRow(Icons.location_on, primaryColor, (drop['address'] ?? '').toString()),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openMaps(_num(target['lat']), _num(target['lng'])),
          icon: const Icon(Icons.navigation_outlined),
          label: Text(toDrop ? 'Navigate to drop-off' : 'Navigate to pickup'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => showDropSos(context, rideId: (a['id'] as num?)?.toInt()),
          icon: const Icon(Icons.sos, color: Colors.red),
          label: const Text('SOS \u2013 I need help', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: rideBusy
                ? null
                : () {
                    final id = (a['id'] as num).toInt();
                    if (status == 'accepted') _rideAction(() => RideApi.arrived(id));
                    if (status == 'arrived') _rideAction(() => RideApi.start(id));
                    if (status == 'in_progress') _complete(a);
                  },
            child: rideBusy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(status == 'accepted' ? 'I have arrived' : (status == 'arrived' ? 'Start trip' : 'Complete trip'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        if (status != 'in_progress') Align(alignment: Alignment.centerRight, child: TextButton(onPressed: rideBusy ? null : () => _cancelTrip(a), child: const Text('Cancel trip', style: TextStyle(color: Colors.red)))),
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
                        : DropMap(
                            provider: mapConfig.provider,
                            tileUrl: mapConfig.tileUrl,
                            styleUrl: mapConfig.styleUrl,
                            attribution: mapConfig.attribution,
                            initialCenter: myPos ?? const LatLng(9.0765, 7.3986),
                            controller: _map,
                            markers: _markers,
                            routePoints: _route,
                          ),
                  ),
                  SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: _topBar())),
                  Align(alignment: Alignment.bottomCenter, child: SafeArea(top: false, child: _bottomPanel())),
                ]),
    );
  }

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
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? Colors.green : Colors.grey)),
                const SizedBox(width: 8),
                Expanded(child: Text(online ? 'Online' : 'Offline', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                busy
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : Switch(
                        value: online,
                        activeColor: primaryColor,
                        onChanged: active != null ? null : ((online || b == null) ? _toggle : (_) => _say(b['message']?.toString() ?? 'You cannot go online yet.')),
                      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.account_balance_wallet_outlined, size: 18, color: primaryColor),
                const SizedBox(width: 6),
                Text(_naira(wallet['balance']), style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      ]),
      if (b != null && !online) Padding(padding: const EdgeInsets.only(top: 10), child: _blockCard(b)),
    ]);
  }

  /// What sits at the bottom of the map: the trip, the incoming requests, or the go-online prompt.
  Widget _bottomPanel() {
    final a = active;
    Widget child;
    if (a != null) {
      child = _activeTrip(a);
    } else if (!online) {
      final b = block;
      child = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('You are offline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(b == null ? 'Go online to start receiving ride requests.' : 'Fix the issue above to go online.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: busy ? null : () => b == null ? _toggle(true) : _say(b['message']?.toString() ?? 'You cannot go online yet.'),
              child: const Text('Go online', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );
    } else {
      final open = requests.where((r) => _secondsLeft(r) > 0).toList();
      if (open.isEmpty) {
        child = Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text('Looking for ride requests\u2026', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
          ]),
        );
      } else {
        child = ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
          child: ListView(shrinkWrap: true, children: [for (final r in open) Padding(padding: const EdgeInsets.only(bottom: 10), child: _requestCard(r))]),
        );
      }
    }
    return Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: child);
  }

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
