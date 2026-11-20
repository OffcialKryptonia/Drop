import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../service/call/call_controller.dart';
import '../design/drop_design.dart';

String dropCallClock(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}

/// The full-screen call page: outgoing (calling), incoming (answer or decline) and in-call (mute, speaker, timer, end).
/// It follows the controller and closes itself a moment after the call finishes.
class DropCallScreen extends StatefulWidget {
  const DropCallScreen({super.key, this.controller});
  final CallController? controller;

  @override
  State<DropCallScreen> createState() => _DropCallScreenState();
}

class _DropCallScreenState extends State<DropCallScreen> {
  late final CallController _c = widget.controller ?? CallController.instance;
  Timer? _tick;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _c.phase == CallPhase.active) setState(() {});
    });
  }

  void _changed() {
    if (!mounted) return;
    if (_c.phase == CallPhase.idle && !_popped) {
      _popped = true;
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    _c.removeListener(_changed);
    super.dispose();
  }

  String get _status {
    switch (_c.phase) {
      case CallPhase.outgoing:
        return 'Calling…';
      case CallPhase.incoming:
        return 'Incoming call from Drop';
      case CallPhase.connecting:
        return 'Connecting…';
      case CallPhase.active:
        return _c.reconnecting ? 'Reconnecting…' : dropCallClock(_c.elapsed);
      case CallPhase.ended:
        return _c.note ?? 'Call ended';
      case CallPhase.idle:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _c.peerName.isEmpty ? 'Drop' : _c.peerName;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final incoming = _c.phase == CallPhase.incoming;
    final ended = _c.phase == CallPhase.ended;
    return PopScope(
      canPop: false, // leaving the page must not leave a call running unseen
      child: Scaffold(
        backgroundColor: DropColors.ink,
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [DropColors.primary.withValues(alpha: 0.30), DropColors.ink, DropColors.ink]),
          ),
          child: SafeArea(
            child: Column(children: [
              const SizedBox(height: 56),
              Semantics(
                label: 'Calling $name',
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: DropColors.primary.withValues(alpha: 0.22),
                  child: Text(initial, style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Text(_status, style: TextStyle(fontSize: 17, color: ended ? DropColors.amber : Colors.white70, fontFeatures: const [FontFeature.tabularFigures()])),
              const Spacer(),
              if (!incoming && !ended)
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _Round(icon: _c.muted ? Icons.mic_off : Icons.mic, label: _c.muted ? 'Unmute' : 'Mute', on: _c.muted, onTap: _c.phase == CallPhase.active ? _c.toggleMute : null),
                    const SizedBox(width: 36),
                    _Round(icon: _c.speaker ? Icons.volume_up : Icons.volume_down, label: 'Speaker', on: _c.speaker, onTap: _c.phase == CallPhase.active ? _c.toggleSpeaker : null),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: incoming
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _Big(icon: Icons.call_end, label: 'Decline', color: const Color(0xFFE5392B), onTap: _c.decline),
                        const SizedBox(width: 72),
                        _Big(icon: Icons.call, label: 'Answer', color: DropColors.success, onTap: _c.accept),
                      ])
                    : ended
                        ? const SizedBox(height: 72)
                        : _Big(icon: Icons.call_end, label: 'End call', color: const Color(0xFFE5392B), onTap: () {
                            HapticFeedback.mediumImpact();
                            _c.end();
                          }),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 72, height: 72, child: Icon(icon, color: Colors.white, size: 32))),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      );
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Material(
            color: on ? Colors.white : Colors.white.withValues(alpha: onTap == null ? 0.06 : 0.14),
            shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 60, height: 60, child: Icon(icon, color: on ? DropColors.ink : Colors.white.withValues(alpha: onTap == null ? 0.4 : 1), size: 26))),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}
