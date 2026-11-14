import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../components/VehicleIcons.dart';

/// The horizontal row of ride types on the passenger home sheet: a vehicle picture, the name and the seats.
/// Types with no driver nearby are shown faded but can still be chosen.
class DropRideTypeStrip extends StatelessWidget {
  final List<Map<String, dynamic>> types;
  final int? selected;
  final ValueChanged<Map<String, dynamic>> onTap;

  const DropRideTypeStrip({Key? key, required this.types, required this.selected, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final t = types[i];
          final id = (t['id'] as num).toInt();
          final on = id == selected;
          final free = ((t['drivers_nearby'] as num?)?.toInt() ?? 1) > 0;
          return GestureDetector(
            onTap: () => onTap(t),
            child: Opacity(
              opacity: free ? 1 : 0.45,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: on ? const Color(0xFFD6EEFB) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _TypeIcon(iconUrl: t['icon_url']?.toString() ?? '', mapIcon: t['map_icon']?.toString() ?? 'car'),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${t['name']}', style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 6),
                    Icon(Icons.person, size: 14, color: Colors.grey.shade700),
                    Text('${t['capacity'] ?? ''}', style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The admin's ride-type picture when there is one, otherwise the vehicle's map icon turned to face right.
class _TypeIcon extends StatefulWidget {
  final String iconUrl;
  final String mapIcon;

  const _TypeIcon({required this.iconUrl, required this.mapIcon});

  @override
  State<_TypeIcon> createState() => _TypeIconState();
}

class _TypeIconState extends State<_TypeIcon> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    VehicleIcons.load(widget.mapIcon).then((b) {
      if (mounted && b != null) setState(() => _bytes = b);
    });
  }

  Widget _fallback() => SizedBox(
        width: 64,
        height: 40,
        child: _bytes == null ? null : Transform.rotate(angle: math.pi / 2, child: Image.memory(_bytes!, fit: BoxFit.contain)),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.iconUrl.startsWith('http')) {
      return SizedBox(width: 64, height: 40, child: Image.network(widget.iconUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _fallback()));
    }
    return _fallback();
  }
}
