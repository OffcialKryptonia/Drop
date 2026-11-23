import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../service/AirportTransfer.dart';
import '../../service/DriverApplicationApi.dart' show ApiFailure;
import '../../service/RideApi.dart';
import '../design/drop_design.dart';
import '../design/drop_theme.dart';
import '../services/drop_money.dart';
import 'drop_route_screen.dart';

/// Airport transfers: its own entry point, not part of the ordinary ride flow.
/// Airport Drop (zone to airport) and Airport Pickup (airport to zone). Airports, flight fields, eligibility and price all come
/// from the server. The booked ride is returned to the home screen, which tracks it through the normal ride lifecycle.
class DropAirportScreen extends StatefulWidget {
  const DropAirportScreen({super.key, required this.pickup, required this.pickupAddress, required this.recents});

  final LatLng pickup;
  final String pickupAddress;
  final List<Map<String, dynamic>> recents;

  @override
  State<DropAirportScreen> createState() => _DropAirportScreenState();
}

class _DropAirportScreenState extends State<DropAirportScreen> {
  bool _loading = true;
  String? _loadError;
  AirportConfig _config = const AirportConfig(airports: [], fields: {});

  String _direction = AirportDirection.drop;
  AirportInfo? _airport;
  LatLng? _place; // the zone end of the trip: the pickup for Airport Drop, the destination for Airport Pickup
  String _placeAddress = '';
  final Map<String, String> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  Map<String, String> _errors = {};

  Map<String, dynamic>? _quote;
  int? _typeId;
  String _payment = 'cash';
  bool _busy = false;
  String? _message;

  bool get _isDrop => _direction == AirportDirection.drop;

  @override
  void initState() {
    super.initState();
    _place = widget.pickup;
    _placeAddress = widget.pickupAddress;
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final c = AirportConfig.fromApi(await RideApi.airports());
      _config = c;
      if (c.airports.isNotEmpty) _airport = c.airports.first;
    } on ApiFailure catch (e) {
      _loadError = e.message;
    } catch (_) {
      _loadError = 'Could not load airports. Check your connection and try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _changed() {
    _quote = null;
    _typeId = null;
    _message = null;
  }

  void _setDirection(String d) {
    if (d == _direction) return;
    setState(() {
      _direction = d;
      _place = d == AirportDirection.drop ? widget.pickup : null;
      _placeAddress = d == AirportDirection.drop ? widget.pickupAddress : '';
      _errors = {};
      _changed();
    });
  }

  Future<void> _choosePlace() async {
    final r = await Navigator.of(context).push<DropRouteResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DropRouteScreen(
          pickup: widget.pickup,
          pickupAddress: widget.pickupAddress,
          recents: widget.recents,
          selectionLabel: _isDrop ? 'Pickup' : 'Destination',
        ),
      ),
    );
    if (r == null || !mounted) return;
    if (r.point == null) {
      setState(() => _message = 'Search for an address to choose it.');
      return;
    }
    setState(() {
      _place = r.point;
      _placeAddress = r.address;
      _changed();
    });
  }

  String _airportAddress() {
    final a = _airport!;
    final t = (_values['terminal'] ?? '').trim();
    return t.isEmpty ? a.label : '${a.label}, $t';
  }

  /// Shows the fares for this trip. The server checks the airport, the service area and the ride types; this only asks.
  Future<void> _seeFares() async {
    final a = _airport;
    if (a == null) return;
    if (_place == null) {
      setState(() => _message = _isDrop ? 'Choose your pickup location.' : 'Choose where you are going.');
      return;
    }
    final missing = _config.missing(_direction, _values);
    if (missing.isNotEmpty) {
      setState(() {
        _errors = {for (final f in missing) f: '${_label(f)} is required.'};
        _message = 'Please complete the highlighted details.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
      _message = null;
    });
    try {
      final from = _isDrop ? _place! : LatLng(a.lat, a.lng);
      final to = _isDrop ? LatLng(a.lat, a.lng) : _place!;
      final q = await RideApi.estimate(
        pickupLat: from.latitude,
        pickupLng: from.longitude,
        pickupAddress: _isDrop ? _placeAddress : _airportAddress(),
        dropLat: to.latitude,
        dropLng: to.longitude,
        dropAddress: _isDrop ? _airportAddress() : _placeAddress,
        airport: {'id': a.id, 'direction': _direction},
      );
      final types = (q['ride_types'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      if (types.isEmpty) {
        _message = 'No ride types are available for airport transfers right now.';
      } else {
        _quote = q;
        _typeId = (types.first['id'] as num).toInt();
        _syncPayment(types.first);
      }
    } on ApiFailure catch (e) {
      _message = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  List<Map<String, dynamic>> get _types => (_quote?['ride_types'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  Map<String, dynamic> get _type => _types.firstWhere((t) => (t['id'] as num).toInt() == _typeId, orElse: () => <String, dynamic>{});

  void _syncPayment(Map<String, dynamic> t) {
    final methods = (t['payment_methods'] as List?)?.map((e) => e.toString()).toList() ?? [];
    if (!methods.contains(_payment)) _payment = methods.contains('cash') ? 'cash' : (methods.isEmpty ? 'cash' : methods.first);
  }

  Future<void> _book() async {
    final a = _airport;
    final t = _type;
    if (a == null || t.isEmpty || _busy || _place == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final from = _isDrop ? _place! : LatLng(a.lat, a.lng);
      final to = _isDrop ? LatLng(a.lat, a.lng) : _place!;
      final res = await RideApi.request(
        pickupLat: from.latitude,
        pickupLng: from.longitude,
        pickupAddress: _isDrop ? _placeAddress : _airportAddress(),
        dropLat: to.latitude,
        dropLng: to.longitude,
        dropAddress: _isDrop ? _airportAddress() : _placeAddress,
        serviceId: _typeId!,
        paymentMethod: _payment,
        airport: {'id': a.id, 'direction': _direction},
        flight: _config.payload(_direction, _values),
      );
      final ride = res['data'];
      if (ride is Map && mounted) {
        Navigator.of(context).pop(Map<String, dynamic>.from(ride));
        return;
      }
    } on ApiFailure catch (e) {
      if (e.unconfirmed) {
        // The request may have reached DROP. Never send it twice: look for the ride, and let the home screen take over if it exists.
        try {
          final cur = (await RideApi.current())['data'];
          if (cur is Map && cur.isNotEmpty && mounted) {
            Navigator.of(context).pop(Map<String, dynamic>.from(cur));
            return;
          }
          _message = 'Your request did not go through. You can request again.';
        } on ApiFailure {
          _message = 'We could not confirm your request. Check your current ride before requesting again.';
        }
      } else {
        _message = e.message;
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  // ---------------------------------------------------------------- UI

  static const _labels = {
    'airline': 'Airline',
    'flight_number': 'Flight number',
    'arrival_date': 'Date (YYYY-MM-DD)',
    'arrival_time': 'Time (HH:MM, 24 hour)',
    'terminal': 'Terminal',
    'passenger_count': 'Passengers',
    'luggage_count': 'Luggage',
    'contact_phone': 'Contact number',
    'instructions': 'Special instructions',
  };

  String _label(String f) => _labels[f] ?? f;

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: DropTheme.text))),
          child,
        ]),
      );

  Widget _directionToggle() => Row(children: [
        for (final d in [AirportDirection.drop, AirportDirection.pickup])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: d == AirportDirection.drop ? 8 : 0),
              child: ChoiceChip(
                showCheckmark: false,
                selected: _direction == d,
                label: SizedBox(width: double.infinity, child: Text(AirportDirection.title(d), textAlign: TextAlign.center)),
                onSelected: (_) => _setDirection(d),
              ),
            ),
          ),
      ]);

  Widget _tile({required IconData icon, required String text, String? hint, VoidCallback? onTap}) => Material(
        color: DropTheme.cardAlt,
        borderRadius: BorderRadius.circular(DropRadius.field),
        child: InkWell(
          borderRadius: BorderRadius.circular(DropRadius.field),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Icon(icon, size: 20, color: DropColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(text.isEmpty ? (hint ?? '') : text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: text.isEmpty ? DropTheme.muted : DropTheme.text, fontWeight: FontWeight.w600))),
              if (onTap != null) Icon(Icons.chevron_right, color: DropTheme.muted),
            ]),
          ),
        ),
      );

  Widget _airportPicker() {
    final airports = _config.airports;
    if (airports.length <= 1) return _tile(icon: Icons.flight, text: _airport?.label ?? '');
    return DropdownButtonFormField<int>(
      value: _airport?.id,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: [for (final a in airports) DropdownMenuItem(value: a.id, child: Text(a.label, overflow: TextOverflow.ellipsis))],
      onChanged: (id) => setState(() {
        _airport = airports.firstWhere((a) => a.id == id);
        _values.remove('terminal');
        _controllers.remove('terminal')?.dispose();
        _changed();
      }),
    );
  }

  Widget _field(String f) {
    final required = _config.isRequired(_direction, f);
    final label = required ? '${_label(f)} *' : _label(f);
    final error = _errors[f];
    if (f == 'terminal' && (_airport?.terminals.isNotEmpty ?? false)) {
      final current = _airport!.terminals.contains(_values['terminal']) ? _values['terminal'] : null;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: current,
          decoration: InputDecoration(labelText: label, errorText: error, border: const OutlineInputBorder()),
          items: [for (final t in _airport!.terminals) DropdownMenuItem(value: t, child: Text(t))],
          onChanged: (v) => setState(() {
            _values['terminal'] = v ?? '';
            _changed();
          }),
        ),
      );
    }
    final numeric = f == 'passenger_count' || f == 'luggage_count';
    final c = _controllers.putIfAbsent(f, () => TextEditingController(text: _values[f] ?? ''));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: numeric ? TextInputType.number : (f == 'contact_phone' ? TextInputType.phone : TextInputType.text),
        textCapitalization: f == 'flight_number' ? TextCapitalization.characters : TextCapitalization.sentences,
        maxLines: f == 'instructions' ? 2 : 1,
        decoration: InputDecoration(labelText: label, errorText: error, border: const OutlineInputBorder()),
        onChanged: (v) {
          _values[f] = v;
          if (_quote != null) setState(_changed);
        },
      ),
    );
  }

  Widget _fares() {
    final types = _types;
    final currency = _quote?['currency'];
    final t = _type;
    final methods = (t['payment_methods'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final bd = t['fare_breakdown'];
    final surcharge = bd is Map ? (num.tryParse('${bd['airport_surcharge']}') ?? 0).toDouble() : 0.0;
    return _section(
      'Choose a ride',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final x in types)
          RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            value: (x['id'] as num).toInt(),
            groupValue: _typeId,
            onChanged: (v) => setState(() {
              _typeId = v;
              _syncPayment(x);
            }),
            title: Text('${x['name']}', style: TextStyle(color: DropTheme.text, fontWeight: FontWeight.w600)),
            secondary: Text(DropMoney.format(x['fare'], currency), style: TextStyle(color: DropTheme.text, fontWeight: FontWeight.w800)),
          ),
        if (surcharge > 0) Text('Includes an airport charge of ${DropMoney.format(surcharge, currency)}.', style: TextStyle(color: DropTheme.muted)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final m in methods)
            ChoiceChip(
              label: Text(m == 'cash' ? 'Cash' : (m == 'wallet' ? 'Wallet' : (m == 'card' ? 'Card' : m))),
              selected: _payment == m,
              onSelected: (_) => setState(() => _payment = m),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _airport;
    return Scaffold(
      backgroundColor: DropTheme.scaffold,
      appBar: AppBar(title: const Text('Airport transfers')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_loadError!, textAlign: TextAlign.center), const SizedBox(height: 12), TextButton(onPressed: _load, child: const Text('Try again'))])))
                : a == null
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Airport transfers are not available yet.', style: TextStyle(color: DropTheme.muted), textAlign: TextAlign.center)))
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                        _section('Where are you going?', _directionToggle()),
                        _section('Airport', _airportPicker()),
                        _section(
                          _isDrop ? 'Pickup location' : 'Destination',
                          _tile(icon: _isDrop ? Icons.my_location : Icons.location_on, text: _placeAddress, hint: _isDrop ? 'Choose your pickup' : 'Where are you going?', onTap: _choosePlace),
                        ),
                        if (!_isDrop && a.instructions.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 18), child: Text(a.instructions, style: TextStyle(color: DropTheme.muted))),
                        if (_config.shown(_direction).isNotEmpty)
                          _section(
                            _isDrop ? 'Flight details' : 'Arrival details',
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              for (final f in _config.shown(_direction)) _field(f),
                              Text('Your driver sees these details. DROP does not track flights.', style: TextStyle(color: DropTheme.muted, fontSize: 12)),
                            ]),
                          ),
                        if (_quote != null) _fares(),
                        if (_message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_message!, style: const TextStyle(color: Color(0xFFD93025), fontWeight: FontWeight.w600))),
                        if (_quote == null)
                          DropPrimaryButton(label: 'See airport fares', loading: _busy, onPressed: _seeFares)
                        else
                          DropPrimaryButton(label: 'Confirm booking · ${DropMoney.format(_type['fare'], _quote?['currency'])}', loading: _busy, onPressed: _book),
                      ]),
      ),
    );
  }
}
