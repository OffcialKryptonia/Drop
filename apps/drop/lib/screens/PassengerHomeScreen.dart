import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/DropMap.dart';
import '../components/LiveLocation.dart';
import '../components/RegionWatcher.dart';
import '../components/RouteGeometry.dart';
import '../components/drawer_component.dart';
import '../drop/services/drop_money.dart';
import '../drop/widgets/drop_email_prompt.dart';
import '../drop/widgets/drop_eta.dart';
import '../drop/screens/drop_route_screen.dart';
import '../drop/widgets/drop_ride_type_strip.dart';
import '../drop/widgets/drop_sos_sheet.dart';
import '../service/DriverApplicationApi.dart' show ApiFailure, DriverApplicationApi;
import '../service/RouteLineApi.dart';
import '../drop/widgets/drop_extras.dart';
import '../service/MapConfig.dart';
import '../service/RegionApi.dart';
import '../service/RideApi.dart';
import '../service/PushService.dart';
import '../service/ToneService.dart';
import '../utils/Colors.dart';

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<dynamic> _l(dynamic v) => v is List ? v : <dynamic>[];
double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
String _money(dynamic v, [dynamic currency]) => DropMoney.format(v, currency);

enum _Phase { loading, plan, choose, trip, done }

/// Passenger home: pick where you are going, choose a ride type (prices come from the server),
/// request, follow the driver, and see the receipt. Replaces the old dashboard.
class PassengerHomeScreen extends StatefulWidget {
  final String? cancelReason;

  const PassengerHomeScreen({Key? key, this.cancelReason}) : super(key: key);

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _search = TextEditingController();
  final DropMapController _map = DropMapController();
  late final LiveLocation _live = LiveLocation(onFix: _onFix);
  final RegionWatcher _region = RegionWatcher();
  bool _pickupAuto = true; // the pickup follows the phone until the passenger chooses another From
  DateTime _addrAt = DateTime.fromMillisecondsSinceEpoch(0);
  MapConfig mapConfig = const MapConfig();
  List<List<LatLng>> regionBoundaries = const [];
  bool mapLoaded = false;
  Timer? _poll;
  Timer? _idle;

  _Phase phase = _Phase.loading;
  bool busy = false;

  LatLng? pickup;
  List<LatLng> _routeFull = const [];
  String? _routeKey;
  String? _shownEnds;
  LatLng? _routeFrom;
  LatLng? _prevDriver;
  double _heading = 0;
  String pickupAddress = 'Your location';
  LatLng center = const LatLng(9.0765, 7.3986); // Abuja until we know where the person is
  String dropAddress = '';
  final List<Map<String, dynamic>> additionalStops = [];
  int maxAdditionalStops = 0;
  List<Map<String, dynamic>> homeTypes = [];
  int? homeType;
  List<Map<String, dynamic>> recents = [];
  bool pinMode = false;
  bool pinForPickup = false; // the pin is choosing the pickup (From), not the drop-off
  bool pinForStop = false;
  String pinPickupAddress = '';
  bool locating = true;

  Map<String, dynamic> quote = {};
  int? selectedType;
  String payment = 'cash';
  final Set<int> extras = {};

  Map<String, dynamic>? ride; // the open ride
  int? lastRideId;
  Map<String, dynamic>? finished; // completed / cancelled / expired ride to show once
  int _stars = 0; // rating given for the finished ride
  bool _rated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    PushService.askPermission(); // the person is signed in here, so this is a good moment to ask
    _checkTransfers();
    _checkExtras();
    _transferTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _checkTransfers();
      _checkExtras();
    });
  }

  Timer? _transferTimer;
  int _lastTransferId = -1; // -1: not read yet, so the first look never rings for old transfers

  bool _extraOpen = false;
  final Set<int> _extraAsked = {};

  /// A driver added a toll, parking or waiting charge after accepting (before pickup): ask the passenger to approve and pay, or decline.
  Future<void> _checkExtras() async {
    if (!mounted || _extraOpen) return;
    try {
      final r = await RideApi.pendingExtras();
      final list = _l(r['data']).map(_m).where((e) => !_extraAsked.contains((e['id'] as num).toInt())).toList();
      if (list.isEmpty || !mounted) return;
      final e = list.first;
      _extraAsked.add((e['id'] as num).toInt()); // do not nag again for one the passenger closed without answering
      _extraOpen = true;
      final id = (e['id'] as num).toInt();
      final answered = await showDropExtraRequestSheet(context, e, walletBalance: (r['wallet_balance'] as num?) ?? 0);
      if (!answered) Future.delayed(const Duration(minutes: 5), () => _extraAsked.remove(id)); // closed without answering: ask again later
    } catch (_) {
    } finally {
      _extraOpen = false;
    }
  }

  /// Rings when another passenger has sent money: a new "transfer_in" appears in the wallet ledger.
  Future<void> _checkTransfers() async {
    if (!mounted) return;
    try {
      final r = await DriverApplicationApi.getJson('wallet-list?per_page=10');
      final data = r['data'];
      if (data is! List) return;
      var newest = 0;
      for (final e in data) {
        if (e is Map && e['transaction_type'] == 'transfer_in') {
          final id = int.tryParse('${e['id']}') ?? 0;
          if (id > newest) newest = id;
        }
      }
      if (_lastTransferId >= 0 && newest > _lastTransferId) ToneService.play(ToneEvent.passengerTransfer);
      if (newest > _lastTransferId) _lastTransferId = newest;
      if (_lastTransferId < 0) _lastTransferId = 0;
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live.dispose();
    _poll?.cancel();
    _transferTimer?.cancel();
    _idle?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && phase == _Phase.trip) _tick();
  }

  void _say(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------- startup ----------

  Future<void> _start() async {
    mapConfig = await MapConfig.load();
    try { maxAdditionalStops = await RideApi.stopLimit(); } catch (_) { maxAdditionalStops = 0; }
    if (mapConfig.mapboxRegionBorderingEnabled) {
      try { regionBoundaries = await RegionApi.boundaries(); } catch (_) { regionBoundaries = const []; }
    }
    if (mounted) setState(() => mapLoaded = true);
    DropMoney.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) DropEmailPrompt.maybeShow(context);
    });
    await _locate();
    try {
      final r = _m((await RideApi.current())['data']);
      if (r.isNotEmpty) {
        _setRide(r);
        return;
      }
    } on ApiFailure catch (e) {
      _say(e.message);
    }
    if (mounted) setState(() => phase = _Phase.plan);
  }

  /// Every real GPS fix: ask about a region change, and keep the automatic pickup under the passenger.
  void _onFix(Position p) {
    final here = LatLng(p.latitude, p.longitude);
    if (mounted) _region.check(context, here, onSwitched: _loadHome, regionBoundaries: regionBoundaries, useMapboxGeometry: mapConfig.mapboxRegionBorderingEnabled, accuracyMeters: p.accuracy);
    final cur = pickup;
    if (!_pickupAuto || phase != _Phase.plan || pinMode || cur == null) return;
    if (RouteGeometry.meters(cur, here) < 40) return;
    setState(() => pickup = here);
    if (DateTime.now().difference(_addrAt).inSeconds >= 8) {
      _addrAt = DateTime.now();
      _addressOf(here, fallback: pickupAddress).then((a) {
        if (mounted && _pickupAuto && pickup == here) setState(() => pickupAddress = a);
      });
    }
  }

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('off');
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw Exception('denied');
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      pickup = LatLng(pos.latitude, pos.longitude);
      _pickupAuto = true;
      _live.start(seed: pickup);
      center = pickup!;
      pickupAddress = await _addressOf(pickup!, fallback: 'Your location');
      _map.animateTo(pickup!, zoom: 17);
    } catch (_) {
      _say('Turn on location and allow DROP to use it, so we know where to pick you up.');
    }
    if (mounted) setState(() => locating = false);
    _loadHome();
  }

  /// Ride types at the pickup point, and the last places the passenger went.
  Future<void> _loadHome() async {
    final p = pickup;
    if (p == null) return;
    try {
      final r = await RideApi.rideTypes(p.latitude, p.longitude);
      final t = _l(r['ride_types']).map(_m).toList();
      if (mounted) {
        setState(() {
          homeTypes = t;
          if (homeType == null || !t.any((x) => (x['id'] as num).toInt() == homeType)) homeType = t.isEmpty ? null : (t.first['id'] as num).toInt();
        });
      }
    } catch (_) {}
    try {
      final seen = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final x in _l((await RideApi.history())['data']).map(_m)) {
        final d = _m(x['dropoff']);
        final a = d['address']?.toString() ?? '';
        if (a.isEmpty || d['lat'] == null || !seen.add(a)) continue;
        out.add(d);
        if (out.length == 4) break;
      }
      if (mounted) setState(() => recents = out);
    } catch (_) {}
  }

  Future<String> _addressOf(LatLng p, {String fallback = ''}) async {
    try {
      final list = await placemarkFromCoordinates(p.latitude, p.longitude);
      if (list.isNotEmpty) {
        final x = list.first;
        final parts = <String>[
          if ((x.name ?? '').isNotEmpty && x.name != x.street) x.name!,
          if ((x.street ?? '').isNotEmpty) x.street!,
          if ((x.subLocality ?? '').isNotEmpty) x.subLocality!,
          if ((x.locality ?? '').isNotEmpty) x.locality!,
        ];
        final seen = <String>{};
        final text = parts.where(seen.add).take(3).join(', ');
        if (text.isNotEmpty) return text;
      }
    } catch (_) {}
    return fallback;
  }

  // ---------- plan: choose the drop-off ----------

  void _onCameraMove(LatLng p) {
    center = p;
  }

  void _onCameraIdle(LatLng p) {
    center = p;
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 400), () async {
      final a = await _addressOf(center);
      if (!mounted || phase != _Phase.plan) return;
      setState(() { if (pinForPickup) { pinPickupAddress = a; } else { dropAddress = a; } });
    });
  }

  Future<bool> _searchPlace() async {
    final q = _search.text.trim();
    if (q.isEmpty) return false;
    FocusScope.of(context).unfocus();
    try {
      final found = await locationFromAddress(q);
      if (found.isEmpty) {
        _say('We could not find that place. Try a nearby landmark or move the pin yourself.');
        return false;
      }
      final target = LatLng(found.first.latitude, found.first.longitude);
      center = target;
      _map.animateTo(target, zoom: 17);
      return true;
    } catch (_) {
      _say('We could not find that place. Try a nearby landmark or move the pin yourself.');
      return false;
    }
  }

  /// "Enter your route": search, Suggested and Saved places. Choosing a place goes straight to prices.
  Future<void> _openRouteScreen({bool addingStop = false}) async {
    if (pickup == null) {
      await _locate();
      if (pickup == null) return;
    }
    final routeOrigin = addingStop && additionalStops.isNotEmpty ? LatLng(_d(additionalStops.last['lat']), _d(additionalStops.last['lng'])) : pickup!;
    final routeOriginAddress = addingStop && additionalStops.isNotEmpty ? additionalStops.last['address']?.toString() ?? pickupAddress : pickupAddress;
    final r = await Navigator.of(context).push<DropRouteResult>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => DropRouteScreen(pickup: routeOrigin, pickupAddress: routeOriginAddress, recents: recents, selectionLabel: addingStop ? 'Stop' : 'To')),
    );
    if (r == null || !mounted) return;
    if (r.pickup != null && !addingStop) {
      _pickupAuto = false;
      setState(() {
        pickup = r.pickup;
        pickupAddress = r.pickupAddress ?? pickupAddress;
      });
      _map.animateTo(r.pickup!);
    }
    if (r.kind == 'mapFrom') {
      _pickupAuto = false;
      setState(() {
        pinForPickup = true;
        pinMode = true;
        pinPickupAddress = pickupAddress;
        center = pickup ?? center;
      });
      if (pickup != null) _map.animateTo(pickup!, zoom: 17);
      return;
    }
    if (r.kind == 'mapDrop') {
      setState(() { pinForPickup = false; pinForStop = addingStop; pinMode = true; });
      return;
    }
    if (r.kind == 'stop' && r.point != null) {
      setState(() => additionalStops.add({'lat': r.point!.latitude, 'lng': r.point!.longitude, 'address': r.address}));
      return;
    }
    if (r.point != null) {
      center = r.point!;
      dropAddress = r.address;
      await _confirmDropoff();
    }
  }

  void _goToRecent(Map<String, dynamic> d) {
    center = LatLng(_d(d['lat']), _d(d['lng']));
    dropAddress = d['address']?.toString() ?? '';
    _confirmDropoff();
  }

  Widget _recentTile(Map<String, dynamic> d, {required VoidCallback onTap}) {
    final full = d['address']?.toString() ?? '';
    final i = full.indexOf(',');
    final title = i > 0 ? full.substring(0, i) : full;
    final sub = i > 0 ? full.substring(i + 1).trim() : '';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(Icons.access_time, color: Colors.grey.shade700),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }

  /// The pin was moved to the right pickup: use it and refresh the ride types for that spot.
  void _confirmPickup() {
    setState(() {
      pickup = center;
      if (pinPickupAddress.isNotEmpty) pickupAddress = pinPickupAddress;
      _pickupAuto = false;
      pinMode = false;
      pinForPickup = false;
    });
    _loadHome();
  }

  Future<void> _confirmStop() async {
    if (busy || additionalStops.length >= maxAdditionalStops) return;
    setState(() => busy = true);
    try {
      final address = await _addressOf(center, fallback: 'Selected stop');
      if (!mounted) return;
      setState(() {
        additionalStops.add({'lat': center.latitude, 'lng': center.longitude, 'address': address});
        pinMode = false;
        pinForStop = false;
      });
    } catch (_) {
      _say('Could not confirm this stop. Please try again.');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _confirmDropoff() async {
    if (pickup == null) {
      setState(() => locating = true);
      await _locate();
      if (pickup == null) return;
    }
    if (busy) return;
    setState(() => busy = true);
    try {
      final drop = dropAddress.isEmpty ? await _addressOf(center, fallback: 'Selected place') : dropAddress;
      quote = await RideApi.estimate(
        pickupLat: pickup!.latitude,
        pickupLng: pickup!.longitude,
        pickupAddress: pickupAddress,
        dropLat: center.latitude,
        dropLng: center.longitude,
        dropAddress: drop,
        stops: List<Map<String, dynamic>>.from(additionalStops),
      );
      dropAddress = drop;
      final types = _l(quote['ride_types']);
      if (types.isEmpty) {
        _say('No ride types are available for this trip right now.');
      } else {
        selectedType = null;
        extras.clear();
        _pickType(_m(types.firstWhere((t) => (_m(t)['id'] as num).toInt() == homeType, orElse: () => types.first)));
        phase = _Phase.choose;
      }
    } on ApiFailure catch (e) {
      _say(e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  // ---------- choose: ride type, payment, extras ----------

  void _pickType(Map<String, dynamic> t) {
    selectedType = (t['id'] as num).toInt();
    final methods = _l(t['payment_methods']).map((e) => e.toString()).toList();
    if (!methods.contains(payment)) payment = methods.contains('cash') ? 'cash' : (methods.isEmpty ? 'cash' : methods.first);
  }

  Map<String, dynamic> get _type => _l(quote['ride_types']).map(_m).firstWhere((t) => (t['id'] as num).toInt() == selectedType, orElse: () => <String, dynamic>{});

  double get _total {
    final t = _type;
    var sum = _d(t['fare']);
    for (final o in _l(quote['options']).map(_m)) {
      if (extras.contains((o['id'] as num).toInt())) sum += _d(o['price']);
    }
    return sum;
  }

  Future<void> _requestRide() async {
    final t = _type;
    if (t.isEmpty || busy) return;
    setState(() => busy = true);
    try {
      final res = await RideApi.request(
        pickupLat: pickup!.latitude,
        pickupLng: pickup!.longitude,
        pickupAddress: pickupAddress,
        dropLat: center.latitude,
        dropLng: center.longitude,
        dropAddress: dropAddress,
        serviceId: selectedType!,
        paymentMethod: payment,
        optionIds: extras.toList(),
        stops: List<Map<String, dynamic>>.from(additionalStops),
      );
      _setRide(_m(res['data']));
    } on ApiFailure catch (e) {
      _say(e.message);
      if (RideApi.lastCode == 'already_has_ride') _start();
    }
    if (mounted) setState(() => busy = false);
  }

  // ---------- trip ----------

  void _setRide(Map<String, dynamic> r) {
    ride = r;
    lastRideId = (r['id'] as num).toInt();
    finished = null;
    phase = _Phase.trip;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitTrip());
  }

  bool _ticking = false;

  Future<void> _tick() async {
    if (_ticking || !mounted) return;
    _ticking = true;
    try {
      final r = _m((await RideApi.current())['data']);
      if (r.isNotEmpty) {
        final changed = ride?['status'] != r['status'];
        if (changed && ride?['status'] == 'searching' && r['status'] == 'accepted') ToneService.play(ToneEvent.passengerAccepted);
        if (mounted) setState(() { ride = r; _trackHeading(); });
        if (changed) _fitTrip();
        if (r['status'] == 'accepted') _checkExtras();
      } else {
        await _rideEnded();
      }
    } catch (_) {
      // a missed poll is fine, the next one will catch up
    }
    _ticking = false;
  }

  Future<void> _rideEnded() async {
    _poll?.cancel();
    Map<String, dynamic>? last;
    try {
      final h = _l((await RideApi.history())['data']).map(_m);
      for (final x in h) {
        if ((x['id'] as num).toInt() == lastRideId) {
          last = x;
          break;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      finished = last ?? {'status': 'cancelled'};
      ride = null;
      phase = _Phase.done;
    });
  }

  Future<void> _cancel() async {
    final r = ride;
    if (r == null) return;
    final status = r['status'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this ride?'),
        content: Text(status == 'searching'
            ? 'We will stop looking for a driver.'
            : 'A driver is already on the way. A cancellation fee may apply if you cancel now.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep ride')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel ride')),
        ],
      ),
    );
    if (ok != true || busy) return;
    setState(() => busy = true);
    try {
      final res = await RideApi.cancel();
      final fee = _d(res['cancellation_fee']);
      _poll?.cancel();
      ride = null;
      phase = _Phase.plan;
      _say(fee > 0 ? 'Ride cancelled. A cancellation fee of ${_money(fee, ride?['currency'])} was charged to your wallet.' : 'Ride cancelled.');
    } on ApiFailure catch (e) {
      _say(e.message);
      _tick();
    }
    if (mounted) setState(() => busy = false);
  }

  /// Shares a link that lets a friend or family member follow this trip live.
  Future<void> _share() async {
    try {
      final res = await RideApi.shareTrip();
      await SharePlus.instance.share(ShareParams(text: res['message']?.toString() ?? res['url'].toString()));
    } on ApiFailure catch (e) {
      _say(e.message);
    } catch (_) {
      _say('Could not create the share link. Please try again.');
    }
  }

  /// PayMyRide: shares a link so someone else can pay this ride's fare.
  Future<void> _payLink() async {
    try {
      final res = await RideApi.payLink();
      await SharePlus.instance.share(ShareParams(text: res['message']?.toString() ?? res['url'].toString()));
    } on ApiFailure catch (e) {
      _say(e.message);
    } catch (_) {
      _say('Could not create the payment link. Please try again.');
    }
  }

  Future<void> _call(String? number) async {
    if (number == null || number.isEmpty) return;
    try {
      await launchUrl(Uri.parse('tel:$number'));
    } catch (_) {
      _say('Could not open the phone app.');
    }
  }

  void _fitTrip() {
    final r = ride;
    if (r == null) return;
    final pts = <LatLng>[
      LatLng(_d(_m(r['pickup'])['lat']), _d(_m(r['pickup'])['lng'])),
      LatLng(_d(_m(r['dropoff'])['lat']), _d(_m(r['dropoff'])['lng'])),
      for (final stop in _l(r['stops']).map(_m)) LatLng(_d(stop['lat']), _d(stop['lng'])),
    ];
    final loc = _m(_m(r['driver'])['location']);
    if (loc.isNotEmpty) pts.add(LatLng(_d(loc['lat']), _d(loc['lng'])));
    _map.fitPoints(pts);
  }

  Future<void> _rate(int stars) async {
    final id = finished?['id'];
    if (id == null || _rated) return;
    setState(() => _stars = stars);
    try {
      await RideApi.rate(id, stars);
      if (mounted) setState(() => _rated = true);
    } on ApiFailure catch (e) {
      _say(e.message);
    } catch (_) {
      _say('Could not save your rating.');
    }
  }

  void _newRide() {
    setState(() {
      _stars = 0;
      _rated = false;
      finished = null;
      ride = null;
      quote = {};
      additionalStops.clear();
      phase = _Phase.plan;
    });
    _locate();
  }

  // ---------- build ----------

  LatLng? get _driverRaw {
    final loc = _m(_m(ride?['driver'])['location']);
    return loc.isEmpty ? null : LatLng(_d(loc['lat']), _d(loc['lng']));
  }

  RouteSnap? get _driverSnap {
    final d = _driverRaw;
    if (d == null) return null;
    final s = RouteGeometry.snap(_routeFull, d);
    return s != null && s.meters < 80 ? s : null;
  }

  /// The line still ahead of the vehicle: the part already driven is cleared.
  List<LatLng> get _route {
    final s = _driverSnap;
    return s == null ? _routeFull : RouteGeometry.remaining(_routeFull, s);
  }

  /// The vehicle sits exactly on the route line when it is close to it.
  LatLng? get _vehiclePoint => _driverSnap?.point ?? _driverRaw;

  /// Which way the vehicle faces: its movement since the last update, or the road direction at first sight.
  void _trackHeading() {
    final d = _driverRaw;
    if (d == null) {
      _prevDriver = null;
      return;
    }
    final prev = _prevDriver;
    if (prev == null) {
      _prevDriver = d;
      final s = RouteGeometry.snap(_routeFull, d);
      if (s != null && s.index + 1 < _routeFull.length) _heading = RouteGeometry.bearing(_routeFull[s.index], _routeFull[s.index + 1]);
    } else if (RouteGeometry.meters(prev, d) >= 5) {
      _heading = RouteGeometry.bearing(prev, d);
      _prevDriver = d;
    }
  }

  /// Loads the road line: pickup -> drop-off as soon as prices are shown, then driver -> pickup while the driver
  /// is coming, then pickup -> drop-off again. A line fetched before is shown at once.
  void _syncRoute() {
    final r = ride;
    final waypoints = <LatLng>[];
    String key;
    var toPickup = false;
    final drv = _driverRaw;
    if (phase == _Phase.choose && pickup != null) {
      waypoints.add(pickup!);
      waypoints.addAll(additionalStops.map((s) => LatLng(_d(s['lat']), _d(s['lng']))));
      waypoints.add(center);
      key = 'choose';
    } else if (phase == _Phase.trip && r != null) {
      final pick = LatLng(_d(_m(r['pickup'])['lat']), _d(_m(r['pickup'])['lng']));
      final drop = LatLng(_d(_m(r['dropoff'])['lat']), _d(_m(r['dropoff'])['lng']));
      final status = r['status'];
      toPickup = (status == 'accepted' || status == 'arrived') && drv != null;
      if (toPickup) {
        waypoints.add(drv!);
        waypoints.add(pick);
      } else {
        waypoints.add(pick);
        for (final stop in _l(r['stops']).map(_m)) {
          if (stop['status'] != 'completed') waypoints.add(LatLng(_d(stop['lat']), _d(stop['lng'])));
        }
        waypoints.add(drop);
      }
      key = '${r['id']}:${toPickup ? 'toPickup' : 'trip'}';
    } else {
      if (_routeFull.isNotEmpty || _routeKey != null) setState(() { _routeFull = const []; _routeKey = null; _routeFrom = null; _prevDriver = null; });
      return;
    }
    final moved = toPickup && _routeFrom != null && RouteGeometry.meters(_routeFrom!, drv!) > 250;
    final target = '$key:${waypoints.map((p) => '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}').join('|')}';
    if (target == _routeKey && !moved) return;
    _routeKey = target;
    _routeFrom = waypoints.first;
    if (!moved) setState(() => _routeFull = const []);
    () async {
      final all = <LatLng>[];
      for (var i = 0; i < waypoints.length - 1; i++) {
        final segment = await RouteLineApi.fetch(waypoints[i], waypoints[i + 1]);
        if (segment.isNotEmpty) all.addAll(all.isEmpty ? segment : segment.skip(1));
      }
      if (!mounted || _routeKey != target) return;
      setState(() => _routeFull = all);
      if (all.length > 1 && key == 'choose') _map.fitPoints([...waypoints, ...all]);
    }();
  }

  List<DropMarker> get _markers {
    final out = <DropMarker>[];
    if (phase == _Phase.trip && ride != null) {
      final r = ride!;
      out.add(DropMarker(id: 'pickup', title: 'Pickup', color: Colors.green, point: LatLng(_d(_m(r['pickup'])['lat']), _d(_m(r['pickup'])['lng']))));
      out.add(DropMarker(id: 'drop', title: 'Drop-off', color: Colors.red, point: LatLng(_d(_m(r['dropoff'])['lat']), _d(_m(r['dropoff'])['lng']))));
      for (final stop in _l(r['stops']).map(_m)) {
        out.add(DropMarker(id: 'stop-${stop['id']}', title: 'Stop ${stop['sequence']}', color: stop['status'] == 'completed' ? Colors.grey : Colors.orange, point: LatLng(_d(stop['lat']), _d(stop['lng']))));
      }
      final v = _vehiclePoint;
      if (v != null) {
        final key = _m(r['service'])['map_icon']?.toString() ?? 'car';
        out.add(DropMarker(id: 'driver', title: 'Your driver', color: Colors.blue, point: v, iconKey: key, heading: _heading));
      }
    } else if (pickup != null) {
      out.add(DropMarker(id: 'pickup', title: 'Pickup', color: Colors.green, point: pickup!));
      if (phase == _Phase.choose) out.add(DropMarker(id: 'drop', title: 'Drop-off', color: Colors.red, point: center));
      if (phase == _Phase.plan || phase == _Phase.choose) {
        for (var i = 0; i < additionalStops.length; i++) {
          final stop = additionalStops[i];
          out.add(DropMarker(id: 'stop-${i + 1}', title: 'Stop ${i + 1}', color: Colors.orange, point: LatLng(_d(stop['lat']), _d(stop['lng']))));
        }
      }
    }
    // The passenger: an arrow that moves with the phone and turns as it turns.
    final me = _live.point;
    final riding = phase == _Phase.trip && ride?['status'] == 'in_progress';
    if (me != null && !riding) out.add(DropMarker(id: 'me', title: 'You', color: Colors.blue, point: me, iconKey: 'me', heading: _live.heading));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _syncRoute(); });
    final planning = phase == _Phase.plan;
    final pinning = planning && pinMode;
    final home = planning && !pinMode;
    return Scaffold(
      key: _scaffoldKey,
      drawer: DrawerComponent(),
      body: Stack(children: [
        Positioned.fill(
          child: !mapLoaded
              ? const ColoredBox(color: Color(0xFFEFEFEF))
              : AnimatedBuilder(animation: _live, builder: (_, __) => DropMap(
            provider: mapConfig.provider,
            tileUrl: mapConfig.tileUrl,
            attribution: mapConfig.attribution,
            mapboxStyleUri: mapConfig.mapboxStyleUri,
            showRegionBorders: mapConfig.mapboxRegionBorderingEnabled,
            regionBoundaries: regionBoundaries,
            initialCenter: pickup ?? center,
            controller: _map,
            showMyLocation: false,
            markers: _markers,
            routePoints: _route,
            onMove: pinning ? _onCameraMove : null,
            onIdle: pinning ? _onCameraIdle : null,
          )),
        ),
        if (pinning) Center(child: Padding(padding: const EdgeInsets.only(bottom: 36), child: Icon(Icons.location_pin, size: 44, color: pinForPickup ? Colors.green : const Color(0xFFE5441A)))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                _roundButton(Icons.menu, () => _scaffoldKey.currentState?.openDrawer()),
                const SizedBox(width: 10),
                if (pinning) Expanded(child: _searchBar()),
                if (pinning) ...[const SizedBox(width: 10), _roundButton(Icons.arrow_back, () => setState(() { pinMode = false; pinForPickup = false; pinForStop = false; }))],
                if (phase == _Phase.choose) _roundButton(Icons.arrow_back, () => setState(() => phase = _Phase.plan)),
              ]),
              if (home)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: locating ? null : _openRouteScreen,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Pickup point', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              Text(locating ? 'Finding your location…' : pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.chevron_right),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        if (home) _homeSheet() else Align(alignment: Alignment.bottomCenter, child: _bottom()),
      ]),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: Colors.black87))),
      );

  Widget _searchBar() => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        elevation: 3,
        child: TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _searchPlace(),
          decoration: InputDecoration(
            hintText: 'Search a place, or move the map',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _searchPlace),
          ),
        ),
      );

  Widget _sheet(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
        ),
        child: SafeArea(top: false, child: child),
      );

  Widget _bottom() {
    switch (phase) {
      case _Phase.loading:
        return _sheet(const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())));
      case _Phase.plan:
        return _planSheet();
      case _Phase.choose:
        return _chooseSheet();
      case _Phase.trip:
        return _tripSheet();
      case _Phase.done:
        return _doneSheet();
    }
  }

  /// The home sheet can be dragged: smaller to see more map, larger to see more recent places.
  Widget _homeSheet() => Positioned.fill(
        child: DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.27,
          maxChildSize: 0.88,
          snap: true,
          snapSizes: const [0.27, 0.5, 0.88],
          builder: (context, scroll) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
            ),
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(16, 0, 16, 18 + MediaQuery.of(context).padding.bottom),
              children: [
                Center(child: Container(width: 44, height: 5, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4)))),
                if (homeTypes.isNotEmpty) ...[
                  DropRideTypeStrip(types: homeTypes, selected: homeType, onTap: (t) => setState(() => homeType = (t['id'] as num).toInt())),
                  const SizedBox(height: 10),
                ],
                Material(
                  color: const Color(0xFFF1F0EC),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _openRouteScreen,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(children: [
                        Icon(Icons.search),
                        SizedBox(width: 14),
                        Expanded(child: Text('Where to & for how much?', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                for (final r in recents) _recentTile(r, onTap: () => _goToRecent(r)),
              ],
            ),
          ),
        ),
      );

  Widget _pickupSheet() => _sheet(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.my_location, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(pinPickupAddress.isEmpty ? 'Move the map to choose your pickup' : pinPickupAddress, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _confirmPickup,
            child: const Text('Confirm pickup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]));

  Widget _planSheet() => pinForPickup ? _pickupSheet() : (pinForStop ? _sheet(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Move the map to choose your additional stop.', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: busy ? null : _confirmStop, child: busy ? const CircularProgressIndicator() : const Text('Confirm this stop'))),
      ])) : _sheet(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.my_location, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(locating ? 'Finding your location…' : pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.location_on, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text(dropAddress.isEmpty ? 'Move the map to choose your drop-off' : dropAddress, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        if (maxAdditionalStops > 0) ...[
          const SizedBox(height: 10),
          for (var i = 0; i < additionalStops.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.more_vert, color: primaryColor, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Stop ${i + 1}: ${additionalStops[i]['address']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                IconButton(tooltip: 'Move stop up', onPressed: busy || i == 0 ? null : () => setState(() { final x = additionalStops.removeAt(i); additionalStops.insert(i - 1, x); }), icon: const Icon(Icons.arrow_upward, size: 18)),
                IconButton(tooltip: 'Move stop down', onPressed: busy || i == additionalStops.length - 1 ? null : () => setState(() { final x = additionalStops.removeAt(i); additionalStops.insert(i + 1, x); }), icon: const Icon(Icons.arrow_downward, size: 18)),
                IconButton(tooltip: 'Remove stop', onPressed: busy ? null : () => setState(() => additionalStops.removeAt(i)), icon: const Icon(Icons.close, size: 18)),
              ]),
            ),
          if (additionalStops.length < maxAdditionalStops)
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: busy ? null : () => _openRouteScreen(addingStop: true), icon: const Icon(Icons.add_location_alt_outlined), label: Text('Add stop (${additionalStops.length}/$maxAdditionalStops)'))),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: busy ? null : _confirmDropoff,
            child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirm drop-off', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ])));

  Widget _chooseSheet() {
    final types = _l(quote['ride_types']).map(_m).toList();
    final options = _l(quote['options']).map(_m).toList();
    final t = _type;
    final methods = _l(t['payment_methods']).map((e) => e.toString()).toList();
    final unit = quote['distance_unit']?.toString() ?? 'km';
    return _sheet(ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${_d(quote['distance']).toStringAsFixed(1)} $unit · about ${_d(quote['duration_minutes']).round()} min'
          '${t['pickup_eta_minutes'] != null ? ' · arrive about ${dropClock(DateTime.now().add(Duration(minutes: (t['pickup_eta_minutes'] as num).round() + _d(quote['duration_minutes']).round())))}' : ''}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView(shrinkWrap: true, children: [
            for (final x in types) _typeTile(x),
            if (options.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (final o in options)
                  FilterChip(
                    label: Text('${o['name']}  +${_money(o['price'], quote['currency'])}'),
                    selected: extras.contains((o['id'] as num).toInt()),
                    onSelected: (v) => setState(() => v ? extras.add((o['id'] as num).toInt()) : extras.remove((o['id'] as num).toInt())),
                  ),
              ]),
            ],
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final m in methods)
                ChoiceChip(label: Text(m == 'cash' ? 'Cash' : (m == 'wallet' ? 'Wallet' : (m == 'card' ? 'Card' : m))), selected: payment == m, onSelected: (_) => setState(() => payment = m)),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: (busy || t.isEmpty) ? null : _requestRide,
            child: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(t.isEmpty ? 'Choose a ride' : 'Request ${t['name']} · ${_money(_total, quote['currency'])}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ));
  }

  Widget _typeTile(Map<String, dynamic> x) {
    final id = (x['id'] as num).toInt();
    final selected = id == selectedType;
    final nearby = (x['drivers_nearby'] as num?)?.toInt() ?? 0;
    final eta = x['pickup_eta_minutes'];
    return GestureDetector(
      onTap: () => setState(() => _pickType(x)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? primaryColor : Colors.grey.shade300, width: selected ? 2 : 1),
          color: selected ? primaryColor.withValues(alpha: 0.06) : Colors.white,
        ),
        child: Row(children: [
          Icon(Icons.local_taxi, color: selected ? primaryColor : Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${x['name']}  ·  ${x['capacity'] ?? ''} seats', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(nearby > 0 ? (eta == null ? '$nearby nearby' : 'Driver ~$eta min away · $nearby nearby') : 'No drivers nearby right now', style: TextStyle(color: nearby > 0 ? Colors.grey.shade700 : Colors.orange.shade800, fontSize: 12)),
            ]),
          ),
          Text(_money(x['fare'], quote['currency']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      ),
    );
  }

  Widget _tripSheet() {
    final r = ride ?? {};
    final status = r['status']?.toString() ?? 'searching';
    final driver = _m(r['driver']);
    final v = _m(driver['vehicle']);
    String title;
    String sub = '';
    switch (status) {
      case 'accepted':
        title = 'Your driver is on the way';
        break;
      case 'arrived':
        title = 'Your driver has arrived';
        sub = 'Meet them at the pickup point.';
        break;
      case 'in_progress':
        title = 'On your way';
        sub = 'Heading to ${_m(r['dropoff'])['address'] ?? 'your drop-off'}.';
        break;
      default:
        title = 'Finding you a driver…';
        sub = 'This usually takes a minute. We will keep looking until the request expires.';
    }
    final vehicle = [v['colour'], v['make'], v['model']].where((e) => e != null && e.toString().isNotEmpty).join(' ');
    return _sheet(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (status == 'searching') const Padding(padding: EdgeInsets.only(right: 12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        Text(_money(r['fare'], r['currency']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
      if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, style: TextStyle(color: Colors.grey.shade700))),
      for (final stop in _l(r['stops']).map(_m))
        Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [Icon(stop['status'] == 'completed' ? Icons.check_circle : Icons.location_on_outlined, size: 17, color: stop['status'] == 'completed' ? Colors.green : primaryColor), const SizedBox(width: 8), Expanded(child: Text('Stop ${stop['sequence']}: ${stop['address'] ?? 'Additional stop'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))), Text(stop['status']?.toString() ?? 'pending', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))])),
      if (r['eta'] is Map) ...[
        const SizedBox(height: 10),
        DropEtaStrip(eta: _m(r['eta'])),
      ],
      if (r['pickup_code'] is Map && (r['pickup_code'] as Map)['code'] != null) ...[
        const SizedBox(height: 12),
        DropPickupCodeCard(code: '${(r['pickup_code'] as Map)['code']}'),
      ],
      if (driver.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(children: [
          CircleAvatar(backgroundColor: primaryColor.withValues(alpha: 0.12), child: Icon(Icons.person, color: primaryColor)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(driver['name']?.toString() ?? 'Your driver', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('$vehicle${v['plate'] != null ? '  ·  ${v['plate']}' : ''}', style: TextStyle(color: Colors.grey.shade700)),
            ]),
          ),
          IconButton(onPressed: () => _call(driver['contact_number']?.toString()), icon: Icon(Icons.call, color: primaryColor)),
        ]),
      ],
      if (driver.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: OutlinedButton.icon(
            onPressed: _share,
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share trip for safety'),
            style: OutlinedButton.styleFrom(foregroundColor: primaryColor, side: BorderSide(color: primaryColor), minimumSize: const Size.fromHeight(44)),
          ),
        ),
      if (driver.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: OutlinedButton.icon(
            onPressed: () => showDropSos(context, rideId: (r['id'] as num?)?.toInt()),
            icon: const Icon(Icons.sos, size: 18),
            label: const Text('SOS \u2013 I need help'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), minimumSize: const Size.fromHeight(44)),
          ),
        ),
      if (r['payment_method'] != 'wallet')
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: OutlinedButton.icon(
            onPressed: _payLink,
            icon: const Icon(Icons.request_quote_outlined, size: 18),
            label: const Text('Let someone pay for this ride'),
            style: OutlinedButton.styleFrom(foregroundColor: primaryColor, side: BorderSide(color: primaryColor), minimumSize: const Size.fromHeight(44)),
          ),
        ),
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.payments_outlined, size: 18),
        const SizedBox(width: 6),
        Text(r['payment_method'] == 'wallet' ? 'Paying from wallet' : 'Paying cash to the driver', style: TextStyle(color: Colors.grey.shade700)),
        const Spacer(),
        if (status != 'in_progress') TextButton(onPressed: busy ? null : _cancel, child: const Text('Cancel ride', style: TextStyle(color: Colors.red))),
      ]),
    ]));
  }

  Widget _doneSheet() {
    final f = finished ?? {};
    final status = f['status']?.toString();
    final done = status == 'completed';
    final expired = status == 'expired';
    final title = done ? 'You have arrived' : (expired ? 'No driver found' : 'Ride cancelled');
    final sub = done
        ? (f['paid_with'] == 'wallet' ? 'Paid from your wallet.' : 'Pay the driver in cash.')
        : (expired ? 'No driver accepted in time. Please try again.' : (_d(f['cancellation_fee']) > 0 ? 'A cancellation fee of ${_money(f['cancellation_fee'], f['currency'])} was charged.' : 'No charge was made.'));
    return _sheet(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(done ? Icons.check_circle : Icons.info_outline, color: done ? Colors.green : Colors.orange.shade800),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        if (done) Text(_money(f['fare'], f['currency']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 6),
      Text(sub, style: TextStyle(color: Colors.grey.shade700)),
      if (done) ...[
        const SizedBox(height: 6),
        Text('${_m(f['pickup'])['address'] ?? ''}  →  ${_m(f['dropoff'])['address'] ?? ''}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        for (final stop in _l(f['stops']).map(_m))
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('Stop ${stop['sequence']}: ${stop['address'] ?? 'Additional stop'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
      ],
      if (done && f['id'] != null) ...[
        const SizedBox(height: 12),
        Text(_rated ? 'Thanks for rating your driver!' : 'How was your driver?', style: const TextStyle(fontWeight: FontWeight.w700)),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _rated ? null : () => _rate(i),
                icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber.shade700, size: 32),
              ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _newRide,
          child: Text(done ? 'Done' : 'Book another ride', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    ]));
  }
}
