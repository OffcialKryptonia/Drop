import 'package:flutter/material.dart';

import '../../service/call/call_controller.dart';
import '../screens/drop_call_screen.dart';
import '../design/drop_design.dart';

bool _screenOpen = false;

/// The "Call" button on an open trip. It shows only when the server says calling is available for this ride, and
/// while it is on screen it also listens for an incoming call and opens the call page when one rings.
/// It never shows or dials a phone number.
class DropCallButton extends StatefulWidget {
  const DropCallButton({super.key, required this.rideId, required this.peerName, this.compact = false, this.controller});
  final int rideId;
  final String peerName;

  /// A round icon only (for a row next to the person's name); otherwise a full-width outlined button.
  final bool compact;
  final CallController? controller;

  @override
  State<DropCallButton> createState() => _DropCallButtonState();
}

class _DropCallButtonState extends State<DropCallButton> {
  late final CallController _c = widget.controller ?? CallController.instance;
  bool _can = false;

  @override
  void initState() {
    super.initState();
    _c.presenter = _show;
    _c.watch();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant DropCallButton old) {
    super.didUpdateWidget(old);
    if (old.rideId != widget.rideId) _refresh();
  }

  Future<void> _refresh() async {
    final ok = await _c.available(widget.rideId);
    if (mounted && ok != _can) setState(() => _can = ok);
  }

  void _show() {
    if (!mounted || _screenOpen) return;
    _screenOpen = true;
    Navigator.of(context, rootNavigator: true)
        .push(PageRouteBuilder<void>(
          opaque: true,
          fullscreenDialog: true,
          pageBuilder: (_, __, ___) => DropCallScreen(controller: _c),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ))
        .whenComplete(() => _screenOpen = false);
  }

  @override
  void dispose() {
    _c.unwatch();
    if (_c.presenter == _show) _c.presenter = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_can) return const SizedBox.shrink();
    void go() => _c.start(widget.rideId, widget.peerName);
    if (widget.compact) {
      return Semantics(
        button: true,
        label: 'Call ${widget.peerName}',
        child: IconButton(onPressed: go, icon: Icon(Icons.call, color: DropColors.primary), tooltip: 'Call in the app'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: OutlinedButton.icon(
        onPressed: go,
        icon: const Icon(Icons.call, size: 18),
        label: Text('Call ${widget.peerName.isEmpty ? 'in the app' : widget.peerName}'),
        style: OutlinedButton.styleFrom(foregroundColor: DropColors.primary, side: BorderSide(color: DropColors.primary), minimumSize: const Size.fromHeight(44)),
      ),
    );
  }
}
