import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/Constants.dart' show USER_ID;

/// A saved copy of something the server told us, with the time we saved it. Always shown as "saved",
/// never as live: the screens use [savedAt] to say how old it is.
class CacheEntry {
  CacheEntry(this.data, this.savedAt);
  final dynamic data;
  final DateTime savedAt;

  Duration age([DateTime? now]) => (now ?? DateTime.now()).difference(savedAt);
  bool isOlderThan(Duration ttl, [DateTime? now]) => age(now) > ttl;
}

/// Small on-device cache for non-sensitive, display-only information (ride history, receipts, help text).
///
/// Rules: keys are per signed-in person and wiped at sign-out; every entry has a timestamp and an expiry;
/// nothing authoritative lives here. Wallet balances, driver availability and ride status are never cached.
class DropCache {
  DropCache._();

  static const _prefix = 'dropc:';
  static const maxEntryBytes = 400 * 1024;

  static String key(int? userId, String name) => '$_prefix${userId ?? 0}:$name';

  /// The key for [name] belonging to whoever is signed in now.
  static Future<String> scoped(String name) async => key((await SharedPreferences.getInstance()).getInt(USER_ID), name);

  static Future<void> put(String key, Object? data, {DateTime? now}) async {
    final encoded = jsonEncode({'t': (now ?? DateTime.now()).millisecondsSinceEpoch, 'd': data});
    if (encoded.length > maxEntryBytes) return; // never let a cache grow without limit
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, encoded);
  }

  /// The saved copy, or null if there is none or it is older than [maxAge].
  static Future<CacheEntry?> read(String key, {Duration? maxAge, DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map;
      final entry = CacheEntry(m['d'], DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt()));
      if (maxAge != null && entry.isOlderThan(maxAge, now)) {
        await prefs.remove(key);
        return null;
      }
      return entry;
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  static Future<void> remove(String key) async => (await SharedPreferences.getInstance()).remove(key);

  /// Sign-out: nothing of the person stays behind.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(k);
    }
  }

  /// "just now", "5 min ago", "3 h ago", "2 days ago".
  static String ago(DateTime savedAt, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(savedAt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    final days = d.inDays;
    return days == 1 ? '1 day ago' : '$days days ago';
  }
}
