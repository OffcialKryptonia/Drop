import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The moments in the app that make a sound.
enum ToneEvent { driverIncoming, driverArrived, driverPayment, passengerAccepted, passengerTransfer }

class ToneOption {
  final String id;
  final String label;
  final String asset;
  const ToneOption(this.id, this.label, this.asset);
}

class ToneSlot {
  final ToneEvent event;
  final String title;
  final String help;
  final bool driver;

  /// First option is the default.
  final List<ToneOption> options;
  const ToneSlot(this.event, this.title, this.help, this.driver, this.options);
}

/// Plays the app's tones and remembers which one the person picked for each moment (on this phone).
class ToneService {
  static const _churchBells = ToneOption('church_bells', 'Church bells', 'sounds/church_bells.mp3');
  static const _ladyRequest = ToneOption('ride_request_lady', 'Ride request (Lady)', 'sounds/ride_request_lady.mp3');
  static const _arrived = ToneOption('destination_arrived', 'Destination arrived', 'sounds/destination_arrived.mp3');
  static const _bell = ToneOption('bell_26778', 'Bell', 'sounds/bell_26778.mp3');
  static const _ding = ToneOption('ding_36029', 'Ding', 'sounds/ding_36029.mp3');
  static const _accepted = ToneOption('order_accepted', 'Order accepted', 'sounds/order_accepted.wav');

  static const slots = <ToneSlot>[
    ToneSlot(ToneEvent.driverIncoming, 'Incoming ride', 'Plays when a new ride request reaches you.', true, [_churchBells, _ladyRequest]),
    ToneSlot(ToneEvent.driverArrived, 'Destination arrived', 'Plays when you reach the passenger\'s destination.', true, [_arrived]),
    ToneSlot(ToneEvent.driverPayment, 'Payment received', 'Plays when a trip is paid.', true, [_bell, _ding]),
    ToneSlot(ToneEvent.passengerAccepted, 'Order accepted', 'Plays when a driver accepts your ride.', false, [_accepted, _ding]),
    ToneSlot(ToneEvent.passengerTransfer, 'Fund transfer received', 'Plays when another passenger sends you money.', false, [_ding]),
  ];

  static const off = 'off';

  static final AudioPlayer _player = AudioPlayer();

  static ToneSlot slotOf(ToneEvent e) => slots.firstWhere((s) => s.event == e);

  static String _key(ToneEvent e) => 'tone_${e.name}';

  /// The picked option id, 'off' for silent, or the default when nothing was picked.
  static Future<String> selected(ToneEvent e) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(_key(e)) ?? slotOf(e).options.first.id;
    } catch (_) {
      return slotOf(e).options.first.id;
    }
  }

  static Future<void> select(ToneEvent e, String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key(e), id);
    } catch (_) {}
  }

  /// Plays the person's chosen tone for this moment. Never throws: a missing sound must not break a ride.
  static Future<void> play(ToneEvent e) async {
    try {
      final id = await selected(e);
      if (id == off) return;
      final option = slotOf(e).options.firstWhere((o) => o.id == id, orElse: () => slotOf(e).options.first);
      await preview(option);
    } catch (_) {}
  }

  static Future<void> preview(ToneOption o) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(o.asset));
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}
