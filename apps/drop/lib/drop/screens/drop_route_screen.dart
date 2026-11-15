import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../service/DriverApplicationApi.dart';

/// What the rider chose on the "Enter your route" screen.
class DropRouteResult {
  /// 'drop' (a place was chosen), 'mapDrop' (set the drop-off on the map) or 'mapFrom' (set the pickup on the map).
  final String kind;
  final LatLng? point;
  final String address;

  /// Set when the rider changed the From field.
  final LatLng? pickup;
  final String? pickupAddress;

  const DropRouteResult(this.kind, {this.point, this.address = '', this.pickup, this.pickupAddress});
}

/// Full-screen "Enter your route": From and To, place search, Suggested (recent) and Saved places (Home, Work, others).
class DropRouteScreen extends StatefulWidget {
  final LatLng pickup;
  final String pickupAddress;
  final List<Map<String, dynamic>> recents;

  const DropRouteScreen({Key? key, required this.pickup, required this.pickupAddress, required this.recents}) : super(key: key);

  @override
  State<DropRouteScreen> createState() => _DropRouteScreenState();
}

class _DropRouteScreenState extends State<DropRouteScreen> {
  late final TextEditingController _from = TextEditingController(text: widget.pickupAddress);
  final TextEditingController _to = TextEditingController();
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();
  Timer? _debounce;
  int _searchId = 0;

  late LatLng _pickup = widget.pickup;
  late String _pickupAddress = widget.pickupAddress;
  bool _pickupChanged = false;

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _saved = [];
  bool _searching = false;
  bool _hasQuery = false;
  String _tab = 'suggested';

  /// 'home', 'work' or 'other' while the rider is choosing an address to save.
  String? _adding;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _from.dispose();
    _to.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  List<Map<String, dynamic>> _list(dynamic v) => v is List ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)] : [];

  Future<void> _loadSaved() async {
    try {
      final r = await DriverApplicationApi.getJson('places/saved');
      if (mounted) setState(() => _saved = _list(r['data']));
    } catch (_) {}
  }

  Map<String, dynamic>? _savedKind(String kind) {
    for (final s in _saved) {
      if (s['kind'] == kind) return s;
    }
    return null;
  }

  bool get _editingFrom => _fromFocus.hasFocus;

  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _hasQuery = false;
        if (_tab == 'results') _tab = 'suggested';
      });
      return;
    }
    setState(() {
      _searching = true;
      _hasQuery = true;
      _tab = 'results';
    });
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_searchId;
    try {
      final r = await DriverApplicationApi.getJson('places/search?q=${Uri.encodeQueryComponent(q)}&lat=${_pickup.latitude}&lng=${_pickup.longitude}');
      if (mounted && id == _searchId) setState(() { _results = _list(r['data']); _searching = false; });
    } catch (_) {
      if (mounted && id == _searchId) setState(() { _results = []; _searching = false; });
    }
  }

  String _full(Map<String, dynamic> p) {
    final t = p['title']?.toString() ?? '';
    final s = p['subtitle']?.toString() ?? '';
    return s.isEmpty || s.startsWith(t) ? (s.isEmpty ? t : s) : '$t, $s';
  }

  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  /// A place was tapped in the results, Suggested or Saved.
  Future<void> _choose({required String title, required String address, required double lat, required double lng}) async {
    final adding = _adding;
    if (adding != null) {
      await _save(adding, title, address, lat, lng);
      return;
    }
    if (_editingFrom) {
      setState(() {
        _pickup = LatLng(lat, lng);
        _pickupAddress = title;
        _pickupChanged = true;
        _from.text = title;
        _results = [];
        _hasQuery = false;
        _tab = 'suggested';
      });
      _toFocus.requestFocus();
      return;
    }
    Navigator.pop(context, DropRouteResult('drop', point: LatLng(lat, lng), address: address.isEmpty ? title : address, pickup: _pickupChanged ? _pickup : null, pickupAddress: _pickupChanged ? _pickupAddress : null));
  }

  Future<void> _save(String kind, String title, String address, double lat, double lng) async {
    try {
      final body = {'address': address.isEmpty ? title : address, 'lat': lat, 'lng': lng};
      if (kind == 'other') {
        await DriverApplicationApi.postJson('places/saved', {...body, 'label': title});
      } else {
        await DriverApplicationApi.putJson('places/saved/$kind', body);
      }
      await _loadSaved();
      if (!mounted) return;
      setState(() { _adding = null; _tab = 'saved'; _to.clear(); _results = []; _hasQuery = false; });
      _say('Saved.');
    } on ApiFailure catch (e) {
      _say(e.message);
    } catch (_) {
      _say('Could not save this place. Try again.');
    }
  }

  Future<void> _remove(Map<String, dynamic> s) async {
    try {
      await DriverApplicationApi.deleteJson('places/saved/${s['id']}');
      await _loadSaved();
    } catch (_) {
      _say('Could not remove this place. Try again.');
    }
  }

  void _startAdding(String kind) {
    setState(() { _adding = kind; _to.clear(); _results = []; _hasQuery = false; });
    _toFocus.requestFocus();
  }

  Widget _field({required TextEditingController c, required FocusNode f, required String label, required IconData icon, Widget? trailing, bool autofocus = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: const Color(0xFFF1F0EC), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: c,
            focusNode: f,
            autofocus: autofocus,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            decoration: InputDecoration(labelText: label, border: InputBorder.none, floatingLabelBehavior: FloatingLabelBehavior.always, labelStyle: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
          ),
        ),
        if (trailing != null) trailing,
      ]),
    );
  }

  Widget _tile({required IconData icon, required String title, String subtitle = '', Widget? trailing, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(icon, color: Colors.grey.shade800),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ]),
          ),
          if (trailing != null) trailing,
        ]),
      ),
    );
  }

  Widget _chip(String id, String label) {
    final on = _tab == id;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(() => _tab = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(color: on ? const Color(0xFF1C1C1C) : const Color(0xFFF1F0EC), borderRadius: BorderRadius.circular(24)),
          child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: on ? Colors.white : Colors.black87)),
        ),
      ),
    );
  }

  List<Widget> _resultTiles() {
    if (_searching && _results.isEmpty) return [const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))];
    if (_results.isEmpty) return [Padding(padding: const EdgeInsets.all(24), child: Text('No places found. Try another name or a nearby landmark.', style: TextStyle(color: Colors.grey.shade700)))];
    return [
      for (final p in _results)
        _tile(
          icon: Icons.location_on_outlined,
          title: p['title']?.toString() ?? '',
          subtitle: p['subtitle']?.toString() ?? '',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (p['distance_km'] != null) Text('${p['distance_km']}km', style: TextStyle(color: Colors.grey.shade700)),
            if (_adding == null)
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                tooltip: 'Save this place',
                onPressed: () => _save('other', p['title']?.toString() ?? '', _full(p), _n(p['lat']), _n(p['lng'])),
              ),
          ]),
          onTap: () => _choose(title: p['title']?.toString() ?? '', address: _full(p), lat: _n(p['lat']), lng: _n(p['lng'])),
        ),
    ];
  }

  List<Widget> _suggestedTiles() {
    if (widget.recents.isEmpty) return [Padding(padding: const EdgeInsets.all(24), child: Text('Places you ride to will show here.', style: TextStyle(color: Colors.grey.shade700)))];
    return [
      for (final r in widget.recents)
        () {
          final full = r['address']?.toString() ?? '';
          final i = full.indexOf(',');
          return _tile(
            icon: Icons.access_time,
            title: i > 0 ? full.substring(0, i) : full,
            subtitle: i > 0 ? full.substring(i + 1).trim() : '',
            onTap: () => _choose(title: i > 0 ? full.substring(0, i) : full, address: full, lat: _n(r['lat']), lng: _n(r['lng'])),
          );
        }(),
    ];
  }

  Widget _savedRow(String kind, IconData icon, String name) {
    final s = _savedKind(kind);
    return _tile(
      icon: icon,
      title: s == null ? 'Add $name' : name,
      subtitle: s?['address']?.toString() ?? '',
      trailing: s == null ? const Icon(Icons.chevron_right) : IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Change', onPressed: () => _startAdding(kind)),
      onTap: () => s == null ? _startAdding(kind) : _choose(title: name, address: s['address']?.toString() ?? '', lat: _n(s['lat']), lng: _n(s['lng'])),
    );
  }

  List<Widget> _savedTiles() {
    return [
      _savedRow('home', Icons.home_outlined, 'Home'),
      _savedRow('work', Icons.work_outline, 'Work'),
      for (final s in _saved.where((x) => x['kind'] == 'other'))
        _tile(
          icon: Icons.bookmark_outline,
          title: s['label']?.toString() ?? '',
          subtitle: s['address']?.toString() ?? '',
          trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Remove', onPressed: () => _remove(s)),
          onTap: () => _choose(title: s['label']?.toString() ?? '', address: s['address']?.toString() ?? '', lat: _n(s['lat']), lng: _n(s['lng'])),
        ),
      _tile(icon: Icons.add, title: 'Another place', trailing: const Icon(Icons.chevron_right), onTap: () => _startAdding('other')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[if (_hasQuery) _chip('results', 'Search results'), _chip('suggested', 'Suggested'), _chip('saved', 'Saved')];
    final List<Widget> body;
    if (_adding != null) {
      body = _hasQuery
          ? _resultTiles()
          : [Padding(padding: const EdgeInsets.all(24), child: Text('Type the address you want to save as ${_adding == 'other' ? 'a place' : _adding}.', style: TextStyle(color: Colors.grey.shade700)))];
    } else if (_tab == 'results' && _hasQuery) {
      body = _resultTiles();
    } else if (_tab == 'saved') {
      body = _savedTiles();
    } else {
      body = _suggestedTiles();
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(alignment: Alignment.center, children: [
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Enter your route', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)))),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F0EC)), icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ),
            ]),
            const SizedBox(height: 8),
            _field(
              c: _from,
              f: _fromFocus,
              label: 'From',
              icon: Icons.my_location,
              trailing: IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Set pickup on the map',
                onPressed: () => Navigator.pop(context, DropRouteResult('mapFrom', pickup: _pickupChanged ? _pickup : null, pickupAddress: _pickupChanged ? _pickupAddress : null)),
              ),
            ),
            const SizedBox(height: 10),
            _field(
              c: _to,
              f: _toFocus,
              label: _adding == null ? 'To' : 'Address to save',
              icon: Icons.flag,
              autofocus: true,
              trailing: IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Choose on the map',
                onPressed: () => Navigator.pop(context, DropRouteResult('mapDrop', pickup: _pickupChanged ? _pickup : null, pickupAddress: _pickupChanged ? _pickupAddress : null)),
              ),
            ),
            if (_adding != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Expanded(child: Text('Saving ${_adding == 'other' ? 'another place' : _adding}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  TextButton(onPressed: () => setState(() => _adding = null), child: const Text('Cancel')),
                ]),
              ),
            const SizedBox(height: 14),
            if (_adding == null) Row(children: tabs),
            const SizedBox(height: 4),
            Expanded(child: ListView(padding: EdgeInsets.zero, keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: body)),
          ]),
        ),
      ),
    );
  }
}
