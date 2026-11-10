import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../design/drop_design.dart';

/// The animated DROP brand introduction: the logo reveals itself, then [onDone] fires.
///
/// Plays the light or dark clip from assets/videos depending on the theme. If the
/// video cannot start, a static logo is shown and [onDone] still fires, so the user
/// is never stuck on this screen.
class DropIntro extends StatefulWidget {
  const DropIntro({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<DropIntro> createState() => _DropIntroState();
}

class _DropIntroState extends State<DropIntro> {
  VideoPlayerController? _controller;
  Timer? _safetyTimer;
  bool _started = false;
  bool _finished = false;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _start();
  }

  void _start() {
    final bool dark = dropIsDark(context);
    final VideoPlayerController controller = VideoPlayerController.asset(
      dark ? 'assets/videos/drop_intro_dark.mp4' : 'assets/videos/drop_intro_light.mp4',
    );
    _controller = controller;
    // Whatever happens to the video, leave this screen after a few seconds.
    _safetyTimer = Timer(const Duration(seconds: 5), _finish);
    controller.initialize().then((_) async {
      if (!mounted) return;
      await controller.setVolume(0);
      await controller.play();
      controller.addListener(_onTick);
      if (mounted) setState(() {});
    }).catchError((Object error) {
      if (!mounted) return;
      setState(() => _failed = true);
      Future<void>.delayed(const Duration(milliseconds: 900), _finish);
    });
  }

  void _onTick() {
    final VideoPlayerController? c = _controller;
    if (c == null || _finished) return;
    final VideoPlayerValue v = c.value;
    if (v.isInitialized && !v.isPlaying && v.position >= v.duration - const Duration(milliseconds: 120)) {
      // Hold the finished logo for a moment, then move on.
      Future<void>.delayed(const Duration(milliseconds: 350), _finish);
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? c = _controller;
    return ColoredBox(
      color: DropColors.background(context),
      child: Center(
        child: _failed
            ? const DropLogo(width: 260)
            : (c != null && c.value.isInitialized)
                ? AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c))
                : const SizedBox.shrink(),
      ),
    );
  }
}
