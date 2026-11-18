import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// One way to write money everywhere in DROP: `₦2,912.96`, and `-₦436.94` for a negative amount
/// (the sign always comes before the symbol, never `₦ -436.94`).
class DropMoney {
  DropMoney._();

  static const String naira = '₦';

  /// Turns anything the API sends (number, numeric string, null) into a number.
  static double toNum(dynamic v) => v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);

  /// [decimals] null means: no decimals for whole amounts, two decimals otherwise.
  /// [signed] adds a leading `+` to positive amounts (for transaction rows).
  static String format(dynamic value, {String symbol = naira, bool signed = false, int? decimals}) {
    final v = toNum(value);
    final abs = v.abs();
    final isZero = abs < 0.005;
    final d = decimals ?? ((isZero || abs == abs.roundToDouble()) ? 0 : 2);
    final fixed = (isZero ? 0.0 : abs).toStringAsFixed(d);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    final body = '$symbol$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
    if (isZero) return body;
    if (v < 0) return '-$body';
    return signed ? '+$body' : body;
  }
}

/// Money as text with fixed-width digits, so values do not jitter while they change.
class DropMoneyText extends StatelessWidget {
  const DropMoneyText(
    this.value, {
    super.key,
    this.style,
    this.signed = false,
    this.decimals,
    this.symbol = DropMoney.naira,
    this.maxLines = 1,
    this.textAlign,
  });

  final dynamic value;
  final TextStyle? style;
  final bool signed;
  final int? decimals;
  final String symbol;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text(
      DropMoney.format(value, symbol: symbol, signed: signed, decimals: decimals),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}
