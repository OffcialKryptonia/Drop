import 'package:drop/drop/design/drop_theme.dart';
import 'package:drop/drop/widgets/drop_theme_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child, {bool disableAnimations = false}) => ValueListenableBuilder<DropThemePref>(
      valueListenable: DropTheme.pref,
      builder: (_, __, ___) => MaterialApp(
        themeMode: DropTheme.themeMode,
        theme: ThemeData.light(),
        darkTheme: DropTheme.dark(primary: const Color(0xFFE5441A)),
        builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: disableAnimations), child: w!),
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DropTheme.resetForTest();
    DropTheme.load(await SharedPreferences.getInstance(), platform: Brightness.light);
  });

  testWidgets('tapping the sun/moon switches to Dark, animates, and reports its state to accessibility', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(app(const DropThemeToggle()));
    expect(find.bySemanticsLabel('Light mode on. Switch to dark mode'), findsOneWidget);

    await t.tap(find.byType(DropThemeToggle));
    await t.pump(const Duration(milliseconds: 80));
    expect(DropTheme.pref.value, DropThemePref.dark);
    // Mid-flight: the knob is between day and night.
    final mid = t.widget<CustomPaint>(find.descendant(of: find.byType(DropThemeToggle), matching: find.byType(CustomPaint)).first);
    final tMid = (mid.painter as SunMoonPainter).t;
    expect(tMid, greaterThan(0));
    expect(tMid, lessThan(1.2));

    await t.pumpAndSettle();
    final end = t.widget<CustomPaint>(find.descendant(of: find.byType(DropThemeToggle), matching: find.byType(CustomPaint)).first);
    expect((end.painter as SunMoonPainter).t, closeTo(1, 0.01));
    expect(find.bySemanticsLabel('Dark mode on. Switch to light mode'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the app theme really changes to dark when toggled, and back', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(app(Builder(builder: (c) { ctx = c; return const DropThemeToggle(); })));
    expect(Theme.of(ctx).brightness, Brightness.light);
    await t.tap(find.byType(DropThemeToggle));
    await t.pumpAndSettle();
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(Theme.of(ctx).scaffoldBackgroundColor.computeLuminance(), lessThan(0.05));
    await t.tap(find.byType(DropThemeToggle));
    await t.pumpAndSettle();
    expect(Theme.of(ctx).brightness, Brightness.light);
  });

  testWidgets('with "remove animations" the toggle jumps straight to the end state', (t) async {
    await t.pumpWidget(app(const DropThemeToggle(), disableAnimations: true));
    await t.tap(find.byType(DropThemeToggle));
    await t.pump();
    final p = t.widget<CustomPaint>(find.descendant(of: find.byType(DropThemeToggle), matching: find.byType(CustomPaint)).first);
    expect((p.painter as SunMoonPainter).t, 1);
  });

  testWidgets('the selector offers System default / Light / Dark and applies each', (t) async {
    await t.pumpWidget(app(const DropThemeSelector()));
    expect(find.text('System default'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('theme-dark')));
    await t.pumpAndSettle();
    expect(DropTheme.pref.value, DropThemePref.dark);
    await t.tap(find.byKey(const ValueKey('theme-light')));
    await t.pumpAndSettle();
    expect(DropTheme.pref.value, DropThemePref.light);
    await t.tap(find.byKey(const ValueKey('theme-system')));
    await t.pumpAndSettle();
    expect(DropTheme.pref.value, DropThemePref.system);
  });

  testWidgets('toggle follows a change made elsewhere (selector) without a tap', (t) async {
    await t.pumpWidget(app(const Column(mainAxisSize: MainAxisSize.min, children: [DropThemeToggle(), DropThemeSelector()])));
    await t.tap(find.byKey(const ValueKey('theme-dark')));
    await t.pumpAndSettle();
    final p = t.widget<CustomPaint>(find.descendant(of: find.byType(DropThemeToggle), matching: find.byType(CustomPaint)).first);
    expect((p.painter as SunMoonPainter).t, closeTo(1, 0.01));
  });

  testWidgets('the painter draws at both ends and overshoot without throwing', (t) async {
    for (final v in [0.0, 0.3, 0.5, 1.0, 1.08, -0.05]) {
      await t.pumpWidget(MaterialApp(home: CustomPaint(size: const Size(68, 34), painter: SunMoonPainter(v))));
    }
  });
}
