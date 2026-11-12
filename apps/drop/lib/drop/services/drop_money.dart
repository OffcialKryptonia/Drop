import '../../manage_imports.dart';
import '../../service/RideApi.dart';

/// Shows money in the right currency. A user's wallet uses their country's currency; a ride uses the
/// currency of the region it is priced in (the server sends it with every quote and ride).
class DropMoney {
  DropMoney._();

  /// The signed-in user's own currency symbol (their wallet).
  static String symbol = '₦';

  /// Reads the user's currency from the server and tells the older screens to use it too.
  static Future<void> load() async {
    try {
      final r = await RideApi.currency();
      final s = r['symbol']?.toString();
      if (s != null && s.isNotEmpty) {
        symbol = s;
        await appStore.setCurrencyCode(s);
      }
    } catch (_) {
      // Keep the default; money still shows, just in naira.
    }
  }

  /// `1,500` style amount with the currency symbol. [currency] is the `{symbol, decimals}` map from the server.
  static String format(dynamic v, [dynamic currency]) {
    final cur = currency is Map ? currency : const {};
    final sym = (cur['symbol']?.toString().isNotEmpty ?? false) ? cur['symbol'].toString() : symbol;
    final decimals = cur['decimals'] is num ? (cur['decimals'] as num).toInt() : 2;
    final n = v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
    final s = n.toStringAsFixed(decimals == 0 || n == n.roundToDouble() ? 0 : 2);
    final parts = s.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return '$sym$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
  }
}
