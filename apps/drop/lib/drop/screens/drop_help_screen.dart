import 'package:flutter/material.dart';

import '../../service/DriverApplicationApi.dart';
import '../../utils/Colors.dart';

/// Help & complaints for riders and drivers: send a complaint, follow DROP's replies.
class DropHelpScreen extends StatefulWidget {
  /// Set when opened from a trip, so the complaint is linked to it.
  final int? rideId;
  const DropHelpScreen({super.key, this.rideId});

  @override
  State<DropHelpScreen> createState() => _DropHelpScreenState();
}

class _DropHelpScreenState extends State<DropHelpScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await DriverApplicationApi.getJson('complaints');
      final l = r['data'];
      items = l is List ? l.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
      error = null;
    } on ApiFailure catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Color _color(String s) => s == 'resolved' ? Colors.green : (s == 'investigating' ? Colors.blue : Colors.orange);

  Future<void> _new() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _NewComplaint(rideId: widget.rideId)));
    if (sent == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & complaints', style: TextStyle(color: Colors.white))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _new, backgroundColor: primaryColor, foregroundColor: Colors.white, icon: const Icon(Icons.edit_outlined), label: const Text('New complaint')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: _load, child: const Text('Try again'))]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No complaints. If something went wrong on a trip, tell us.'))])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final c = items[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text((c['subject'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text((c['created_at'] ?? '').toString().split('T').first),
                              trailing: Text((c['status_text'] ?? '').toString(), style: TextStyle(color: _color('${c['status']}'), fontWeight: FontWeight.w700)),
                              onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ComplaintThread(id: (c['id'] as num).toInt())));
                                _load();
                              },
                            );
                          },
                        ),
                ),
    );
  }
}

class _NewComplaint extends StatefulWidget {
  final int? rideId;
  const _NewComplaint({this.rideId});

  @override
  State<_NewComplaint> createState() => _NewComplaintState();
}

class _NewComplaintState extends State<_NewComplaint> {
  final subject = TextEditingController();
  final description = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    subject.dispose();
    description.dispose();
    super.dispose();
  }

  void _say(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _send() async {
    if (subject.text.trim().isEmpty) return _say('Enter a short subject.');
    if (description.text.trim().isEmpty) return _say('Tell us what happened.');
    if (sending) return;
    setState(() => sending = true);
    try {
      final r = await DriverApplicationApi.postJson('complaints', {'subject': subject.text.trim(), 'description': description.text.trim(), if (widget.rideId != null) 'ride_request_id': widget.rideId});
      if (!mounted) return;
      _say((r['message'] ?? 'Sent.').toString());
      Navigator.of(context).pop(true);
      return;
    } on ApiFailure catch (e) {
      _say(e.message);
    }
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New complaint', style: TextStyle(color: Colors.white))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: subject, maxLength: 150, decoration: InputDecoration(labelText: 'Subject', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 12),
        TextField(controller: description, maxLines: 6, maxLength: 3000, decoration: InputDecoration(labelText: 'What happened?', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        if (widget.rideId != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('This will be linked to your trip #${widget.rideId}.', style: TextStyle(color: Colors.grey.shade700))),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: sending ? null : _send,
            child: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send complaint'),
          ),
        ),
      ]),
    );
  }
}

class _ComplaintThread extends StatefulWidget {
  final int id;
  const _ComplaintThread({required this.id});

  @override
  State<_ComplaintThread> createState() => _ComplaintThreadState();
}

class _ComplaintThreadState extends State<_ComplaintThread> {
  Map<String, dynamic> d = {};
  final reply = TextEditingController();
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await DriverApplicationApi.getJson('complaints/${widget.id}');
      d = r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : {};
      error = null;
    } on ApiFailure catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _send() async {
    final t = reply.text.trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await DriverApplicationApi.postJson('complaints/${widget.id}/comments', {'comment': t});
      reply.clear();
      await _load();
    } on ApiFailure catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final comments = d['comments'] is List ? (d['comments'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
    return Scaffold(
      appBar: AppBar(title: Text('Complaint #${widget.id}', style: const TextStyle(color: Colors.white))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : Column(children: [
                  Expanded(
                    child: ListView(padding: const EdgeInsets.all(16), children: [
                      Text((d['subject'] ?? '').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text((d['status_text'] ?? '').toString(), style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 12),
                      Text((d['description'] ?? '').toString()),
                      const Divider(height: 32),
                      for (final m in comments)
                        Align(
                          alignment: m['added_by'] == 'admin' ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(color: m['added_by'] == 'admin' ? Colors.grey.shade200 : primaryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (m['added_by'] == 'admin') const Text('DROP support', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              Text((m['comment'] ?? '').toString()),
                            ]),
                          ),
                        ),
                      if (comments.isEmpty) Text('No replies yet. We will answer here.', style: TextStyle(color: Colors.grey.shade700)),
                    ]),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: Row(children: [
                        Expanded(child: TextField(controller: reply, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: 'Write a message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
                        const SizedBox(width: 8),
                        IconButton(onPressed: sending ? null : _send, icon: Icon(Icons.send, color: primaryColor)),
                      ]),
                    ),
                  ),
                ]),
    );
  }
}
