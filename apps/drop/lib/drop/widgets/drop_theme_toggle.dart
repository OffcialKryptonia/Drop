import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../design/drop_theme.dart';

/// Animated sun / moon switch. Tapping flips Light and Dark; the sun's rays fold away while a crescent
/// slides across it and the sky darkens, driven by a spring so it settles with a small bounce.
/// Honours "remove animations" (jumps straight to the end state).
class DropThemeToggle extends StatefulWidget {
  const DropThemeToggle({super.key, this.width = 68});

  final double width;

  @override
  State<DropThemeToggle> createState() => _DropThemeToggleState();
}

class _DropThemeToggleState extends State<DropThemeToggle> with SingleTickerProviderStateMixin {
  static const SpringDescription _spring = SpringDescription(mass: 1, stiffness: 190, damping: 13);

  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: DropTheme.isDark ? 1 : 0);
  final Listenable _listen = Listenable.merge([DropTheme.pref, DropTheme.revision]);

  @override
  void initState() {
    super.initState();
    _listen.addListener(_sync);
  }

  @override
  void dispose() {
    _listen.removeListener(_sync);
    _c.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final target = DropTheme.isDark ? 1.0 : 0.0;
    if ((_c.value - target).abs() < 0.001 && !_c.isAnimating) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = target;
    } else {
      _c.animateWith(SpringSimulation(_spring, _c.value, target, _c.velocity));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = DropTheme.isDark;
    final h = widget.width / 2;
    return Semantics(
      button: true,
      toggled: dark,
      label: dark ? 'Dark mode on. Switch to light mode' : 'Light mode on. Switch to dark mode',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          DropTheme.toggle();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => CustomPaint(size: Size(widget.width, h), painter: SunMoonPainter(_c.value)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the track, stars and the sun-to-moon knob for animation value [t] (0 = day, 1 = night; may overshoot).
class SunMoonPainter extends CustomPainter {
  SunMoonPainter(this.t);

  final double t;

  static const Color daySky = Color(0xFF7CC4F5);
  static const Color nightSky = Color(0xFF1B2440);
  static const Color sun = Color(0xFFFFB300);
  static const Color moon = Color(0xFFE9EDF5);

  @override
  void paint(Canvas canvas, Size size) {
    final k = t.clamp(0.0, 1.0);
    final h = size.height;
    final track = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(h / 2));
    canvas.drawRRect(track, Paint()..color = Color.lerp(daySky, nightSky, k)!);

    // Stars fade in on the left as the knob moves right.
    final star = Paint()..color = Colors.white.withValues(alpha: (k * 1.4 - 0.3).clamp(0.0, 1.0));
    canvas.drawCircle(Offset(h * 0.55, h * 0.32), 1.4, star);
    canvas.drawCircle(Offset(h * 0.95, h * 0.62), 1.1, star);
    canvas.drawCircle(Offset(h * 0.75, h * 0.78), 0.9, star);

    final r = h / 2 - 5;
    final cx = h / 2 + (size.width - h) * t;
    final c = Offset(cx, h / 2);

    // Rays: fold in and spin while the sun becomes the moon.
    final rayK = (1 - k * 1.5).clamp(0.0, 1.0);
    if (rayK > 0) {
      final ray = Paint()
        ..color = sun
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + k * math.pi;
        final from = r + 2.2;
        final to = r + 2.2 + 3.2 * rayK;
        canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * from, c + Offset(math.cos(a), math.sin(a)) * to, ray);
      }
    }

    // Body: a full disc that gets a bite taken out of it.
    final body = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final cut = ((k - 0.3) / 0.7).clamp(0.0, 1.0);
    final cutter = Path()..addOval(Rect.fromCircle(center: c + Offset(r * (1.9 - 1.25 * cut), -r * (1.0 - 0.45 * cut)), radius: r * 0.82));
    final shape = cut == 0 ? body : Path.combine(PathOperation.difference, body, cutter);
    canvas.drawPath(shape, Paint()..color = Color.lerp(sun, moon, k)!);
  }

  @override
  bool shouldRepaint(SunMoonPainter old) => old.t != t;
}

/// System / Light / Dark choice, shown under the toggle.
class DropThemeSelector extends StatelessWidget {
  const DropThemeSelector({super.key});

  static const _options = <(DropThemePref, String, IconData)>[
    (DropThemePref.system, 'System default', Icons.brightness_auto_rounded),
    (DropThemePref.light, 'Light', Icons.light_mode_rounded),
    (DropThemePref.dark, 'Dark', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DropThemePref>(
      valueListenable: DropTheme.pref,
      builder: (context, current, _) {
        final scheme = Theme.of(context).colorScheme;
        return Row(
          children: [
            for (final o in _options)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Semantics(
                    button: true,
                    selected: current == o.$1,
                    label: '${o.$2} theme',
                    child: InkWell(
                      key: ValueKey('theme-${o.$1.name}'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        DropTheme.setPref(o.$1);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        constraints: const BoxConstraints(minHeight: 64),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        decoration: BoxDecoration(
                          color: current == o.$1 ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: current == o.$1 ? scheme.primary : Theme.of(context).dividerColor, width: current == o.$1 ? 1.6 : 1),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(o.$3, size: 22, color: current == o.$1 ? scheme.primary : Theme.of(context).iconTheme.color),
                            const SizedBox(height: 4),
                            Text(
                              o.$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, fontWeight: current == o.$1 ? FontWeight.w700 : FontWeight.w500, color: Theme.of(context).textTheme.bodyMedium?.color),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The "Appearance" block for Settings: animated toggle plus the three-way choice.
class DropAppearanceCard extends StatelessWidget {
  const DropAppearanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Choose how DROP looks. System default follows your phone.', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const DropThemeToggle(),
            ],
          ),
          const SizedBox(height: 10),
          const DropThemeSelector(),
        ],
      ),
    );
  }
}
