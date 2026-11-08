import 'dart:async';

import 'package:drop/service/DriverApplicationApi.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../components/DrawerComponent.dart';
import '../utils/Colors.dart';
import 'DocumentsScreen.dart';
import 'WalletScreen.dart';

/// Home of driver mode. Online toggle with wallet and document checks done by the server,
/// location sharing only while online and while the app is open.
/// Ride requests and the active trip arrive with the rides backend.
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

  bool get online => status['is_online'] == true;
  Map<String, dynamic> get wallet => Map<String, dynamic>.from((status['wallet'] ?? {}) as Map);
  Map<String, dynamic>? get block => status['online_block'] is Map ? Map<String, dynamic>.from(status['online_block'] as Map) : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(resume: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(resume: true);
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
        _requestsCard(),
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

  Widget _requestsCard() {
    return _card(
      child: Column(children: [
        Icon(Icons.local_taxi_outlined, size: 40, color: Colors.grey.shade500),
        const SizedBox(height: 8),
        const Text('Ride requests', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(online ? 'Waiting for requests. Ride requests will appear here.' : 'Go online to start receiving ride requests.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
      ]),
    );
  }
}
