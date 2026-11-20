import 'package:drop/drop/widgets/drop_ride_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host({required List<Map<String, dynamic>> stops, int max = 3, VoidCallback? onAdd, void Function(int)? onRemove, void Function(int, int)? onMove, bool busy = false}) => MaterialApp(
      home: Scaffold(body: DropStopsEditor(stops: stops, max: max, busy: busy, onAdd: onAdd ?? () {}, onRemove: onRemove ?? (_) {}, onMove: onMove ?? (_, __) {})),
    );

void main() {
  testWidgets('with no stops it offers Add stop and shows the limit', (tester) async {
    var added = 0;
    await tester.pumpWidget(host(stops: [], onAdd: () => added++));
    expect(find.text('Add stop (0/3)'), findsOneWidget);
    await tester.tap(find.text('Add stop (0/3)'));
    expect(added, 1);
  });

  testWidgets('stops are listed in order and can be removed', (tester) async {
    int? removed;
    await tester.pumpWidget(host(stops: [
      {'address': 'Wuse Market'},
      {'address': 'Jabi Lake'},
    ], onRemove: (i) => removed = i));
    expect(find.text('Stop 1: Wuse Market'), findsOneWidget);
    expect(find.text('Stop 2: Jabi Lake'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove stop').last);
    expect(removed, 1);
  });

  testWidgets('the first stop cannot move up and the last cannot move down', (tester) async {
    (int, int)? moved;
    await tester.pumpWidget(host(stops: [
      {'address': 'A'},
      {'address': 'B'},
    ], onMove: (a, b) => moved = (a, b)));
    await tester.tap(find.byTooltip('Move stop down').first);
    expect(moved, (0, 1));
    moved = null;
    await tester.tap(find.byTooltip('Move stop up').first, warnIfMissed: false);
    expect(moved, isNull);
  });

  testWidgets('at the limit the Add stop button goes away', (tester) async {
    await tester.pumpWidget(host(stops: [
      {'address': 'A'},
      {'address': 'B'},
    ], max: 2));
    expect(find.textContaining('Add stop'), findsNothing);
  });

  testWidgets('when the admin sets the limit to zero nothing is shown', (tester) async {
    await tester.pumpWidget(host(stops: [], max: 0));
    expect(find.textContaining('Add stop'), findsNothing);
  });

  testWidgets('while pricing, the controls are disabled', (tester) async {
    var added = 0;
    await tester.pumpWidget(host(stops: [], busy: true, onAdd: () => added++));
    await tester.tap(find.textContaining('Add stop'), warnIfMissed: false);
    expect(added, 0);
  });
}
