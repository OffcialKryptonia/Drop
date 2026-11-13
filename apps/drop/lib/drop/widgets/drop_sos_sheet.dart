import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../service/DriverApplicationApi.dart';

/// SOS for the live trip (rider and driver). One big button tells DROP's team with the person's location and trip;
/// the national emergency number and the person's own emergency contacts are a tap away.
Future<void> showDropSos(BuildContext context, {int? rideId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _SosSheet(rideId: rideId),
  );
}

class _SosSheet extends StatefulWidget {
  final int? rideId;
  const _SosSheet({this.rideId});

  @override
  State<_SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<_SosSheet> {
  bool sending = false;
  bool sent = false;
  String? error;
  List<Map<String, dynamic>> contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final r = await DriverApplicationApi.getJson('sos-list');
      final l = r['data'];
      if (l is List && mounted) setState(() => contacts = l.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {}
  }

  Future<void> _alert() async {
    if (sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    double? lat, lng;
    try {
      // Whatever the phone already knows is used at once; a fresh fix is only waited for briefly.
      Position? p = await Geolocator.getLastKnownPosition();
      p ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 6));
      lat = p.latitude;
      lng = p.longitude;
    } catch (_) {}
    try {
      await DriverApplicationApi.postJson('sos/alert', {'ride_request_id': widget.rideId, 'latitude': lat, 'longitude': lng});
      sent = true;
    } on ApiFailure catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> _call(String number) async {
    try {
      await launchUrl(Uri.parse('tel:$number'));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Emergency', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 6),
          Text(sent ? 'DROP has been alerted with your location and trip. Stay on the line if we call you.' : 'In danger? Tell DROP now. We receive your location and trip details straight away.', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: sent ? Colors.green : Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: sending || sent ? null : _alert,
              icon: sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(sent ? Icons.check_circle : Icons.sos),
              label: Text(sent ? 'DROP alerted' : 'Alert DROP now', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => _call('112'),
              icon: const Icon(Icons.call),
              label: const Text('Call emergency services (112)'),
            ),
          ),
          if (contacts.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Your emergency contacts', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final c in contacts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text((c['title'] ?? '').toString()),
                subtitle: Text((c['contact_number'] ?? '').toString()),
                trailing: IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => _call((c['contact_number'] ?? '').toString())),
              ),
          ],
        ]),
      ),
    );
  }
}
