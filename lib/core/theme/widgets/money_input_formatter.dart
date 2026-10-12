import 'package:flutter/services.dart';

/// Formats a money field as it's typed: thousands commas ("12,500"), one
/// decimal point, at most [decimals] digits after it. The caret stays
/// after the same digit it was after, however many commas move.
///
/// Parsers should strip commas (`parseMoney` already does).
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.decimals = 2});

  final int decimals;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    // Digits (and the point) before the caret — where it lands after.
    final caret = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, raw.length)
        : raw.length;
    var significantBefore = _significant(raw.substring(0, caret));

    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    final point = cleaned.indexOf('.');
    var whole = point < 0 ? cleaned : cleaned.substring(0, point);
    var fraction = point < 0 ? null : cleaned.substring(point + 1).replaceAll('.', '');
    if (fraction != null && fraction.length > decimals) {
      // Typed past the last decimal: keep what was there.
      return oldValue;
    }
    if (decimals == 0) fraction = null;
    // No leading zeros ("007"), but "0.5" keeps its zero — and "." alone
    // becomes "0.". Both shift the digits the caret counts past.
    final typedWhole = whole;
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.isEmpty && fraction != null) whole = '0';
    significantBefore += whole.length - typedWhole.length;

    final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    final text = fraction == null ? grouped : '$grouped.$fraction';

    significantBefore = significantBefore.clamp(0, _significant(text));
    var offset = 0;
    for (var seen = 0; offset < text.length && seen < significantBefore; offset++) {
      if (text[offset] != ',') seen++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  static int _significant(String text) => text.replaceAll(RegExp(r'[^0-9.]'), '').length;
}
