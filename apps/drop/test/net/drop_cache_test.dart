import 'package:drop/service/net/drop_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'USER_ID': 7, 'unrelated': 'keep me'}));

  test('saves with a timestamp and reads it back', () async {
    final at = DateTime(2026, 11, 20, 9);
    await DropCache.put('dropc:7:history:rider', [
      {'id': 1}
    ], now: at);
    final e = await DropCache.read('dropc:7:history:rider');
    expect(e!.data, [
      {'id': 1}
    ]);
    expect(e.savedAt, at);
  });

  test('keys belong to the signed-in person', () async {
    expect(await DropCache.scoped('history:rider'), 'dropc:7:history:rider');
    expect(DropCache.key(null, 'x'), 'dropc:0:x');
  });

  test('an entry older than its expiry is gone', () async {
    final at = DateTime(2026, 11, 1);
    await DropCache.put('dropc:7:a', {'x': 1}, now: at);
    expect(await DropCache.read('dropc:7:a', maxAge: const Duration(days: 30), now: DateTime(2026, 11, 20)), isNotNull);
    expect(await DropCache.read('dropc:7:a', maxAge: const Duration(days: 10), now: DateTime(2026, 11, 20)), isNull);
    expect(await DropCache.read('dropc:7:a'), isNull, reason: 'expired entries are removed, not just hidden');
  });

  test('a damaged entry is dropped instead of crashing the screen', () async {
    SharedPreferences.setMockInitialValues({'dropc:7:bad': '{not json'});
    expect(await DropCache.read('dropc:7:bad'), isNull);
  });

  test('an oversized entry is not stored', () async {
    await DropCache.put('dropc:7:big', List.filled(60000, 'xxxxxxxxxx'));
    expect(await DropCache.read('dropc:7:big'), isNull);
  });

  test('sign-out wipes every saved copy and nothing else', () async {
    await DropCache.put('dropc:7:a', 1);
    await DropCache.put('dropc:7:receipt:r:5', 2);
    await DropCache.clearAll();
    expect(await DropCache.read('dropc:7:a'), isNull);
    expect(await DropCache.read('dropc:7:receipt:r:5'), isNull);
    expect((await SharedPreferences.getInstance()).getString('unrelated'), 'keep me');
  });

  test('says how old a copy is in plain words', () {
    final now = DateTime(2026, 11, 20, 12);
    expect(DropCache.ago(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(DropCache.ago(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(DropCache.ago(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
    expect(DropCache.ago(now.subtract(const Duration(days: 1)), now: now), '1 day ago');
    expect(DropCache.ago(now.subtract(const Duration(days: 4)), now: now), '4 days ago');
  });
}
