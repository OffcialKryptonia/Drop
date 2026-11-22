import 'package:drop/drop/design/drop_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dialogs, sheets, inputs, cards, list tiles, menus and snackbars must all turn dark with the theme.
void main() {
  Widget host(Widget body) => MaterialApp(
        themeMode: ThemeMode.dark,
        theme: ThemeData.light(),
        darkTheme: DropTheme.dark(primary: const Color(0xFFE5441A)),
        home: Scaffold(body: body),
      );

  Color? bgOf(WidgetTester t, Finder f) {
    final m = t.widget<Material>(find.descendant(of: f, matching: find.byType(Material)).first);
    return m.color;
  }

  testWidgets('AlertDialog is dark with readable text', (t) async {
    await t.pumpWidget(host(Builder(builder: (c) => TextButton(onPressed: () => showDialog(context: c, builder: (_) => const AlertDialog(title: Text('Cancel ride?'), content: Text('Are you sure?'))), child: const Text('open')))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(bgOf(t, find.byType(AlertDialog))!.computeLuminance(), lessThan(0.05));
    final title = t.widget<Text>(find.text('Cancel ride?'));
    final style = DefaultTextStyle.of(t.element(find.text('Cancel ride?'))).style.merge(title.style);
    expect(style.color == null || style.color!.computeLuminance() > 0.5, isTrue);
  });

  testWidgets('bottom sheet is dark', (t) async {
    await t.pumpWidget(host(Builder(builder: (c) => TextButton(onPressed: () => showModalBottomSheet(context: c, builder: (_) => const SizedBox(height: 200, child: Text('sheet'))), child: const Text('open')))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(bgOf(t, find.byType(BottomSheet))!.computeLuminance(), lessThan(0.05));
  });

  testWidgets('text field, card, list tile, switch, snackbar and popup menu use dark colours', (t) async {
    await t.pumpWidget(host(Builder(builder: (c) => ListView(children: [
          const TextField(decoration: InputDecoration(hintText: 'Where to?')),
          const Card(child: ListTile(title: Text('Wallet'), subtitle: Text('₦1,200'))),
          Switch(value: true, onChanged: (_) {}),
          TextButton(onPressed: () => ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('Saved'))), child: const Text('snack')),
        ]))));
    final field = t.widget<InputDecorator>(find.byType(InputDecorator));
    expect(field.decoration.fillColor ?? Theme.of(t.element(find.byType(TextField))).inputDecorationTheme.fillColor, isNotNull);
    expect(Theme.of(t.element(find.byType(Card))).cardColor.computeLuminance(), lessThan(0.05));
    final tile = Theme.of(t.element(find.byType(ListTile))).listTileTheme;
    expect(tile.textColor!.computeLuminance(), greaterThan(0.8));
    await t.tap(find.text('snack'));
    await t.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(Theme.of(t.element(find.byType(Scaffold).first)).snackBarTheme.backgroundColor!.computeLuminance(), lessThan(0.05));
  });

  testWidgets('primary button text stays readable on the brand colour', (t) async {
    final scheme = DropTheme.dark(primary: const Color(0xFFE5441A)).colorScheme;
    double c(Color a, Color b) { final x = a.computeLuminance(), y = b.computeLuminance(); return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05); }
    expect(c(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(3.5)); // large/bold button text
    expect(c(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(7));
  });
}
