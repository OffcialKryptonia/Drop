/// Airport transfer models and checks the app can make before asking the server. The server is the authority:
/// it re-validates the airport, the service area, the flight fields and the price on every request.
class FlightFieldRule {
  final bool enabled;
  final bool required;
  const FlightFieldRule({required this.enabled, required this.required});
}

class AirportInfo {
  final int id;
  final String name;
  final String code;
  final double lat;
  final double lng;
  final List<String> terminals;
  final String instructions;
  const AirportInfo({required this.id, required this.name, required this.code, required this.lat, required this.lng, required this.terminals, required this.instructions});

  String get label => code.isEmpty ? name : '$name ($code)';

  static AirportInfo? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = j['id'];
    final lat = j['latitude'];
    final lng = j['longitude'];
    if (id is! num || lat is! num || lng is! num) return null;
    final terms = <String>[];
    final raw = j['terminals'];
    if (raw is List) {
      for (final t in raw) {
        final n = t is Map ? t['name']?.toString().trim() : null;
        if (n != null && n.isNotEmpty) terms.add(n);
      }
    }
    return AirportInfo(
      id: id.toInt(),
      name: (j['name'] ?? '').toString(),
      code: (j['iata_code'] ?? '').toString(),
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      terminals: terms,
      instructions: (j['pickup_instructions'] ?? '').toString(),
    );
  }
}

/// The two airport directions the server accepts.
class AirportDirection {
  AirportDirection._();
  static const drop = 'drop'; // zone to airport
  static const pickup = 'pickup'; // airport to zone

  static String title(String d) => d == drop ? 'Airport Drop' : 'Airport Pickup';
}

class AirportConfig {
  final List<AirportInfo> airports;

  /// direction -> field -> rule, exactly as set by the admin.
  final Map<String, Map<String, FlightFieldRule>> fields;
  const AirportConfig({required this.airports, required this.fields});

  static const fieldOrder = ['airline', 'flight_number', 'arrival_date', 'arrival_time', 'terminal', 'passenger_count', 'luggage_count', 'contact_phone', 'instructions'];

  static AirportConfig fromApi(Map<String, dynamic> body) {
    final airports = <AirportInfo>[];
    final data = body['data'];
    if (data is List) {
      for (final a in data) {
        final x = AirportInfo.fromJson(a);
        if (x != null) airports.add(x);
      }
    }
    final fields = <String, Map<String, FlightFieldRule>>{};
    final raw = body['flight_fields'];
    for (final dir in [AirportDirection.drop, AirportDirection.pickup]) {
      final rules = <String, FlightFieldRule>{};
      final d = raw is Map ? raw[dir] : null;
      if (d is Map) {
        d.forEach((k, v) {
          if (v is Map) rules[k.toString()] = FlightFieldRule(enabled: v['enabled'] == true || v['required'] == true, required: v['required'] == true);
        });
      }
      fields[dir] = rules;
    }
    return AirportConfig(airports: airports, fields: fields);
  }

  /// Fields to show for a direction, in a stable order.
  List<String> shown(String direction) => fieldOrder.where((f) => fields[direction]?[f]?.enabled == true).toList();

  bool isRequired(String direction, String field) => fields[direction]?[field]?.required == true;

  /// Required fields the passenger has not filled in yet.
  List<String> missing(String direction, Map<String, String> values) =>
      shown(direction).where((f) => isRequired(direction, f) && (values[f] ?? '').trim().isEmpty).toList();

  /// Only the shown, non-empty fields go to the server.
  Map<String, dynamic> payload(String direction, Map<String, String> values) {
    final out = <String, dynamic>{};
    for (final f in shown(direction)) {
      final v = (values[f] ?? '').trim();
      if (v.isNotEmpty) out[f] = v;
    }
    return out;
  }
}
