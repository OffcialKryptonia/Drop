import 'package:drop/drop/design/drop_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    DropTheme.resetForTest();
  });

  Future<SharedPreferences> prefs([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPreferences.getInstance();
  }

  test('defaults to System when nothing is saved or the saved value is unknown', () async {
    DropTheme.load(await prefs(), platform: Brightness.light);
    expect(DropTheme.pref.value, DropThemePref.system);
    DropTheme.load(await prefs({DropTheme.prefsKey: 'purple'}), platform: Brightness.light);
    expect(DropTheme.pref.value, DropThemePref.system);
  });

  test('restores the saved choice at start-up (no flash on first frame)', () async {
    DropTheme.load(await prefs({DropTheme.prefsKey: 'dark'}), platform: Brightness.light);
    expect(DropTheme.pref.value, DropThemePref.dark);
    expect(DropTheme.isDark, isTrue);
    expect(DropTheme.themeMode, ThemeMode.dark);
  });

  test('System follows the phone; explicit Light/Dark ignore it', () async {
    DropTheme.load(await prefs(), platform: Brightness.dark);
    expect(DropTheme.isDark, isTrue);
    expect(DropTheme.themeMode, ThemeMode.system);
    await DropTheme.setPref(DropThemePref.light);
    expect(DropTheme.isDark, isFalse);
    DropTheme.updatePlatform(Brightness.light);
    await DropTheme.setPref(DropThemePref.dark);
    expect(DropTheme.isDark, isTrue);
  });

  test('a choice is persisted and survives a restart', () async {
    final p = await prefs();
    DropTheme.load(p, platform: Brightness.light);
    await DropTheme.setPref(DropThemePref.dark);
    expect(p.getString(DropTheme.prefsKey), 'dark');
    DropTheme.resetForTest();
    DropTheme.load(p, platform: Brightness.light);
    expect(DropTheme.pref.value, DropThemePref.dark);
  });

  test('revision only bumps when the effective brightness really changes', () async {
    DropTheme.load(await prefs(), platform: Brightness.light);
    var bumps = 0;
    DropTheme.revision.addListener(() => bumps++);
    await DropTheme.setPref(DropThemePref.light); // light -> light
    expect(bumps, 0);
    await DropTheme.setPref(DropThemePref.dark);
    expect(bumps, 1);
    await DropTheme.setPref(DropThemePref.system); // phone is light -> light again
    expect(bumps, 2);
    DropTheme.updatePlatform(Brightness.dark); // phone goes dark while on System
    expect(bumps, 3);
    await DropTheme.setPref(DropThemePref.dark); // dark -> dark
    expect(bumps, 3);
  });

  test('toggle flips what is showing, including when on System', () async {
    DropTheme.load(await prefs(), platform: Brightness.dark);
    await DropTheme.toggle();
    expect(DropTheme.pref.value, DropThemePref.light);
    await DropTheme.toggle();
    expect(DropTheme.pref.value, DropThemePref.dark);
  });

  test('a storage failure does not break switching', () async {
    DropTheme.load(await prefs(), platform: Brightness.light);
    // no prefs attached (as if unavailable)
    DropTheme.resetForTest();
    await DropTheme.setPref(DropThemePref.dark);
    expect(DropTheme.isDark, isTrue);
  });

  double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  test('text tokens are readable (WCAG AA 4.5:1) on every surface in both themes', () async {
    for (final dark in [false, true]) {
      DropTheme.load(await prefs({DropTheme.prefsKey: dark ? 'dark' : 'light'}), platform: Brightness.light);
      for (final bg in [DropTheme.scaffold, DropTheme.card, DropTheme.cardAlt, DropTheme.inputFill]) {
        expect(contrast(DropTheme.text, bg), greaterThanOrEqualTo(7), reason: 'text on $bg dark=$dark');
        expect(contrast(DropTheme.muted, bg), greaterThanOrEqualTo(4.5), reason: 'muted on $bg dark=$dark');
      }
    }
  });

  test('dark surfaces are dark and light surfaces are light', () async {
    DropTheme.load(await prefs({DropTheme.prefsKey: 'dark'}), platform: Brightness.light);
    for (final c in [DropTheme.scaffold, DropTheme.card, DropTheme.cardAlt]) {
      expect(c.computeLuminance(), lessThan(0.05));
    }
    DropTheme.load(await prefs({DropTheme.prefsKey: 'light'}), platform: Brightness.light);
    for (final c in [DropTheme.scaffold, DropTheme.card, DropTheme.cardAlt]) {
      expect(c.computeLuminance(), greaterThan(0.85));
    }
  });
}
