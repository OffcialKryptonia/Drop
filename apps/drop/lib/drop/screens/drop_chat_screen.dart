import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../service/DriverApplicationApi.dart' show ApiFailure;
import '../../service/RideApi.dart';
import '../design/drop_design.dart';

/// Quick messages for either side, one tap each.
const dropQuickReplies = <String>[
  "I'm on my way.",
  "I've arrived at the pickup location.",
  'Please wait a moment.',
  "I can't find your location.",
  "I'm nearby.",
  'Please call me.',
  'Thank you.',
];

String _newClientId() {
  final r = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join()}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
}

/// A message that is still on its way (or failed) and not yet confirmed by the server.
class _Local {
  _Local({required this.clientId, this.body, this.voicePath, this.seconds, this.waveform});
  final String clientId;
  final String? body;
  final String? voicePath;
  final int? seconds;
  final List<int>? waveform;
  bool failed = false;
  String? error;
  DateTime at = DateTime.now();
}

/// Chat for one ride, between the passenger and the assigned driver. Updates every few seconds while open.
class DropChatScreen extends StatefulWidget {
  const DropChatScreen({super.key, required this.rideId, this.peerNameHint});
  final int rideId;
  final String? peerNameHint;

  @override
  State<DropChatScreen> createState() => _DropChatScreenState();
}

class _DropChatScreenState extends State<DropChatScreen> with WidgetsBindingObserver {
  final List<Map<String, dynamic>> _messages = [];
  final List<_Local> _locals = [];
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  bool _loading = true;
  bool _hasMore = false;
  bool _loadingMore = false;
  String? _loadError;
  bool _enabled = true;
  bool _voiceEnabled = true;
  bool _canSend = false;
  int _maxVoice = 60;
  String _peerName = '';
  String _rideStatus = '';
  bool _foreground = true;

  // voice recording
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _holdMode = false;
  bool _cancelHint = false;
  int _recSeconds = 0;
  Timer? _recTimer;
  StreamSubscription<Amplitude>? _ampSub;
  final List<int> _amps = [];
  String? _recPath;

  // voice playback: one message at a time
  final AudioPlayer _player = AudioPlayer();
  int? _playingId;
  bool _playLoading = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  final Map<int, (String, DateTime)> _urlCache = {};
  final List<StreamSubscription> _playerSubs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _peerName = widget.peerNameHint ?? '';
    _playerSubs.addAll([
      _player.onPositionChanged.listen((p) => mounted ? setState(() => _pos = p) : null),
      _player.onDurationChanged.listen((d) => mounted ? setState(() => _dur = d) : null),
      _player.onPlayerComplete.listen((_) => mounted ? setState(() {
            _playingId = null;
            _pos = Duration.zero;
          }) : null),
    ]);
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _recTimer?.cancel();
    _ampSub?.cancel();
    for (final s in _playerSubs) {
      s.cancel();
    }
    _player.dispose();
    _recorder.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refresh();
  }

  int get _lastId => _messages.isEmpty ? 0 : (_messages.last['id'] as num).toInt();

  void _applyMeta(Map data) {
    _enabled = data['enabled'] != false;
    _voiceEnabled = data['voice_enabled'] != false;
    _canSend = data['can_send'] == true;
    _maxVoice = (data['max_voice_seconds'] as num?)?.toInt() ?? 60;
    _rideStatus = '${data['ride_status'] ?? ''}';
    final name = (data['peer'] is Map ? (data['peer'] as Map)['name'] : null)?.toString() ?? '';
    if (name.isNotEmpty) _peerName = name;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final r = await RideApi.chat(widget.rideId);
      final data = Map<String, dynamic>.from(r['data'] as Map);
      if (!mounted) return;
      setState(() {
        _applyMeta(data);
        _messages
          ..clear()
          ..addAll(((data['messages'] as List?) ?? const []).map((m) => Map<String, dynamic>.from(m as Map)));
        _hasMore = data['has_more'] == true;
        _loading = false;
      });
      _markRead();
    } on ApiFailure catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _loadError = e.message;
      });
    }
  }

  /// New messages since the last one, plus read ticks on mine.
  Future<void> _refresh() async {
    if (!_foreground || _loading || _loadError != null) return;
    try {
      final r = await RideApi.chat(widget.rideId, after: _lastId);
      final data = Map<String, dynamic>.from(r['data'] as Map);
      final fresh = ((data['messages'] as List?) ?? const []).map((m) => Map<String, dynamic>.from(m as Map)).toList();
      if (!mounted) return;
      setState(() {
        _applyMeta(data);
        final known = _messages.map((m) => m['client_id']).toSet();
        for (final m in fresh) {
          if (!known.contains(m['client_id'])) _messages.add(m);
        }
        _locals.removeWhere((l) => _messages.any((m) => m['client_id'] == l.clientId));
      });
      if (fresh.any((m) => m['mine'] != true)) {
        HapticFeedback.selectionClick();
        _markRead();
      }
      _refreshTicks();
    } catch (_) {}
  }

  /// My messages become 'delivered' and 'read' on the server; fetch their latest state occasionally.
  int _tick = 0;
  Future<void> _refreshTicks() async {
    if (++_tick % 2 != 0) return;
    final pending = _messages.where((m) => m['mine'] == true && m['read_at'] == null).toList();
    if (pending.isEmpty) return;
    try {
      final r = await RideApi.chat(widget.rideId, limit: 50);
      final latest = ((r['data'] as Map)['messages'] as List).map((m) => Map<String, dynamic>.from(m as Map));
      if (!mounted) return;
      setState(() {
        for (final n in latest) {
          final i = _messages.indexWhere((m) => m['id'] == n['id']);
          if (i >= 0) _messages[i] = n;
        }
      });
    } catch (_) {}
  }

  Future<void> _markRead() async {
    try {
      await RideApi.chatRead(widget.rideId);
    } catch (_) {}
  }

  Future<void> _loadOlder() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final first = (_messages.first['id'] as num).toInt();
      final r = await RideApi.chat(widget.rideId, before: first);
      final data = Map<String, dynamic>.from(r['data'] as Map);
      final older = ((data['messages'] as List?) ?? const []).map((m) => Map<String, dynamic>.from(m as Map)).toList();
      if (mounted) setState(() {
        _messages.insertAll(0, older);
        _hasMore = data['has_more'] == true;
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  void _toBottom() {
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  // ---- sending ----

  Future<void> _sendText(String body) async {
    final text = body.trim();
    if (text.isEmpty || !_canSend) return;
    _text.clear();
    final local = _Local(clientId: _newClientId(), body: text);
    setState(() => _locals.add(local));
    _toBottom();
    await _deliver(local);
  }

  Future<void> _deliver(_Local l) async {
    setState(() {
      l.failed = false;
      l.error = null;
    });
    try {
      final r = l.voicePath != null
          ? await RideApi.sendVoice(widget.rideId, clientId: l.clientId, path: l.voicePath!, seconds: l.seconds ?? 1, waveform: l.waveform ?? const [])
          : await RideApi.sendChat(widget.rideId, clientId: l.clientId, body: l.body ?? '');
      final m = Map<String, dynamic>.from(r['data'] as Map);
      if (!mounted) return;
      setState(() {
        if (!_messages.any((x) => x['client_id'] == m['client_id'])) _messages.add(m);
        _locals.remove(l);
      });
      if (l.voicePath != null) File(l.voicePath!).delete().catchError((_) => File(l.voicePath!));
    } on ApiFailure catch (e) {
      if (mounted) setState(() {
        l.failed = true;
        l.error = e.message;
      });
    }
  }

  // ---- recording ----

  Future<bool> _ensureMic() async {
    if (await _recorder.hasPermission()) return true;
    if (!mounted) return false;
    final forever = await Permission.microphone.isPermanentlyDenied;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Allow microphone access to send voice messages.'),
      action: forever ? SnackBarAction(label: 'Settings', onPressed: openAppSettings) : null,
    ));
    return false;
  }

  Future<void> _startRecording({required bool hold}) async {
    if (_recording || !_canSend || !_voiceEnabled) return;
    if (!await _ensureMic()) return;
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 48000, sampleRate: 22050, numChannels: 1), path: path);
      HapticFeedback.mediumImpact();
      _amps.clear();
      _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 150)).listen((a) {
        // dB from about -45 (quiet) to 0 (loud) becomes 5..100.
        _amps.add((((a.current.clamp(-45.0, 0.0) + 45) / 45) * 95 + 5).round());
      });
      _recTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _recSeconds++);
        if (_recSeconds >= _maxVoice) _finishRecording(send: true);
      });
      setState(() {
        _recording = true;
        _holdMode = hold;
        _cancelHint = false;
        _recSeconds = 0;
        _recPath = path;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start recording.')));
    }
  }

  List<int> _bars() {
    if (_amps.isEmpty) return const [];
    const n = 32;
    return List.generate(n, (i) {
      final a = (i * _amps.length / n).floor();
      final b = max(a + 1, ((i + 1) * _amps.length / n).floor());
      final slice = _amps.sublist(a, min(b, _amps.length));
      return (slice.reduce((x, y) => x + y) / slice.length).round();
    });
  }

  Future<void> _finishRecording({required bool send}) async {
    if (!_recording) return;
    _recTimer?.cancel();
    await _ampSub?.cancel();
    final seconds = _recSeconds;
    final bars = _bars();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    setState(() {
      _recording = false;
      _holdMode = false;
      _cancelHint = false;
    });
    path ??= _recPath;
    if (path == null) return;
    if (!send) {
      File(path).delete().catchError((_) => File(path!));
      return;
    }
    if (seconds < 1) {
      File(path).delete().catchError((_) => File(path!));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hold the button and speak, then let go.')));
      return;
    }
    final local = _Local(clientId: _newClientId(), voicePath: path, seconds: seconds, waveform: bars);
    setState(() => _locals.add(local));
    _toBottom();
    await _deliver(local);
  }

  // ---- playback ----

  Future<void> _togglePlay(Map<String, dynamic> m) async {
    final id = (m['id'] as num).toInt();
    try {
      if (_playingId == id) {
        if (_player.state == PlayerState.playing) {
          await _player.pause();
        } else {
          await _player.resume();
        }
        setState(() {});
        return;
      }
      await _player.stop();
      setState(() {
        _playingId = id;
        _playLoading = true;
        _pos = Duration.zero;
      });
      var cached = _urlCache[id];
      if (cached == null || cached.$2.isBefore(DateTime.now())) {
        cached = (await RideApi.chatAudioUrl(widget.rideId, id), DateTime.now().add(const Duration(minutes: 8)));
        _urlCache[id] = cached;
      }
      await _player.play(UrlSource(cached.$1));
      if (mounted) setState(() => _playLoading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _playingId = null;
          _playLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not play this voice message.')));
      }
    }
  }

  // ---- building ----

  String _statusText() {
    switch (_rideStatus) {
      case 'accepted':
        return 'On the way to pickup';
      case 'arrived':
        return 'At the pickup point';
      case 'in_progress':
        return 'Trip in progress';
      case 'completed':
        return 'Trip completed';
      case 'cancelled':
        return 'Trip cancelled';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = dropIsDark(context) ? const Color(0xFF0E0C0B) : const Color(0xFFF6F1ED);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: DropColors.background(context),
        foregroundColor: DropColors.text(context),
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(radius: 19, backgroundColor: DropColors.primary.withValues(alpha: 0.15), child: Text(_initials(_peerName), style: TextStyle(color: DropColors.primary, fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_peerName.isEmpty ? 'Chat' : _peerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (_statusText().isNotEmpty) Text(_statusText(), style: TextStyle(fontSize: 12, color: DropColors.mutedText(context))),
            ]),
          ),
        ]),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(child: _body()),
          _composer(),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: DropColors.mutedText(context))),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ]),
        ),
      );
    }
    if (!_enabled) return Center(child: Text('Chat is switched off right now.', style: TextStyle(color: DropColors.mutedText(context))));
    final items = <Widget>[];
    // Newest first, because the list is reversed (the latest message sits at the bottom).
    final all = <Object>[..._messages, ..._locals];
    DateTime? lastDay;
    final built = <Widget>[];
    for (final o in all) {
      final at = o is _Local ? o.at : (DateTime.tryParse('${(o as Map)['created_at']}') ?? DateTime.now()).toLocal();
      final day = DateTime(at.year, at.month, at.day);
      if (lastDay == null || day != lastDay) {
        built.add(_dateChip(day));
        lastDay = day;
      }
      built.add(o is _Local ? _localBubble(o) : _bubble(Map<String, dynamic>.from(o as Map), at));
    }
    items.addAll(built.reversed);
    if (all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chat_bubble_outline, size: 44, color: DropColors.mutedText(context)),
            const SizedBox(height: 12),
            Text(_canSend ? 'No messages yet.\nSay hello or use a quick message below.' : 'No messages in this chat.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.4, color: DropColors.mutedText(context))),
          ]),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 80) _loadOlder();
        return false;
      },
      child: ListView(controller: _scroll, reverse: true, padding: const EdgeInsets.fromLTRB(12, 8, 12, 8), children: [
        ...items,
        if (_loadingMore) const Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
      ]),
    );
  }

  Widget _dateChip(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today ? 'Today' : (day == today.subtract(const Duration(days: 1)) ? 'Yesterday' : '${day.day}/${day.month}/${day.year}');
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: DropColors.hairline(context), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DropColors.mutedText(context))),
      ),
    );
  }

  String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _frame({required bool mine, required Widget child, required String time, Widget? tick, VoidCallback? onTap}) {
    final bubble = mine ? DropColors.primary : DropColors.surface(context);
    final fg = mine ? Colors.white : DropColors.text(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
          decoration: BoxDecoration(
            color: bubble,
            borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 4), bottomRight: Radius.circular(mine ? 4 : 18)),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg, fontSize: 15.5, height: 1.3),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              child,
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(time, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7))),
                if (tick != null) ...[const SizedBox(width: 4), tick],
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tickFor(Map<String, dynamic> m) {
    if (m['read_at'] != null) return const Icon(Icons.done_all, size: 15, color: Color(0xFF8FD3FF));
    if (m['delivered_at'] != null) return Icon(Icons.done_all, size: 15, color: Colors.white.withValues(alpha: 0.75));
    return Icon(Icons.done, size: 15, color: Colors.white.withValues(alpha: 0.75));
  }

  Widget _bubble(Map<String, dynamic> m, DateTime at) {
    final mine = m['mine'] == true;
    final tick = mine ? _tickFor(m) : null;
    if (m['kind'] == 'voice') {
      final id = (m['id'] as num).toInt();
      final playing = _playingId == id;
      final total = Duration(seconds: (m['seconds'] as num?)?.toInt() ?? 1);
      final dur = playing && _dur > Duration.zero ? _dur : total;
      final progress = playing && dur.inMilliseconds > 0 ? (_pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
      final bars = ((m['waveform'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
      return _frame(
        mine: mine,
        time: _hm(at),
        tick: tick,
        child: _VoiceRow(
          mine: mine,
          playing: playing && _player.state == PlayerState.playing,
          loading: playing && _playLoading,
          progress: progress,
          bars: bars.isEmpty ? List.generate(28, (i) => 25 + (i * 37 % 60)) : bars,
          label: _mmss(playing ? _pos : dur),
          onTap: () => _togglePlay(m),
        ),
      );
    }
    return _frame(mine: mine, time: _hm(at), tick: tick, child: Text('${m['body']}'));
  }

  String _mmss(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _localBubble(_Local l) {
    final child = l.voicePath != null
        ? Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.mic, size: 18, color: Colors.white), const SizedBox(width: 6), Text('Voice message · ${_mmss(Duration(seconds: l.seconds ?? 0))}')])
        : Text(l.body ?? '');
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _frame(
        mine: true,
        time: _hm(l.at),
        tick: l.failed ? const Icon(Icons.error_outline, size: 15, color: Color(0xFFFFD0CC)) : Icon(Icons.schedule, size: 14, color: Colors.white.withValues(alpha: 0.75)),
        child: child,
      ),
      if (l.failed)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(l.error ?? 'Not sent.', style: const TextStyle(fontSize: 12, color: Color(0xFFD93025)))),
            TextButton(onPressed: () => _deliver(l), child: const Text('Retry')),
            TextButton(onPressed: () => setState(() => _locals.remove(l)), child: const Text('Delete')),
          ]),
        ),
    ]);
  }

  Widget _composer() {
    if (_loading || _loadError != null || !_enabled) return const SizedBox.shrink();
    if (!_canSend) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        color: DropColors.background(context),
        child: Text('This chat is closed. Messages can be sent only while the trip is open.', textAlign: TextAlign.center, style: TextStyle(color: DropColors.mutedText(context))),
      );
    }
    return Container(
      color: DropColors.background(context),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!_recording && _text.text.isEmpty)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dropQuickReplies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(dropQuickReplies[i], style: const TextStyle(fontSize: 13)),
                onPressed: () => _sendText(dropQuickReplies[i]),
              ),
            ),
          ),
        const SizedBox(height: 6),
        _recording ? _recordingBar() : _inputRow(),
      ]),
    );
  }

  Widget _inputRow() {
    final hasText = _text.text.trim().isNotEmpty;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: TextField(
          controller: _text,
          minLines: 1,
          maxLines: 5,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Message',
            filled: true,
            fillColor: DropColors.surface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          ),
        ),
      ),
      const SizedBox(width: 8),
      if (hasText)
        _roundButton(Icons.send, () => _sendText(_text.text), 'Send message')
      else if (_voiceEnabled)
        GestureDetector(
          onLongPressStart: (_) => _startRecording(hold: true),
          onLongPressMoveUpdate: (d) {
            final hint = d.offsetFromOrigin.dx < -70;
            if (hint != _cancelHint) setState(() => _cancelHint = hint);
          },
          onLongPressEnd: (d) => _finishRecording(send: d.offsetFromOrigin.dx > -70),
          child: _roundButton(Icons.mic, () => _startRecording(hold: false), 'Record voice message. Hold to record, or tap to start.'),
        ),
    ]);
  }

  Widget _roundButton(IconData icon, VoidCallback onTap, String label) => Semantics(
        button: true,
        label: label,
        child: Material(
          color: DropColors.primary,
          shape: const CircleBorder(),
          child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 48, height: 48, child: Icon(icon, color: Colors.white))),
        ),
      );

  Widget _recordingBar() {
    return Row(children: [
      IconButton(onPressed: () => _finishRecording(send: false), icon: const Icon(Icons.delete_outline, color: Color(0xFFD93025)), tooltip: 'Discard recording'),
      const _Pulse(),
      const SizedBox(width: 8),
      Text(_mmss(Duration(seconds: _recSeconds)), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const Spacer(),
      Text(_holdMode ? (_cancelHint ? 'Release to cancel' : '‹ Slide left to cancel') : 'Recording…', style: TextStyle(fontSize: 13, color: _cancelHint ? const Color(0xFFD93025) : DropColors.mutedText(context))),
      const SizedBox(width: 8),
      if (!_holdMode) _roundButton(Icons.send, () => _finishRecording(send: true), 'Send voice message'),
    ]);
  }
}

/// Play/pause, a waveform that fills as it plays, and the time.
class _VoiceRow extends StatelessWidget {
  const _VoiceRow({required this.mine, required this.playing, required this.loading, required this.progress, required this.bars, required this.label, required this.onTap});
  final bool mine;
  final bool playing;
  final bool loading;
  final double progress;
  final List<int> bars;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : DropColors.text(context);
    final dim = fg.withValues(alpha: 0.4);
    return SizedBox(
      width: 220,
      child: Row(children: [
        Semantics(
          button: true,
          label: playing ? 'Pause voice message' : 'Play voice message',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: loading ? Padding(padding: const EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: fg)) : Icon(playing ? Icons.pause : Icons.play_arrow, color: fg, size: 30),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: 32,
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              for (var i = 0; i < bars.length; i++)
                Expanded(
                  child: Center(
                    child: Container(
                      width: 3,
                      height: 4 + bars[i] * 0.24,
                      decoration: BoxDecoration(color: i / bars.length <= progress && progress > 0 ? fg : dim, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.8))),
      ]),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse();
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween(begin: 0.3, end: 1.0).animate(_c), child: const Icon(Icons.fiber_manual_record, color: Color(0xFFD93025), size: 16));
}
