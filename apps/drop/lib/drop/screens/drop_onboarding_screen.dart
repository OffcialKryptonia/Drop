import 'dart:math' as math;

import '../../manage_imports.dart';
import '../design/drop_design.dart';
import 'drop_intro.dart';

/// First-run experience: animated DROP logo, then four short slides, with
/// "Get started" and "Log in" always one tap away.
class DropOnboardingScreen extends StatefulWidget {
  const DropOnboardingScreen({super.key});

  @override
  State<DropOnboardingScreen> createState() => _DropOnboardingScreenState();
}

enum _Art { book, confidence, track, reliable }

class _Slide {
  const _Slide(this.title, this.body, this.art);

  final String title;
  final String body;
  final _Art art;
}

const List<_Slide> _slides = <_Slide>[
  _Slide('Book a ride in seconds', 'Set your pickup and drop-off, see your fare upfront, then request a ride.', _Art.book),
  _Slide('Move around your city with confidence', 'Approved drivers and fares you can see before you ride.', _Art.confidence),
  _Slide('Track your driver and trip', 'Watch your driver arrive and follow your journey on the map.', _Art.track),
  _Slide('A ride you can rely on', 'Pay with cash or your DROP wallet and get where you are going.', _Art.reliable),
];

class _DropOnboardingScreenState extends State<DropOnboardingScreen> {
  final PageController _pages = PageController();
  int _page = 0;
  bool _introDone = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _leave(Widget next) async {
    await sharedPref.setBool(IS_FIRST_TIME, false);
    if (!mounted) return;
    launchScreen(context, next, isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DropColors.background(context),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _introDone
            ? _buildSlides(context)
            : DropIntro(
                key: const ValueKey<String>('intro'),
                onDone: () {
                  if (mounted) setState(() => _introDone = true);
                },
              ),
      ),
    );
  }

  Widget _buildSlides(BuildContext context) {
    return SafeArea(
      key: const ValueKey<String>('slides'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DropSpacing.lg, DropSpacing.sm, DropSpacing.sm, 0),
            child: Row(
              children: [
                const DropLogo(height: 26),
                const Spacer(),
                TextButton(
                  onPressed: () => _leave(SignInScreen()),
                  child: Text(
                    'Skip',
                    style: TextStyle(color: DropColors.mutedText(context), fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _slides.length,
              onPageChanged: (int i) => setState(() => _page = i),
              itemBuilder: (BuildContext context, int i) => _SlidePage(slide: _slides[i]),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(_slides.length, (int i) {
              final bool active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 8,
                width: active ? 24 : 8,
                decoration: BoxDecoration(
                  color: active ? DropColors.primary : DropColors.hairline(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: DropSpacing.lg),
          Padding(
            padding: const EdgeInsets.fromLTRB(DropSpacing.lg, 0, DropSpacing.lg, DropSpacing.lg),
            child: Column(
              children: [
                DropPrimaryButton(label: 'Get started', onPressed: () => _leave(SignUpScreen())),
                const SizedBox(height: 12),
                DropSecondaryButton(label: 'Log in', onPressed: () => _leave(SignInScreen())),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DropSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: DropSpacing.md),
          Expanded(child: Center(child: _SlideArt(kind: slide.art))),
          const SizedBox(height: DropSpacing.lg),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: DropColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.4, color: DropColors.mutedText(context)),
          ),
          const SizedBox(height: DropSpacing.lg),
        ],
      ),
    );
  }
}

/// Original illustrations built from the DROP palette. They echo real screens in the app.
class _SlideArt extends StatelessWidget {
  const _SlideArt({required this.kind});

  final _Art kind;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DropColors.surface(context),
          borderRadius: BorderRadius.circular(DropRadius.card + 4),
          border: Border.all(color: DropColors.hairline(context)),
        ),
        child: switch (kind) {
          _Art.book => _bookArt(context),
          _Art.confidence => _confidenceArt(context),
          _Art.track => _trackArt(context),
          _Art.reliable => _reliableArt(context),
        },
      ),
    );
  }

  Widget _routeRow(BuildContext context, IconData icon, Color color, String label, String place) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: DropColors.mutedText(context))),
              Text(
                place,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DropColors.text(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? DropColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? DropColors.primary : DropColors.hairline(context)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? DropColors.primary : DropColors.text(context),
        ),
      ),
    );
  }

  Widget _bookArt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _routeRow(context, Icons.circle, DropColors.success, 'Pickup', 'Wuse 2, Abuja'),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
            width: 2,
            height: 22,
            color: DropColors.hairline(context).withValues(alpha: 0.2),
          ),
        ),
        _routeRow(context, Icons.square_rounded, DropColors.primary, 'Drop-off', 'Jabi Lake Mall'),
        const SizedBox(height: 20),
        Row(
          children: [
            _chip(context, 'Economy', selected: true),
            const SizedBox(width: 8),
            _chip(context, 'Comfort'),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: DropColors.primary, borderRadius: BorderRadius.circular(12)),
          child: const Text('Request ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _pill(BuildContext context, IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DropColors.background(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DropColors.hairline(context)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: DropColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DropColors.text(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidenceArt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(color: DropColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.verified_user_rounded, size: 52, color: Colors.white),
        ),
        const SizedBox(height: 22),
        _pill(context, Icons.badge_outlined, 'Approved drivers'),
        const SizedBox(height: 10),
        _pill(context, Icons.receipt_long_outlined, 'Know your fare upfront'),
      ],
    );
  }

  Widget _trackArt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 190,
          width: double.infinity,
          child: CustomPaint(painter: _RoutePainter(DropColors.primary, DropColors.hairline(context))),
        ),
        const SizedBox(height: 14),
        _pill(context, Icons.access_time_rounded, 'Driver arriving in 3 min'),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label) {
    return Expanded(
      child: Container(
        height: 112,
        decoration: BoxDecoration(
          color: DropColors.background(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DropColors.hairline(context)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: DropColors.primary),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DropColors.text(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reliableArt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _tile(context, Icons.account_balance_wallet_rounded, 'DROP wallet'),
            const SizedBox(width: 12),
            _tile(context, Icons.payments_rounded, 'Cash'),
          ],
        ),
        const SizedBox(height: 14),
        _pill(context, Icons.location_on_rounded, 'Drivers near you'),
      ],
    );
  }
}

/// A dashed route between two points with a car marker, drawn in the DROP palette.
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.color, this.guide);

  final Color color;
  final Color guide;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset a = Offset(size.width * 0.12, size.height * 0.82);
    final Offset b = Offset(size.width * 0.88, size.height * 0.18);
    final Path path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(size.width * 0.15, size.height * 0.25, size.width * 0.55, size.height * 0.95, b.dx, b.dy);

    // Street-grid hint.
    final Paint grid = Paint()
      ..color = guide
      ..strokeWidth = 1;
    for (int i = 1; i < 5; i++) {
      final double y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      final double x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    // Dashed route.
    final Paint dash = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final double end = math.min(d + 12, metric.length);
        canvas.drawPath(metric.extractPath(d, end), dash);
        d += 20;
      }
      final tangent = metric.getTangentForOffset(metric.length * 0.55);
      if (tangent != null) {
        canvas.drawCircle(tangent.position, 17, Paint()..color = color);
        final TextPainter icon = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(Icons.directions_car_filled_rounded.codePoint),
            style: TextStyle(
              fontSize: 20,
              fontFamily: Icons.directions_car_filled_rounded.fontFamily,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        icon.paint(canvas, tangent.position - Offset(icon.width / 2, icon.height / 2));
      }
    }

    canvas.drawCircle(a, 8, Paint()..color = DropColors.success);
    canvas.drawCircle(b, 8, Paint()..color = color);
    canvas.drawCircle(b, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => old.color != color || old.guide != guide;
}
