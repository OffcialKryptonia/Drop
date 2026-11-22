import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hardcoded colours cannot follow Light/Dark. This keeps the count from growing; lower [baseline]
/// whenever you migrate more screens to DropTheme / Theme.of(context) tokens.
///
/// What is counted: `Colors.white`, `Colors.black` and `Color(0xAARRGGBB)` literals in lib/ (comments and the
/// theme files themselves excluded). Many remaining ones are legitimate (white text on the brand orange,
/// brand/status colours), so the goal is "never up", not zero.
const int baseline = 460;

void main() {
  test('hardcoded colour literals do not grow beyond the recorded baseline', () {
    final re = RegExp(r'Colors\.(?:white|black)(?![0-9A-Za-z])|Color\(0x[0-9A-Fa-f]{8}\)');
    var count = 0;
    final offenders = <String, int>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      if (f.path.endsWith('drop/design/drop_theme.dart') || f.path.endsWith('drop_theme_toggle.dart')) continue;
      var n = 0;
      for (final line in f.readAsLinesSync()) {
        if (line.trimLeft().startsWith('//')) continue;
        n += re.allMatches(line).length;
      }
      if (n > 0) offenders[f.path] = n;
      count += n;
    }
    final top = (offenders.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(8).map((e) => '${e.key}: ${e.value}').join('\n');
    expect(count, lessThanOrEqualTo(baseline), reason: 'Found $count (baseline $baseline). Use DropTheme / Theme.of(context) tokens. Heaviest files:\n$top');
  });

  test('the new design layer and theme widgets stay free of light-only literals', () {
    for (final p in ['lib/drop/widgets/drop_theme_toggle.dart', 'lib/drop/design/drop_theme.dart']) {
      final src = File(p).readAsStringSync();
      expect(RegExp(r'Colors\.white(?![0-9A-Za-z])').allMatches(src).length, lessThanOrEqualTo(2), reason: p);
    }
  });
}
