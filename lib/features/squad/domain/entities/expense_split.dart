import 'package:equatable/equatable.dart';

import 'expense.dart';

/// Divides an expense into what each person owes, in minor units. Same
/// rule as match bills (BillSplit): for an equal split, everyone except the
/// payer pays their share rounded up to a whole unit, and the payer's own
/// share covers the rest — ฿1,000 ÷ 3 → ฿334 each for the others (exact
/// ฿333.33), ฿332 for the payer.
class ExpenseSplit extends Equatable {
  const ExpenseSplit._({required this.shares, this.exactCents, this.roundedCents, this.error});

  /// [participants] share it: everyone for [ExpenseSplitMode.equal], the
  /// ticked people for [ExpenseSplitMode.chosen]. [exactCents] are the
  /// typed amounts for [ExpenseSplitMode.exact].
  factory ExpenseSplit.compute({
    required ExpenseSplitMode mode,
    required int totalCents,
    required String payerId,
    required List<String> participants,
    Map<String, int> exactCents = const {},
  }) {
    if (totalCents <= 0) return const ExpenseSplit._(shares: {}, error: 'Enter an amount');
    return switch (mode) {
      ExpenseSplitMode.treat => ExpenseSplit._(shares: {payerId: totalCents}),
      ExpenseSplitMode.exact => _exact(totalCents, exactCents),
      ExpenseSplitMode.equal ||
      ExpenseSplitMode.chosen => _equal(totalCents, payerId, participants),
    };
  }

  static ExpenseSplit _equal(int total, String payerId, List<String> participants) {
    final people = participants.toSet().toList();
    final count = people.length;
    if (count == 0) return const ExpenseSplit._(shares: {}, error: 'Pick who shares it');
    final exact = (total / count).round();
    // Ceiling division to a whole unit (100 minor units).
    final rounded = (total + count * 100 - 1) ~/ (count * 100) * 100;
    final payerCovers = total - rounded * (count - 1);
    if (people.contains(payerId) && payerCovers >= 0) {
      return ExpenseSplit._(
        shares: {for (final id in people) id: id == payerId ? payerCovers : rounded},
        exactCents: exact,
        roundedCents: rounded,
      );
    }
    // The payer only fronted it (or the amount is too small to round):
    // split to the minor unit, the first few taking any leftover unit.
    final base = total ~/ count;
    final leftover = total - base * count;
    return ExpenseSplit._(
      shares: {for (final (index, id) in people.indexed) id: base + (index < leftover ? 1 : 0)},
      exactCents: exact,
    );
  }

  static ExpenseSplit _exact(int total, Map<String, int> entered) {
    final shares = {
      for (final MapEntry(:key, :value) in entered.entries)
        if (value > 0) key: value,
    };
    final sum = shares.values.fold(0, (a, b) => a + b);
    if (shares.isEmpty) return ExpenseSplit._(shares: shares, error: 'Type at least one share');
    if (sum != total) {
      return ExpenseSplit._(shares: shares, error: 'Shares add up to $sum, not $total');
    }
    return ExpenseSplit._(shares: shares);
  }

  /// What each person owes, summing to the total — or partial if [error].
  final Map<String, int> shares;

  /// Each person's share to the minor unit, for equal splits (e.g. 33333).
  final int? exactCents;

  /// Each non-payer's share rounded up to a whole unit (e.g. 33400), when
  /// the payer is in an equal split and covers the rest.
  final int? roundedCents;

  /// Why it can't be saved yet, e.g. exact shares that don't add up.
  final String? error;

  bool get isValid => error == null;

  @override
  List<Object?> get props => [shares, exactCents, roundedCents, error];
}
