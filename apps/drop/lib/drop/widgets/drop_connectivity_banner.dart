import 'dart:async';

import 'package:flutter/material.dart';

import '../../service/net/connectivity_service.dart';
import '../design/drop_design.dart';

/// What the strip says for each state. Kept apart from the widget so the wording is easy to test.
String? dropConnectivityMessage(NetStatus s) {
  switch (s) {
    case NetStatus.online:
      return null;
    case NetStatus.offline:
      return 'No internet connection. You are viewing saved information.';
    case NetStatus.degraded:
      return 'Weak connection. Things may be slow.';
    case NetStatus.reconnecting:
      return 'Reconnecting…';
    case NetStatus.serverDown:
      return 'DROP is not responding. Trying again. You are viewing saved information.';
  }
}

/// A slim strip above the app: it pushes the screen down a little instead of covering anything,
/// never blocks a tap, and says "You're back online." for a moment when the connection returns.
/// This replaces the old full-screen "no internet" page, so the app always opens and stays usable.
class DropConnectivityHost extends StatefulWidget {
  const DropConnectivityHost({super.key, required this.child, this.service});

  final Widget child;
  final ConnectivityService? service;

  @override
  State<DropConnectivityHost> createState() => _DropConnectivityHostState();
}

class _DropConnectivityHostState extends State<DropConnectivityHost> with WidgetsBindingObserver {
  late final ConnectivityService svc = widget.service ?? ConnectivityService.instance;
  bool _backOnline = false;
  Timer? _hide;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _seen = svc.recoveries.value;
    svc.recoveries.addListener(_recovered);
    svc.status.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _recovered() {
    if (svc.recoveries.value == _seen) return;
    _seen = svc.recoveries.value;
    _hide?.cancel();
    setState(() => _backOnline = true);
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _backOnline = false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) svc.onResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    svc.recoveries.removeListener(_recovered);
    svc.status.removeListener(_changed);
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = dropConnectivityMessage(svc.status.value);
    final text = msg ?? (_backOnline ? 'You are back online.' : null);
    final good = msg == null && _backOnline;
    final topInset = MediaQuery.of(context).padding.top;
    return Column(children: [
      AnimatedSize(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.topCenter,
        child: text == null
            ? const SizedBox(width: double.infinity)
            : Semantics(
                liveRegion: true,
                child: Container(
                  key: const Key('connectivity_banner'),
                  width: double.infinity,
                  color: good ? DropColors.success : const Color(0xFF3A3F47),
                  padding: EdgeInsets.fromLTRB(16, topInset + 5, 16, 5),
                  child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                ),
              ),
      ),
      Expanded(
        // While the strip is showing it already covers the status bar, so the screen below must not add that space again.
        child: MediaQuery.removePadding(context: context, removeTop: text != null, child: widget.child),
      ),
    ]);
  }
}
