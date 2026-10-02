import 'package:equatable/equatable.dart';

import '../../../team_membership/domain/entities/team.dart';
import 'expense.dart';
import 'settlement.dart';
import 'squad_member.dart';

/// One payment that settles (part of) a debt.
class Debt extends Equatable {
  const Debt({
    required this.fromId,
    required this.toId,
    required this.amountCents,
    this.expenseCount,
  });

  final String fromId;
  final String toId;
  final int amountCents;

  /// For a raw (unsimplified) debt: how many expenses it comes from.
  final int? expenseCount;

  @override
  List<Object?> get props => [fromId, toId, amountCents, expenseCount];
}

/// Everything a squad's screens read: members, expenses and settlements,
/// and the balances worked out from them.
class SquadLedger extends Equatable {
  const SquadLedger({
    required this.currency,
    this.members = const [],
    this.expenses = const [],
    this.settlements = const [],
  });

  static const empty = SquadLedger(currency: GroupCurrency.thb);

  final GroupCurrency currency;
  final List<SquadMember> members;

  /// Newest first.
  final List<Expense> expenses;

  /// Newest first.
  final List<Settlement> settlements;

  SquadMember? member(String profileId) {
    for (final member in members) {
      if (member.profileId == profileId) return member;
    }
    return null;
  }

  String nameOf(String profileId, {String? me}) =>
      profileId == me ? 'You' : (member(profileId)?.name ?? 'Someone');

  Expense? expense(String id) {
    for (final expense in expenses) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  /// Each member's net position: what they paid minus their shares, plus
  /// confirmed settlements sent minus received. Positive = owed money.
  /// Pending payments don't count until the receiver confirms them.
  Map<String, int> get balances {
    final balances = {for (final member in members) member.profileId: 0};
    void add(String id, int cents) => balances[id] = (balances[id] ?? 0) + cents;
    for (final expense in expenses) {
      add(expense.payerId, expense.amountCents);
      for (final MapEntry(:key, :value) in expense.shares.entries) {
        add(key, -value);
      }
    }
    for (final settlement in settlements.where((s) => s.isConfirmed)) {
      add(settlement.fromId, settlement.amountCents);
      add(settlement.toId, -settlement.amountCents);
    }
    return balances;
  }

  int balanceOf(String profileId) => balances[profileId] ?? 0;

  /// Sent by [profileId] and still waiting for the receiver.
  List<Settlement> pendingFrom(String profileId) =>
      settlements.where((s) => s.isPending && s.fromId == profileId).toList();

  /// Sent to [profileId], waiting for them to confirm or reject.
  List<Settlement> awaitingConfirmationBy(String profileId) =>
      settlements.where((s) => s.isPending && s.toId == profileId).toList();

  int pendingCentsFrom(String profileId, {String? to}) =>
      pendingFrom(profileId)
          .where((s) => to == null || s.toId == to)
          .fold(0, (sum, s) => sum + s.amountCents);

  /// The fewest payments that zero everyone out: the biggest debtor pays
  /// the biggest creditor, again and again. A→B ฿100 + B→C ฿100 becomes
  /// A→C ฿100.
  List<Debt> get simplifiedDebts {
    final debtors = <MapEntry<String, int>>[];
    final creditors = <MapEntry<String, int>>[];
    for (final entry in balances.entries) {
      if (entry.value < 0) debtors.add(MapEntry(entry.key, -entry.value));
      if (entry.value > 0) creditors.add(MapEntry(entry.key, entry.value));
    }
    int byAmount(MapEntry<String, int> a, MapEntry<String, int> b) {
      final order = b.value.compareTo(a.value);
      return order != 0 ? order : a.key.compareTo(b.key);
    }

    debtors.sort(byAmount);
    creditors.sort(byAmount);
    final debts = <Debt>[];
    var d = 0, c = 0;
    var owe = debtors.isEmpty ? 0 : debtors[0].value;
    var owed = creditors.isEmpty ? 0 : creditors[0].value;
    while (d < debtors.length && c < creditors.length) {
      final amount = owe < owed ? owe : owed;
      if (amount > 0) {
        debts.add(Debt(fromId: debtors[d].key, toId: creditors[c].key, amountCents: amount));
      }
      owe -= amount;
      owed -= amount;
      if (owe == 0 && ++d < debtors.length) owe = debtors[d].value;
      if (owed == 0 && ++c < creditors.length) owed = creditors[c].value;
    }
    return debts;
  }

  /// Every pairwise debt, without simplifying: for each pair, what one
  /// owes the other across all expenses, less confirmed payments between
  /// them.
  List<Debt> get rawDebts {
    // Keyed (a, b) with a < b; positive = a owes b.
    final net = <(String, String), int>{};
    final counts = <(String, String), int>{};
    void owe(String from, String to, int cents, {bool countIt = false}) {
      if (from == to || cents == 0) return;
      final forward = from.compareTo(to) < 0;
      final key = forward ? (from, to) : (to, from);
      net[key] = (net[key] ?? 0) + (forward ? cents : -cents);
      if (countIt) counts[key] = (counts[key] ?? 0) + 1;
    }

    for (final expense in expenses) {
      for (final MapEntry(:key, :value) in expense.shares.entries) {
        owe(key, expense.payerId, value, countIt: true);
      }
    }
    for (final settlement in settlements.where((s) => s.isConfirmed)) {
      owe(settlement.toId, settlement.fromId, settlement.amountCents);
    }
    return [
      for (final MapEntry(key: (a, b), :value) in net.entries)
        if (value > 0)
          Debt(fromId: a, toId: b, amountCents: value, expenseCount: counts[(a, b)])
        else if (value < 0)
          Debt(fromId: b, toId: a, amountCents: -value, expenseCount: counts[(a, b)]),
    ]..sort((x, y) => y.amountCents.compareTo(x.amountCents));
  }

  @override
  List<Object?> get props => [currency, members, expenses, settlements];
}
