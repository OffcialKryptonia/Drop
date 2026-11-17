import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../design/drop_design.dart';

/// Shared building blocks for the driver ride screens: request card, trip sheet, receipt and wallet.
/// Everything here is presentation only: no API calls and no business rules.

/// A bottom sheet that sits on the map with a drag handle, rounded top corners and a height cap,
/// so the map stays visible above it and long content scrolls instead of overflowing.
class DropSheet extends StatelessWidget {
  const DropSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.62,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 12),
  });

  final Widget child;
  final double maxHeightFactor;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final dark = dropIsDark(context);
    return Container(
      margin: margin,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * maxHeightFactor),
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? DropColors.nightSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: DropColors.mutedText(context).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
          ),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}

/// A small coloured status label such as "Heading to pickup".
class DropStatusPill extends StatelessWidget {
  const DropStatusPill({super.key, required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13))),
        ],
      ),
    );
  }
}

/// A short fact such as "0.7 km · 2 min" or "Cash".
class DropFactChip extends StatelessWidget {
  const DropFactChip({super.key, required this.text, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DropColors.text(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: DropColors.surface(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: DropColors.hairline(context))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: c), const SizedBox(width: 5)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13))),
        ],
      ),
    );
  }
}

/// Splits "Winnie Plaza, Abacha Road, Katampe" into the place name and the rest of the address.
({String name, String rest}) splitAddress(String address) {
  final a = address.trim();
  if (a.isEmpty) return (name: 'Selected place', rest: '');
  final i = a.indexOf(',');
  if (i <= 0) return (name: a, rest: '');
  return (name: a.substring(0, i).trim(), rest: a.substring(i + 1).trim());
}

/// Pickup and drop-off as one vertical timeline. [activeStop] 0 highlights the pickup, 1 the drop-off.
class DropStopTimeline extends StatelessWidget {
  const DropStopTimeline({super.key, required this.pickup, required this.dropoff, this.activeStop});

  final String pickup;
  final String dropoff;
  final int? activeStop;

  Widget _stop(BuildContext context, String caption, String address, bool active) {
    final s = splitAddress(address);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: active ? DropColors.primary : DropColors.mutedText(context))),
        const SizedBox(height: 2),
        Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DropColors.text(context))),
        if (s.rest.isNotEmpty) Text(s.rest, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: DropColors.mutedText(context))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Icon(Icons.circle, size: 14, color: DropColors.success),
                Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: DropColors.mutedText(context).withValues(alpha: 0.4))),
                Icon(Icons.location_on, size: 20, color: DropColors.primary),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stop(context, 'PICKUP', pickup, activeStop == 0),
                const SizedBox(height: 12),
                _stop(context, 'DROP-OFF', dropoff, activeStop == 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A ring that empties as the time runs out, with the seconds in the middle. It ticks by itself,
/// so the screen around it does not rebuild every second. Turns red for the last five seconds.
class DropCountdownRing extends StatefulWidget {
  const DropCountdownRing({super.key, required this.expiresAt, required this.totalSeconds, this.size = 52});

  final DateTime? expiresAt;
  final int totalSeconds;
  final double size;

  @override
  State<DropCountdownRing> createState() => _DropCountdownRingState();
}

class _DropCountdownRingState extends State<DropCountdownRing> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  int get _left {
    final e = widget.expiresAt;
    if (e == null) return 0;
    final d = e.toUtc().difference(DateTime.now().toUtc()).inSeconds;
    return d < 0 ? 0 : d;
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final total = widget.totalSeconds <= 0 ? 1 : widget.totalSeconds;
    final urgent = left <= 5;
    final color = urgent ? Colors.red : DropColors.primary;
    return Semantics(
      label: '$left seconds left to accept',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(value: (left / total).clamp(0.0, 1.0), strokeWidth: 4, color: color, backgroundColor: color.withValues(alpha: 0.15)),
            ),
            Text('$left', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }
}

/// A round icon button with a 48 dp touch target (call, chat).
class DropRoundAction extends StatelessWidget {
  const DropRoundAction({super.key, required this.icon, required this.label, required this.onPressed, this.color});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DropColors.primary;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: c.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 48, height: 48, child: Icon(icon, color: c)),
        ),
      ),
    );
  }
}

/// A compact button that never wraps its label: it scales the text down instead.
/// [primary] fills with the brand colour; otherwise it is outlined. [danger] makes it red.
class DropActionButton extends StatelessWidget {
  const DropActionButton({super.key, required this.label, required this.onPressed, this.icon, this.primary = false, this.danger = false, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final base = danger ? Colors.red : DropColors.primary;
    final content = loading
        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: primary ? Colors.white : base))
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Text(label, maxLines: 1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(DropRadius.button));
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: primary
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: base,
                foregroundColor: Colors.white,
                disabledBackgroundColor: base.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: shape,
              ),
              onPressed: loading ? null : onPressed,
              child: content,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: danger ? Colors.red : DropColors.text(context),
                side: BorderSide(color: danger ? Colors.red : DropColors.mutedText(context).withValues(alpha: 0.5), width: 1.3),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: shape,
              ),
              onPressed: loading ? null : onPressed,
              child: content,
            ),
    );
  }
}

/// One line of a receipt: a label on the left and an amount on the right.
class DropReceiptRow extends StatelessWidget {
  const DropReceiptRow({super.key, required this.label, required this.amount, this.bold = false, this.amountColor});

  final String label;
  final Widget amount;
  final bool bold;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: bold ? 17 : 15, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? DropColors.text(context) : DropColors.mutedText(context));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          DefaultTextStyle(style: style.copyWith(color: amountColor ?? DropColors.text(context)), child: amount),
        ],
      ),
    );
  }
}
