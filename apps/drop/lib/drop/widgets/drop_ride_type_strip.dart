
import 'package:flutter/material.dart';
import '../../drop/design/drop_theme.dart';


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
          final free = ((t['drivers_nearby'] as num?)?.toInt() ?? 1) > 0 || ((t['drivers_in_region'] as num?)?.toInt() ?? 0) > 0;
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
                    Icon(Icons.person, size: 14, color: DropTheme.muted),
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

/// The admin's ride-type picture when there is one, otherwise a built-in side-view picture for the vehicle kind.
/// This is separate from the top-down icon drawn on the map.
class _TypeIcon extends StatelessWidget {
  final String iconUrl;
  final String mapIcon;

  const _TypeIcon({required this.iconUrl, required this.mapIcon});

  static const _kinds = {'car', 'bike', 'keke', 'van', 'car_dispatch', 'bike_dispatch'};

  Widget _builtIn() => Image.asset('assets/vehicle_icons/side_${_kinds.contains(mapIcon) ? mapIcon : 'car'}.png', fit: BoxFit.contain);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 40,
      child: iconUrl.startsWith('http') ? Image.network(iconUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _builtIn()) : _builtIn(),
    );
  }
}
