import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../service/RideApi.dart';
import '../../service/net/drop_cache.dart';
import '../design/drop_design.dart';
import '../widgets/drop_money.dart';
import '../widgets/drop_ride_ui.dart';
import 'drop_receipt_screen.dart';

/// "My trips": the person's finished trips, newest first. Tap a completed trip for its receipt.
/// Passengers see what they paid; drivers see what they earned.
class DropTripsScreen extends StatefulWidget {
  const DropTripsScreen({super.key, required this.driver});

  final bool driver;

  @override
  State<DropTripsScreen> createState() => _DropTripsScreenState();
}

class _DropTripsScreenState extends State<DropTripsScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  String? _error;
  DateTime? _savedAt; // set while the list on screen is a saved copy, not fresh from the server

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _parse(dynamic data) => ((data as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  /// Saved trips show at once (also with no internet); the fresh list replaces them when it arrives.
  Future<void> _load() async {
    final key = await DropCache.scoped(widget.driver ? 'history:driver' : 'history:rider');
    if (_trips.isEmpty) {
      final saved = await DropCache.read(key, maxAge: const Duration(days: 30));
      if (saved != null && mounted) {
        setState(() {
          _trips = _parse(saved.data);
          _savedAt = saved.savedAt;
          _loading = false;
        });
      }
    }
    if (mounted && _trips.isEmpty) setState(() => _loading = true);
    _error = null;
    try {
      final res = widget.driver ? await RideApi.driverHistory() : await RideApi.history();
      _trips = _parse(res['data']);
      _savedAt = null;
      DropCache.put(key, res['data']);
    } catch (e) {
      if (_trips.isEmpty) _error = 'Could not load your trips. Check your connection and try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  String _when(Map<String, dynamic> t) {
    final dt = DateTime.tryParse((t['completed_at'] ?? t['created_at'] ?? '').toString())?.toLocal();
    return dt == null ? '' : DateFormat('d MMM, h:mm a').format(dt);
  }

  String _pickup(Map<String, dynamic> t) => widget.driver ? (t['pickup_address'] ?? '').toString() : (((t['pickup'] as Map?)?['address']) ?? '').toString();
  String _dropoff(Map<String, dynamic> t) => widget.driver ? (t['dropoff_address'] ?? '').toString() : (((t['dropoff'] as Map?)?['address']) ?? '').toString();

  Widget _row(Map<String, dynamic> t) {
    final status = (t['status'] ?? 'completed').toString();
    final done = status == 'completed';
    final amount = widget.driver ? t['earning'] : t['fare'];
    final sym = widget.driver ? DropMoney.naira : (((t['currency'] as Map?)?['symbol']) ?? DropMoney.naira).toString();
    final p = splitAddress(_pickup(t)), d = splitAddress(_dropoff(t));
    final stops = (t['stops'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      ..sort((a, b) => ((a['sequence'] as num?)?.toInt() ?? 0).compareTo((b['sequence'] as num?)?.toInt() ?? 0));
    return Semantics(
      button: done,
      child: Material(
        color: DropColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: done ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => DropReceiptScreen(rideId: (t['id'] as num).toInt(), driver: widget.driver))) : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: DropColors.hairline(context))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_when(t), style: TextStyle(fontSize: 12, color: DropColors.mutedText(context))),
                  const SizedBox(height: 6),
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DropColors.text(context))),
                  for (final stop in stops)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(children: [
                        Icon(Icons.more_horiz, size: 14, color: DropColors.primary),
                        const SizedBox(width: 4),
                        Expanded(child: Text('Stop ${stop['sequence'] ?? ''}: ${stop['address'] ?? 'Additional stop'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: DropColors.mutedText(context)))),
                      ]),
                    ),
                  Row(children: [
                    Icon(Icons.arrow_downward, size: 14, color: DropColors.mutedText(context)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: DropColors.mutedText(context)))),
                  ]),
                ]),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (done)
                  DropMoneyText(amount, symbol: sym, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: widget.driver ? DropColors.success : DropColors.text(context)))
                else
                  DropStatusPill(text: status == 'cancelled' ? 'Cancelled' : 'No driver found', color: Colors.red),
                if (done) Text('Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DropColors.primary)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: DropColors.mutedText(context))),
            const SizedBox(height: 16),
            SizedBox(width: 200, child: DropActionButton(label: 'Try again', onPressed: _load)),
          ]),
        ),
      );
    } else if (_trips.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(widget.driver ? 'No trips yet. Your completed trips and earnings will show here.' : 'No trips yet. Your completed trips and receipts will show here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: DropColors.mutedText(context))),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _trips.length + (_savedAt == null ? 0 : 1),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            if (_savedAt != null) {
              if (i == 0) {
                return Text('Saved ${DropCache.ago(_savedAt!)}. Pull down to refresh when you are online.', key: const Key('saved_note'), style: TextStyle(fontSize: 12.5, color: DropColors.mutedText(context)));
              }
              return _row(_trips[i - 1]);
            }
            return _row(_trips[i]);
          },
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('My trips')), body: body);
  }
}
