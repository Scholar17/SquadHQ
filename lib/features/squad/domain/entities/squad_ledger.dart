import 'package:equatable/equatable.dart';

import '../../../team_membership/domain/entities/team.dart';
import 'expense.dart';
import 'payment_promise.dart';
import 'settlement.dart';
import 'recurring_expense.dart';
import 'squad_member.dart';
import 'trip.dart';

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

/// One line behind a [Debt] (see [SquadLedger.debtLines]): an expense the
/// debtor owes for (+), one the creditor owes the debtor for (−), or money
/// one of them paid the other beyond their shares (no [expense]).
class DebtLine extends Equatable {
  const DebtLine({required this.cents, this.expense, this.fullCents});

  /// Signed: positive adds to the debt, negative takes off it.
  final int cents;
  final Expense? expense;

  /// The whole share when payments already covered part of it.
  final int? fullCents;

  bool get isPartlyPaid => fullCents != null && fullCents != cents.abs();

  @override
  List<Object?> get props => [cents, expense, fullCents];
}

/// [SquadLedger.statement]: what one person owes another and why.
typedef PairStatement = ({
  List<({Expense expense, int cents})> aOwes,
  List<({Expense expense, int cents})> bOwes,
  List<Settlement> payments,
  int total,
});

/// A payment that came back rejected, and the one sent again in its place
/// while it's still waiting (see [SquadLedger.sentBackTo]).
typedef SentBack = ({Settlement rejected, Settlement? resent});

/// A "Remind" sent to [toId] by [fromId].
class SquadReminder extends Equatable {
  const SquadReminder({required this.fromId, required this.toId, required this.at, this.tripId});

  final String fromId;
  final String toId;
  final DateTime at;

  /// A trip's "Remind to pay" (035); null for the squad's own.
  final String? tripId;

  @override
  List<Object?> get props => [fromId, toId, at, tripId];
}

/// Everything a squad's screens read: members, expenses and settlements,
/// and the balances worked out from them. [expenses] and [settlements] are
/// the squad's own; each trip's are kept apart ([forTrip]) so trip debts
/// never mix with the squad's.
class SquadLedger extends Equatable {
  const SquadLedger({
    required this.currency,
    this.members = const [],
    this.expenses = const [],
    this.settlements = const [],
    this.reminders = const [],
    this.trips = const [],
    this.tripExpenses = const [],
    this.tripSettlements = const [],
    this.tripReminders = const [],
    this.recurring = const [],
    this.promises = const [],
    this.tripPromises = const [],
  });

  static const empty = SquadLedger(currency: GroupCurrency.thb);

  final GroupCurrency currency;
  final List<SquadMember> members;

  /// Newest first.
  final List<Expense> expenses;

  /// Newest first.
  final List<Settlement> settlements;

  /// Recent reminders (the last couple of days), for the once-a-day rule.
  final List<SquadReminder> reminders;

  /// Newest first.
  final List<Trip> trips;

  /// Every trip's expenses and payments, newest first (see [forTrip]).
  final List<Expense> tripExpenses;
  final List<Settlement> tripSettlements;
  final List<SquadReminder> tripReminders;

  /// Monthly expenses (subscriptions); each month's charge is in [expenses].
  final List<RecurringExpense> recurring;

  /// "I'll pay on …" promises — the squad's, and each trip's apart.
  final List<PaymentPromise> promises;
  final List<PaymentPromise> tripPromises;

  /// [fromId]'s promise to pay [toId] that's still to come (today counts).
  PaymentPromise? promiseFrom(String fromId, String toId, {DateTime? now}) {
    for (final promise in promises) {
      if (promise.fromId == fromId && promise.toId == toId && promise.isActive(now: now)) {
        return promise;
      }
    }
    return null;
  }

  /// [fromId] has paid [toId] part of what's still open between them:
  /// what payments (pending too) already took off the expenses that are
  /// left, and what's [left]. Null when nothing's paid toward them yet, or
  /// nothing's left.
  ({int paid, int left})? partlyPaid(String fromId, String toId) {
    final left = owedBetween(fromId, toId, includePending: true);
    if (left <= 0) return null;
    var paid = 0;
    for (final line in debtLines(fromId, toId, includePending: true)) {
      final full = line.fullCents;
      if (line.cents > 0 && full != null) paid += full - line.cents;
    }
    return paid > 0 ? (paid: paid, left: left) : null;
  }

  /// Whether a pending payment [s] covers only part of what its payer
  /// owes the receiver (for its trip, or the squad): [owed] before it,
  /// counting their other payments still waiting, and what's [left] after
  /// it. Null when it covers everything.
  ({int owed, int left})? partOf(Settlement s) {
    final scope = s.tripId == null ? this : forTrip(s.tripId!);
    final otherPending = scope.settlements
        .where((x) => x.isPending && x.id != s.id && x.fromId == s.fromId && x.toId == s.toId)
        .fold(0, (sum, x) => sum + x.amountCents);
    final owed = scope.owedBetween(s.fromId, s.toId) - otherPending;
    if (owed <= 0 || s.amountCents >= owed) return null;
    return (owed: owed, left: owed - s.amountCents);
  }

  RecurringExpense? recurringById(String id) {
    for (final r in recurring) {
      if (r.id == id) return r;
    }
    return null;
  }

  Trip? trip(String id) {
    for (final trip in trips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  /// [tripId]'s expenses and payments as a ledger of their own — its
  /// balances, debts and pending payments, apart from the squad's.
  SquadLedger forTrip(String tripId) => SquadLedger(
    currency: currency,
    members: members,
    expenses: [
      for (final e in tripExpenses)
        if (e.tripId == tripId) e,
    ],
    settlements: [
      for (final s in tripSettlements)
        if (s.tripId == tripId) s,
    ],
    reminders: [
      for (final r in tripReminders)
        if (r.tripId == tripId) r,
    ],
    trips: [?trip(tripId)],
    promises: [
      for (final p in tripPromises)
        if (p.tripId == tripId) p,
    ],
  );

  /// The ledger [expense] counts in: its trip's, or this one.
  SquadLedger scopeOf(Expense expense) => expense.tripId == null ? this : forTrip(expense.tripId!);

  /// Trip payments sent to [profileId], waiting for them to confirm.
  List<Settlement> tripPaymentsAwaiting(String profileId) =>
      tripSettlements.where((s) => s.isPending && s.toId == profileId).toList();

  /// Whether [fromId] already reminded [toId] today. Days are the phone's;
  /// the server checks by the squad's time zone, so near midnight it may
  /// still refuse.
  bool remindedToday(String fromId, String toId, {DateTime? now}) {
    final today = (now ?? DateTime.now()).toLocal();
    return reminders.any((r) {
      final at = r.at.toLocal();
      return r.fromId == fromId &&
          r.toId == toId &&
          at.year == today.year &&
          at.month == today.month &&
          at.day == today.day;
    });
  }

  SquadMember? member(String profileId) {
    for (final member in members) {
      if (member.profileId == profileId) return member;
    }
    return null;
  }

  String nameOf(String profileId, {String? me}) =>
      profileId == me ? 'You' : (member(profileId)?.name ?? 'Someone');

  /// "Aung", "Aung & Ko", or "Aung + 2" — biggest payer first.
  String paidByLabel(Expense expense, {String? me}) {
    final ids = (expense.payers.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .map((entry) => entry.key)
        .toList();
    return switch (ids) {
      [final only] => nameOf(only, me: me),
      [final a, final b] => '${nameOf(a, me: me)} & ${nameOf(b, me: me)}',
      [final first, ...final rest] => '${nameOf(first, me: me)} + ${rest.length}',
      [] => 'Someone',
    };
  }

  /// The squad's or a trip's.
  Expense? expense(String id) {
    for (final expense in [...expenses, ...tripExpenses]) {
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
      for (final MapEntry(:key, :value) in expense.payers.entries) {
        add(key, value);
      }
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

  /// Payments [profileId] sent that came back rejected — one per receiver,
  /// the latest, so a payment rejected twice shows once. [SentBack.resent]
  /// is the payment sent again in its place while that's still waiting
  /// for the receiver; once it's confirmed the item is gone. Rejections
  /// older than a week drop off.
  List<SentBack> sentBackTo(String profileId, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final latest = <String, Settlement>{};
    final items = <String, SentBack>{};
    // Newest first: per receiver, the latest payment, then the one before.
    for (final s in settlements.where((s) => s.fromId == profileId)) {
      final newer = latest[s.toId];
      if (newer == null) {
        latest[s.toId] = s;
        if (s.isRejected) items[s.toId] = (rejected: s, resent: null);
      } else if (newer.isPending && s.isRejected && !items.containsKey(s.toId)) {
        items[s.toId] = (rejected: s, resent: newer);
      }
    }
    return [
      for (final item in items.values)
        if (today.difference(item.rejected.respondedAt ?? item.rejected.createdAt).inDays < 7) item,
    ];
  }

  int pendingCentsFrom(String profileId, {String? to}) =>
      pendingFrom(profileId)
          .where((s) => to == null || s.toId == to)
          .fold(0, (sum, s) => sum + s.amountCents);

  /// What [fromId] owes [toId] directly, across every expense between
  /// them less confirmed payments (the unsimplified debt); 0 if nothing.
  ///
  /// [includePending]: count payments still waiting for the receiver as
  /// paid — what's left to settle once everything sent goes through.
  int owedBetween(String fromId, String toId, {bool includePending = false}) {
    for (final debt in includePending ? openDebts : rawDebts) {
      if (debt.fromId == fromId && debt.toId == toId) return debt.amountCents;
    }
    return 0;
  }

  /// The lines behind what [fromId] owes [toId]: what [fromId] owes [toId]
  /// for each expense (see [Expense.owed]), less what [toId] owes
  /// [fromId] for each. Confirmed payments between them clear the
  /// oldest expenses first; those drop off (or show what's left). Adds up
  /// to [owedBetween]. Oldest first.
  List<DebtLine> debtLines(String fromId, String toId, {bool includePending = false}) {
    // [expenses] is newest first; same day keeps that order, reversed.
    final order = {for (final (i, e) in expenses.indexed) e.id: i};
    final oldestFirst = [...expenses]
      ..sort((a, b) {
        final byDay = a.spentAt.compareTo(b.spentAt);
        return byDay != 0 ? byDay : order[b.id]!.compareTo(order[a.id]!);
      });
    final owed = [
      for (final e in oldestFirst)
        if (e.owedBy(fromId, toId) > 0) (expense: e, cents: e.owedBy(fromId, toId)),
    ];
    final owing = [
      for (final e in oldestFirst)
        if (e.owedBy(toId, fromId) > 0) (expense: e, cents: e.owedBy(toId, fromId)),
    ];
    var paid = 0;
    for (final s in settlements.where((s) => s.isConfirmed || (includePending && s.isPending))) {
      if (s.fromId == fromId && s.toId == toId) paid += s.amountCents;
      if (s.fromId == toId && s.toId == fromId) paid -= s.amountCents;
    }
    // Payments clear the oldest shares on their side; what's left shows.
    List<DebtLine> clear(List<({Expense expense, int cents})> list, int sign, int credit) {
      final lines = <DebtLine>[];
      for (final (expense: e, cents: share) in list) {
        final covered = credit < share ? credit : share;
        credit -= covered;
        if (share - covered > 0) {
          lines.add(DebtLine(cents: sign * (share - covered), expense: e, fullCents: share));
        }
      }
      // Paid back more than those shares: it counts the other way.
      if (credit > 0) lines.add(DebtLine(cents: -sign * credit));
      return lines;
    }

    return [...clear(owed, 1, paid > 0 ? paid : 0), ...clear(owing, -1, paid < 0 ? -paid : 0)];
  }

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
  List<Debt> get rawDebts => _pairwise(includePending: false);

  /// [rawDebts] counting payments still waiting for the receiver as paid —
  /// what's left to settle once everything sent goes through. What Settle
  /// shows: someone who's sent their part isn't asked for it again, nor
  /// taken off what the other owes them.
  List<Debt> get openDebts => _pairwise(includePending: true);

  /// Everything between [a] and [b], from [a]'s side: what [a] owes [b]
  /// for each expense, what [b] owes [a] for each, and every payment
  /// between them that counts (confirmed, and pending — rejected ones
  /// don't). Adds up to [owedBetween] with pending included: [total] > 0
  /// means [a] pays [b], < 0 that [b] pays [a]. Newest first.
  PairStatement statement(String a, String b) {
    final aOwes = <({Expense expense, int cents})>[];
    final bOwes = <({Expense expense, int cents})>[];
    for (final e in expenses) {
      if (e.owedBy(a, b) case final c when c > 0) aOwes.add((expense: e, cents: c));
      if (e.owedBy(b, a) case final c when c > 0) bOwes.add((expense: e, cents: c));
    }
    final payments = [
      for (final s in settlements)
        if (!s.isRejected && ((s.fromId == a && s.toId == b) || (s.fromId == b && s.toId == a))) s,
    ];
    final int total =
        aOwes.fold<int>(0, (sum, x) => sum + x.cents) -
        bOwes.fold<int>(0, (sum, x) => sum + x.cents) -
        payments.fold<int>(0, (sum, s) => sum + (s.fromId == a ? s.amountCents : -s.amountCents));
    return (aOwes: aOwes, bOwes: bOwes, payments: payments, total: total);
  }

  List<Debt> _pairwise({required bool includePending}) {
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
      for (final debt in expense.owed) {
        owe(debt.fromId, debt.toId, debt.cents, countIt: true);
      }
    }
    for (final settlement in settlements.where(
      (s) => s.isConfirmed || (includePending && s.isPending),
    )) {
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
  List<Object?> get props => [
    currency,
    members,
    expenses,
    settlements,
    reminders,
    trips,
    tripExpenses,
    tripSettlements,
    tripReminders,
    recurring,
    promises,
    tripPromises,
  ];
}
