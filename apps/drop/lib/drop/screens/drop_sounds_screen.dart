import 'package:flutter/material.dart';

import '../../service/ToneService.dart';

/// Tone settings: pick the sound for each moment, in Driver mode and in Passenger mode.
class DropSoundsScreen extends StatefulWidget {
  const DropSoundsScreen({Key? key}) : super(key: key);

  @override
  State<DropSoundsScreen> createState() => _DropSoundsScreenState();
}

class _DropSoundsScreenState extends State<DropSoundsScreen> {
  final Map<ToneEvent, String> _picked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final s in ToneService.slots) {
      _picked[s.event] = await ToneService.selected(s.event);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ToneService.stop();
    super.dispose();
  }

  Widget _section(String title, bool driver) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 4), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
      for (final s in ToneService.slots.where((x) => x.driver == driver)) _slot(s),
    ]);
  }

  Widget _slot(ToneSlot s) {
    final current = _picked[s.event] ?? s.options.first.id;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(s.help, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ]),
          ),
          for (final o in s.options)
            RadioListTile<String>(
              dense: true,
              value: o.id,
              groupValue: current,
              title: Text(o.id == s.options.first.id ? '${o.label} (default)' : o.label),
              secondary: IconButton(icon: const Icon(Icons.play_circle_outline), tooltip: 'Play', onPressed: () => ToneService.preview(o)),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _picked[s.event] = v);
                ToneService.select(s.event, v);
                ToneService.preview(o);
              },
            ),
          RadioListTile<String>(
            dense: true,
            value: ToneService.off,
            groupValue: current,
            title: const Text('No sound'),
            onChanged: (v) {
              if (v == null) return;
              ToneService.stop();
              setState(() => _picked[s.event] = v);
              ToneService.select(s.event, v);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tone settings')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        _section('Driver mode', true),
        _section('Passenger mode', false),
      ]),
    );
  }
}
