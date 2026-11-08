import 'dart:async';

import 'package:drop/service/DriverApplicationApi.dart';
import 'package:drop/service/RideApi.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  bool get online => status['is_online'] == true;
  Map<String, dynamic> get wallet => Map<String, dynamic>.from((status['wallet'] ?? {}) as Map);
  Map<String, dynamic>? get block => status['online_block'] is Map ? Map<String, dynamic>.from(status['online_block'] as Map) : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _positionSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50)).listen((pos) async {
      if (DateTime.now().difference(_lastPing).inSeconds < 20) return;
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

  Future<void> _toggle(bool wantOnline) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (wantOnline) {
        if (!await _locationAllowed()) {
          setState(() => busy = false);
          return;
        }
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        await DriverApplicationApi.setOnline(true, latitude: pos.latitude, longitude: pos.longitude);
        _startSharing();
      } else {
        _stopSharing();
        await DriverApplicationApi.setOnline(false);
      }
      await _load();
    } on ApiFailure catch (e) {
      _say(e.message);
      await _load();
    } catch (_) {
      _say('Could not get your location. Please try again.');
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

  Future<void> _openMaps(double lat, double lng) async {
    try {
      await launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'), mode: LaunchMode.externalApplication);
    } catch (_) {
      _say('Could not open Google Maps.');
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

  Widget _ridesSection() {
    final a = active;
    if (a != null) return _activeTrip(a);
    if (!online) {
      return _card(
        child: Column(children: [
          Icon(Icons.local_taxi_outlined, size: 40, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          const Text('Ride requests', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Go online to start receiving ride requests.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
        ]),
      );
    }
    final open = requests.where((r) => _secondsLeft(r) > 0).toList();
    if (open.isEmpty) {
      return _card(
        child: Column(children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 10),
          const Text('Waiting for ride requests', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Requests near you will appear here. Keep this screen open.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
        ]),
      );
    }
    return Column(children: [for (final r in open) Padding(padding: const EdgeInsets.only(bottom: 12), child: _requestCard(r))]);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      drawer: DrawerComponent(),
      appBar: AppBar(
        title: const Text('DROP Driver'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(resume: true), child: const Text('Try again')),
          ]),
        ),
      );
    }
    final w = wallet;
    final b = block;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _onlineCard(b),
        const SizedBox(height: 12),
        _walletCard(w),
        if (b != null) ...[const SizedBox(height: 12), _blockCard(b)],
        const SizedBox(height: 12),
        _ridesSection(),
      ]),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  Widget _onlineCard(Map<String, dynamic>? b) {
    return _card(
      child: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: online ? Colors.green : Colors.grey)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(online ? 'You are online' : 'You are offline', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(online ? 'Sharing your location while this app is open.' : (b == null ? 'Go online to receive ride requests.' : 'Fix the issue below to go online.'),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ]),
        ),
        busy
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Switch(value: online, activeColor: primaryColor, onChanged: (online || b == null) ? _toggle : (_) => _say(b['message']?.toString() ?? 'You cannot go online yet.')),
      ]),
    );
  }

  String _money(dynamic v) => (v is num) ? v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2) : '0';

  Widget _walletCard(Map<String, dynamic> w) {
    return _card(
      child: Row(children: [
        Icon(Icons.account_balance_wallet_outlined, color: primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Driver wallet', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Balance ${_money(w['balance'])}  ·  needed to go online ${_money(w['minimum'])}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ]),
        ),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen())).then((_) => _load()), child: const Text('Top up')),
      ]),
    );
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
