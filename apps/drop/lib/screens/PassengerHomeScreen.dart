import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/DropMap.dart';
import '../components/drawer_component.dart';
import '../drop/services/drop_money.dart';
import '../drop/widgets/drop_email_prompt.dart';
import '../service/DriverApplicationApi.dart' show ApiFailure;
import '../service/MapConfig.dart';
import '../service/RideApi.dart';
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
  MapConfig mapConfig = const MapConfig();
  bool mapLoaded = false;
  Timer? _poll;
  Timer? _idle;

  _Phase phase = _Phase.loading;
  bool busy = false;

  LatLng? pickup;
  String pickupAddress = 'Your location';
  LatLng center = const LatLng(9.0765, 7.3986); // Abuja until we know where the person is
  String dropAddress = '';
  bool locating = true;

  Map<String, dynamic> quote = {};
  int? selectedType;
  String payment = 'cash';
  final Set<int> extras = {};

  Map<String, dynamic>? ride; // the open ride
  int? lastRideId;
  Map<String, dynamic>? finished; // completed / cancelled / expired ride to show once

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
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

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('off');
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw Exception('denied');
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      pickup = LatLng(pos.latitude, pos.longitude);
      center = pickup!;
      pickupAddress = await _addressOf(pickup!, fallback: 'Your location');
      _map.animateTo(pickup!, zoom: 15);
    } catch (_) {
      _say('Turn on location and allow DROP to use it, so we know where to pick you up.');
    }
    if (mounted) setState(() => locating = false);
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
      if (mounted && phase == _Phase.plan) setState(() => dropAddress = a);
    });
  }

  Future<void> _searchPlace() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    try {
      final found = await locationFromAddress(q);
      if (found.isEmpty) {
        _say('We could not find that place. Try a nearby landmark or move the pin yourself.');
        return;
      }
      final target = LatLng(found.first.latitude, found.first.longitude);
      center = target;
      _map.animateTo(target, zoom: 16);
    } catch (_) {
      _say('We could not find that place. Try a nearby landmark or move the pin yourself.');
    }
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
      );
      dropAddress = drop;
      final types = _l(quote['ride_types']);
      if (types.isEmpty) {
        _say('No ride types are available for this trip right now.');
      } else {
        selectedType = null;
        extras.clear();
        _pickType(_m(types.first));
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
        if (mounted) setState(() => ride = r);
        if (changed) _fitTrip();
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
    ];
    final loc = _m(_m(r['driver'])['location']);
    if (loc.isNotEmpty) pts.add(LatLng(_d(loc['lat']), _d(loc['lng'])));
    _map.fitPoints(pts);
  }

  void _newRide() {
    setState(() {
      finished = null;
      ride = null;
      quote = {};
      phase = _Phase.plan;
    });
    _locate();
  }

  // ---------- build ----------

  List<DropMarker> get _markers {
    final out = <DropMarker>[];
    if (phase == _Phase.trip && ride != null) {
      final r = ride!;
      out.add(DropMarker(id: 'pickup', title: 'Pickup', color: Colors.green, point: LatLng(_d(_m(r['pickup'])['lat']), _d(_m(r['pickup'])['lng']))));
      out.add(DropMarker(id: 'drop', title: 'Drop-off', color: Colors.red, point: LatLng(_d(_m(r['dropoff'])['lat']), _d(_m(r['dropoff'])['lng']))));
      final loc = _m(_m(r['driver'])['location']);
      if (loc.isNotEmpty) out.add(DropMarker(id: 'driver', title: 'Your driver', color: Colors.blue, point: LatLng(_d(loc['lat']), _d(loc['lng']))));
    } else if (pickup != null) {
      out.add(DropMarker(id: 'pickup', title: 'Pickup', color: Colors.green, point: pickup!));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final planning = phase == _Phase.plan;
    return Scaffold(
      key: _scaffoldKey,
      drawer: DrawerComponent(),
      body: Stack(children: [
        Positioned.fill(
          child: !mapLoaded
              ? const ColoredBox(color: Color(0xFFEFEFEF))
              : DropMap(
            provider: mapConfig.provider,
            tileUrl: mapConfig.tileUrl,
            attribution: mapConfig.attribution,
            initialCenter: pickup ?? center,
            controller: _map,
            showMyLocation: pickup != null,
            markers: _markers,
            onMove: planning ? _onCameraMove : null,
            onIdle: planning ? _onCameraIdle : null,
          ),
        ),
        if (planning) const Center(child: Padding(padding: EdgeInsets.only(bottom: 36), child: Icon(Icons.location_pin, size: 44, color: Color(0xFFE5441A)))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _roundButton(Icons.menu, () => _scaffoldKey.currentState?.openDrawer()),
              const SizedBox(width: 10),
              if (planning) Expanded(child: _searchBar()),
              if (phase == _Phase.choose) _roundButton(Icons.arrow_back, () => setState(() => phase = _Phase.plan)),
            ]),
          ),
        ),
        Align(alignment: Alignment.bottomCenter, child: _bottom()),
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

  Widget _planSheet() => _sheet(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: busy ? null : _confirmDropoff,
            child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirm drop-off', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]));

  Widget _chooseSheet() {
    final types = _l(quote['ride_types']).map(_m).toList();
    final options = _l(quote['options']).map(_m).toList();
    final t = _type;
    final methods = _l(t['payment_methods']).map((e) => e.toString()).toList();
    final unit = quote['distance_unit']?.toString() ?? 'km';
    return _sheet(ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_d(quote['distance']).toStringAsFixed(1)} $unit · about ${_d(quote['duration_minutes']).round()} min', style: TextStyle(color: Colors.grey.shade700)),
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
              Text(nearby > 0 ? '${eta ?? '-'} min away · $nearby driver${nearby == 1 ? '' : 's'} nearby' : 'No drivers nearby right now', style: TextStyle(color: nearby > 0 ? Colors.grey.shade700 : Colors.orange.shade800, fontSize: 12)),
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
