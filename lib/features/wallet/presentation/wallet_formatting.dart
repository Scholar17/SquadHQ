import '../domain/entities/team_wallet.dart';

String _withCommas(String digits) =>
    digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Whole baht, e.g. ฿1,250 — rounded if [amount] has satang.
String formatBaht(num amount) => '฿${_withCommas(amount.round().toString())}';

/// To the satang, e.g. ฿333.33.
String formatBahtExact(num amount) {
  final [whole, fraction] = amount.toStringAsFixed(2).split('.');
  return '฿${_withCommas(whole)}.$fraction';
}

String splitModeLabel(SplitMode mode) => switch (mode) {
      SplitMode.rsvpIn => 'Players who said In',
      SplitMode.team => 'Whole team',
      SplitMode.custom => 'Picked players',
    };
