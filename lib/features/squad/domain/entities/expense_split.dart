import 'package:equatable/equatable.dart';

import 'expense.dart';

/// Divides an expense into what each person owes, in minor units. Same
/// rule as match bills (BillSplit): for an equal split, everyone except the
/// payer pays their share rounded up to a whole unit, and the payer's own
/// share covers the rest — ฿1,000 ÷ 3 → ฿334 each for the others (exact
/// ฿333.33), ฿332 for the payer.
class ExpenseSplit extends Equatable {
  const ExpenseSplit._({required this.shares, this.exactCents, this.roundedCents, this.error});

  /// [payerId] is whoever paid the most; with [payers] (several people
  /// paid) a treat leaves each covering what they paid. [participants] share it: everyone for [ExpenseSplitMode.equal], the
  /// ticked people for [ExpenseSplitMode.chosen] and
  /// [ExpenseSplitMode.custom]. [exactCents] are the typed amounts for
  /// [ExpenseSplitMode.exact], and for [ExpenseSplitMode.custom] where only
  /// the participants' count. [weights] are each person's % or number of
  /// shares in hundredths (40% = 4000) for [ExpenseSplitMode.percent] and
  /// [ExpenseSplitMode.shares]; anyone without one isn't in it.
  factory ExpenseSplit.compute({
    required ExpenseSplitMode mode,
    required int totalCents,
    required String payerId,
    required List<String> participants,
    Map<String, int> exactCents = const {},
    Map<String, int> weights = const {},
    Map<String, int>? payers,
  }) {
    if (totalCents <= 0) return const ExpenseSplit._(shares: {}, error: 'Enter an amount');
    return switch (mode) {
      // A treat: each payer covers what they paid, so nobody owes.
      ExpenseSplitMode.treat => ExpenseSplit._(shares: payers ?? {payerId: totalCents}),
      // A loan: whoever didn't pay borrowed it and owes all of it.
      ExpenseSplitMode.borrow => _borrow(totalCents, payerId, participants),
      ExpenseSplitMode.exact => _exact(totalCents, exactCents),
      ExpenseSplitMode.custom =>
        participants.isEmpty
            ? const ExpenseSplit._(shares: {}, error: 'Pick who shares it')
            : _exact(totalCents, {for (final id in participants) id: ?exactCents[id]}),
      ExpenseSplitMode.equal ||
      ExpenseSplitMode.chosen => _equal(totalCents, payerId, participants),
      ExpenseSplitMode.percent => _weighted(totalCents, weights, percent: true),
      ExpenseSplitMode.shares => _weighted(totalCents, weights, percent: false),
    };
  }

  static ExpenseSplit _borrow(int total, String payerId, List<String> participants) {
    final borrowers = participants.where((id) => id != payerId).toSet();
    if (borrowers.length != 1) {
      return const ExpenseSplit._(shares: {}, error: 'Pick who borrowed it');
    }
    return ExpenseSplit._(shares: {borrowers.single: total});
  }

  /// 100% in hundredths.
  static const fullPercent = 10000;

  /// Shares the total in proportion to [entered] weights, to the minor
  /// unit: everyone gets their exact share rounded down, and the units
  /// left go one each to whoever lost the most in rounding (first listed
  /// on a tie) — so it always adds up to [total].
  static ExpenseSplit _weighted(int total, Map<String, int> entered, {required bool percent}) {
    final weights = {
      for (final MapEntry(:key, :value) in entered.entries)
        if (value > 0) key: value,
    };
    if (weights.isEmpty) {
      return ExpenseSplit._(
        shares: const {},
        error: percent ? 'Type each person’s %' : 'Type each person’s shares',
      );
    }
    final sum = weights.values.fold(0, (a, b) => a + b);
    final divisor = percent ? fullPercent : sum;
    final shares = <String, int>{};
    final remainders = <String, int>{};
    for (final MapEntry(:key, :value) in weights.entries) {
      shares[key] = total * value ~/ divisor;
      remainders[key] = total * value % divisor;
    }
    if (percent && sum != fullPercent) {
      return ExpenseSplit._(
        shares: shares,
        error: 'Percents add up to ${_percentText(sum)}%, not 100%',
      );
    }
    var left = total - shares.values.fold(0, (a, b) => a + b);
    final ids = weights.keys.toList();
    final order = [...ids]
      ..sort((a, b) {
        final byRemainder = remainders[b]!.compareTo(remainders[a]!);
        return byRemainder != 0 ? byRemainder : ids.indexOf(a).compareTo(ids.indexOf(b));
      });
    for (final id in order) {
      if (left == 0) break;
      shares[id] = shares[id]! + 1;
      left--;
    }
    return ExpenseSplit._(shares: shares);
  }

  /// 3333 → "33.33", 10000 → "100".
  static String _percentText(int hundredths) {
    final whole = hundredths ~/ 100;
    final fraction = hundredths % 100;
    if (fraction == 0) return '$whole';
    return '$whole.${fraction.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}';
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
