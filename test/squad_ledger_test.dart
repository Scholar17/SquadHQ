import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/features/squad/domain/entities/expense.dart';
import 'package:squad_hq/features/squad/domain/entities/expense_split.dart';
import 'package:squad_hq/features/squad/domain/entities/recurring_expense.dart';
import 'package:squad_hq/features/squad/domain/entities/settlement.dart';
import 'package:squad_hq/features/squad/domain/entities/squad_ledger.dart';
import 'package:squad_hq/features/squad/domain/entities/squad_member.dart';
import 'package:squad_hq/features/team_membership/domain/entities/team.dart';

void main() {
  group('ExpenseSplit', () {
    test('฿1,000 equally between 3: friends pay ฿334 (exact ฿333.33), the payer covers ฿332', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.equal,
        totalCents: 100000,
        payerId: 'aung',
        participants: ['aung', 'ko', 'min'],
      );
      expect(split.isValid, isTrue);
      expect(split.shares, {'aung': 33200, 'ko': 33400, 'min': 33400});
      expect(split.exactCents, 33333);
      expect(split.roundedCents, 33400);
    });

    test('฿1,150 ÷ 4 → ฿288 each over exact ฿287.50; the payer covers ฿286', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.equal,
        totalCents: 115000,
        payerId: 'a',
        participants: ['a', 'b', 'c', 'd'],
      );
      expect(split.shares['a'], 28600);
      expect(split.shares['b'], 28800);
      expect(split.exactCents, 28750);
    });

    test('Borrow: whoever didn’t pay owes all of it', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.borrow,
        totalCents: 50000,
        payerId: 'me',
        participants: ['me', 'ko'],
      );
      expect(split.isValid, isTrue);
      expect(split.shares, {'ko': 50000});
      final alone = ExpenseSplit.compute(
        mode: ExpenseSplitMode.borrow,
        totalCents: 50000,
        payerId: 'me',
        participants: ['me'],
      );
      expect(alone.isValid, isFalse);
    });

    test('A payer outside the split only fronted it: split to the satang', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.chosen,
        totalCents: 100000,
        payerId: 'aung',
        participants: ['ko', 'min', 'su'],
      );
      expect(split.shares, {'ko': 33334, 'min': 33333, 'su': 33333});
      expect(split.shares.values.reduce((a, b) => a + b), 100000);
      expect(split.roundedCents, isNull);
    });

    test('Percent: 50 · 30 · 20 of ฿1,000', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.percent,
        totalCents: 100000,
        payerId: 'a',
        participants: const [],
        weights: {'a': 5000, 'b': 3000, 'c': 2000},
      );
      expect(split.isValid, isTrue);
      expect(split.shares, {'a': 50000, 'b': 30000, 'c': 20000});
    });

    test('Percent must add up to 100', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.percent,
        totalCents: 100000,
        payerId: 'a',
        participants: const [],
        weights: {'a': 5000, 'b': 2500},
      );
      expect(split.isValid, isFalse);
      expect(split.error, 'Percents add up to 75%, not 100%');
    });

    test('Percent rounding still adds up: ฿100 at 33.34 · 33.33 · 33.33', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.percent,
        totalCents: 10000,
        payerId: 'a',
        participants: const [],
        weights: {'a': 3334, 'b': 3333, 'c': 3333},
      );
      expect(split.shares.values.reduce((a, b) => a + b), 10000);
      expect(split.shares, {'a': 3334, 'b': 3333, 'c': 3333});
    });

    test('Shares: 2 · 1 · 1 of ฿1,000 → ฿500 · ฿250 · ฿250; 0 shares is out', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.shares,
        totalCents: 100000,
        payerId: 'a',
        participants: const [],
        weights: {'a': 200, 'b': 100, 'c': 100, 'd': 0},
      );
      expect(split.isValid, isTrue);
      expect(split.shares, {'a': 50000, 'b': 25000, 'c': 25000});
    });

    test('Shares that don\'t divide evenly: leftover satang go to the biggest remainders', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.shares,
        totalCents: 100000,
        payerId: 'a',
        participants: const [],
        weights: {'a': 100, 'b': 100, 'c': 100},
      );
      expect(split.shares, {'a': 33334, 'b': 33333, 'c': 33333});
    });

    test('Shares with nobody in it', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.shares,
        totalCents: 100000,
        payerId: 'a',
        participants: const [],
      );
      expect(split.isValid, isFalse);
    });

    test('Custom: only the ticked people, each with a typed amount', () {
      ExpenseSplit custom(List<String> ticked) => ExpenseSplit.compute(
        mode: ExpenseSplitMode.custom,
        totalCents: 100000,
        payerId: 'a',
        participants: ticked,
        // c's amount was typed, then c unticked: it doesn't count.
        exactCents: {'a': 60000, 'b': 40000, 'c': 25000},
      );
      expect(custom(['a', 'b']).shares, {'a': 60000, 'b': 40000});
      expect(custom(['a', 'b']).isValid, isTrue);
      expect(custom(['a', 'b', 'c']).isValid, isFalse);
      expect(custom([]).error, 'Pick who shares it');
    });

    test('Exact shares must add up to the amount', () {
      final short = ExpenseSplit.compute(
        mode: ExpenseSplitMode.exact,
        totalCents: 120000,
        payerId: 'a',
        participants: const [],
        exactCents: {'a': 50000, 'b': 40000},
      );
      expect(short.isValid, isFalse);

      final ok = ExpenseSplit.compute(
        mode: ExpenseSplitMode.exact,
        totalCents: 120000,
        payerId: 'a',
        participants: const [],
        exactCents: {'a': 50000, 'b': 40000, 'c': 30000},
      );
      expect(ok.isValid, isTrue);
    });

    test('A treat is all on the payer — nobody owes anything', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.treat,
        totalCents: 90000,
        payerId: 'aung',
        participants: ['aung', 'ko'],
      );
      expect(split.shares, {'aung': 90000});
    });

    test('Nobody picked, or no amount, is not valid', () {
      expect(
        ExpenseSplit.compute(
          mode: ExpenseSplitMode.chosen,
          totalCents: 1000,
          payerId: 'a',
          participants: const [],
        ).isValid,
        isFalse,
      );
      expect(
        ExpenseSplit.compute(
          mode: ExpenseSplitMode.equal,
          totalCents: 0,
          payerId: 'a',
          participants: ['a'],
        ).isValid,
        isFalse,
      );
    });
  });

  group('RecurringExpense', () {
    RecurringExpense plan({int day = 15, DateTime? lastMonth, DateTime? pausedAt}) =>
        RecurringExpense(
          id: 'yt',
          title: 'YouTube Family',
          category: ExpenseCategory.other,
          amountCents: 42000,
          payerId: 'a',
          splitMode: ExpenseSplitMode.equal,
          shares: const {'a': 14000, 'b': 14000, 'c': 14000},
          chargeDay: day,
          startsOn: DateTime(2026, 10),
          createdBy: 'a',
          lastMonth: lastMonth,
          pausedAt: pausedAt,
        );

    test('"Last day" fits each month', () {
      final lastDay = plan(day: RecurringExpense.lastDay);
      expect(lastDay.chargeDateIn(DateTime(2027, 2)), DateTime(2027, 2, 28));
      expect(lastDay.chargeDateIn(DateTime(2028, 2)), DateTime(2028, 2, 29));
      expect(lastDay.chargeDateIn(DateTime(2026, 10)), DateTime(2026, 10, 31));
    });

    test('Next charge: this month until charged, then next; none while paused', () {
      expect(plan().nextCharge(DateTime(2026, 10, 4)), DateTime(2026, 10, 15));
      expect(
        plan(lastMonth: DateTime(2026, 10)).nextCharge(DateTime(2026, 10, 20)),
        DateTime(2026, 11, 15),
      );
      // Not before its first month.
      expect(plan().nextCharge(DateTime(2026, 9, 1)), DateTime(2026, 10, 15));
      expect(plan(pausedAt: DateTime(2026, 10, 2)).nextCharge(DateTime(2026, 10, 4)), isNull);
    });
  });

  group('SquadLedger', () {
    SquadMember member(String id) => SquadMember(profileId: id, name: id, role: TeamRole.player);

    Expense expense(String id, String payer, Map<String, int> shares) => Expense(
      id: id,
      title: id,
      category: ExpenseCategory.food,
      amountCents: shares.values.reduce((a, b) => a + b),
      spentAt: DateTime(2026, 9, 27),
      splitMode: ExpenseSplitMode.exact,
      payerId: payer,
      shares: shares,
      createdBy: payer,
    );

    Settlement settlement(String from, String to, int cents, SettlementStatus status) => Settlement(
      id: '$from-$to-$cents',
      fromId: from,
      toId: to,
      amountCents: cents,
      method: SettlementMethod.cash,
      status: status,
      createdAt: DateTime(2026, 9, 28),
    );

    test('Simplify debts turns A→B ฿100 + B→C ฿100 into A→C ฿100', () {
      final ledger = SquadLedger(
        currency: GroupCurrency.thb,
        members: [member('a'), member('b'), member('c')],
        expenses: [
          expense('b paid for a', 'b', {'a': 10000}),
          expense('c paid for b', 'c', {'b': 10000}),
        ],
      );
      expect(ledger.balances, {'a': -10000, 'b': 0, 'c': 10000});
      expect(ledger.simplifiedDebts, [const Debt(fromId: 'a', toId: 'c', amountCents: 10000)]);
      expect(ledger.rawDebts, hasLength(2));
    });

    test('Several payers: each person short owes each payer in proportion', () {
      // ฿1,000 dinner: Aung paid ฿600, Ko ฿400; four people, ฿250 each.
      final dinner = Expense(
        id: 'dinner',
        title: 'dinner',
        category: ExpenseCategory.food,
        amountCents: 100000,
        spentAt: DateTime(2026, 9, 27),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'aung',
        payers: const {'aung': 60000, 'ko': 40000},
        shares: const {'aung': 25000, 'ko': 25000, 'min': 25000, 'su': 25000},
        createdBy: 'aung',
      );
      // Aung is ฿350 over, Ko ฿150: a ฿250 share is 70% / 30%.
      expect(dinner.owed, [
        (fromId: 'min', toId: 'aung', cents: 17500),
        (fromId: 'min', toId: 'ko', cents: 7500),
        (fromId: 'su', toId: 'aung', cents: 17500),
        (fromId: 'su', toId: 'ko', cents: 7500),
      ]);
      expect(dinner.netFor('ko'), 15000);
      expect(dinner.canEdit('ko', isAdmin: false), isTrue);

      final ledger = SquadLedger(
        currency: GroupCurrency.thb,
        members: [member('aung'), member('ko'), member('min'), member('su')],
        expenses: [dinner],
      );
      expect(ledger.balances, {'aung': 35000, 'ko': 15000, 'min': -25000, 'su': -25000});
      expect(ledger.owedBetween('min', 'ko'), 7500);
      expect(ledger.debtLines('min', 'aung').single.cents, 17500);
      expect(ledger.paidByLabel(dinner), 'aung & ko');
    });

    test('Several payers: odd amounts still add up exactly', () {
      final odd = Expense(
        id: 'odd',
        title: 'odd',
        category: ExpenseCategory.food,
        amountCents: 100001,
        spentAt: DateTime(2026, 9, 27),
        splitMode: ExpenseSplitMode.exact,
        payerId: 'a',
        payers: const {'a': 33334, 'b': 33333, 'c': 33334},
        shares: const {'d': 33333, 'e': 33333, 'f': 33335},
        createdBy: 'a',
      );
      final owed = odd.owed;
      for (final id in ['d', 'e', 'f']) {
        final paid = owed.where((x) => x.fromId == id).fold(0, (sum, x) => sum + x.cents);
        expect(paid, odd.shareOf(id));
      }
      for (final id in ['a', 'b', 'c']) {
        final got = owed.where((x) => x.toId == id).fold(0, (sum, x) => sum + x.cents);
        expect(got, odd.paidBy(id));
      }
    });

    test('A treat with several payers: nobody owes anything', () {
      final split = ExpenseSplit.compute(
        mode: ExpenseSplitMode.treat,
        totalCents: 100000,
        payerId: 'a',
        participants: const [],
        payers: const {'a': 70000, 'b': 30000},
      );
      expect(split.shares, {'a': 70000, 'b': 30000});
    });

    test('Every expense behind a debt shows, oldest cleared first by payments', () {
      // Newest first, like the ledger.
      final ledger = SquadLedger(
        currency: GroupCurrency.thb,
        members: [member('me'), member('aung')],
        expenses: [
          expense('taxi', 'aung', {'me': 10000, 'aung': 10000}),
          expense('hotel', 'me', {'me': 20000, 'aung': 20000}),
          expense('drinks', 'aung', {'me': 15000, 'aung': 15000}),
          expense('dinner', 'aung', {'me': 30000, 'aung': 30000}),
        ],
        settlements: [settlement('me', 'aung', 10000, SettlementStatus.confirmed)],
      );
      final lines = ledger.debtLines('me', 'aung');
      // ฿300 + ฿150 + ฿100 − ฿200 (hotel) − ฿100 paid = ฿250.
      expect(ledger.owedBetween('me', 'aung'), 25000);
      expect(lines.fold(0, (sum, line) => sum + line.cents), 25000);
      // Every expense shows; the payment covered part of the oldest.
      expect(
        [for (final line in lines) (line.expense?.id, line.cents)],
        [('dinner', 20000), ('drinks', 15000), ('taxi', 10000), ('hotel', -20000)],
      );
      expect(lines.first.isPartlyPaid, isTrue);
      expect(lines[1].isPartlyPaid, isFalse);
    });

    test('Two expenses to one person: one payment for all marks both paid', () {
      final lunch = expense('lunch', 'aung', {'me': 10000, 'aung': 10000});
      final dinner = expense('dinner', 'aung', {'me': 20000, 'aung': 20000});
      SquadLedger paying(List<Settlement> settlements) => SquadLedger(
        currency: GroupCurrency.thb,
        members: [member('me'), member('aung')],
        expenses: [dinner, lunch],
        settlements: settlements,
      );

      final unpaid = paying(const []);
      expect(unpaid.expenseLeft(lunch, 'me', 'aung'), 10000);
      expect(unpaid.expenseLeft(dinner, 'me', 'aung'), 20000);
      expect(unpaid.openExpenseCount('me', 'aung'), 2);

      // Everything at once, as Settle pays it.
      final all = paying([settlement('me', 'aung', 30000, SettlementStatus.confirmed)]);
      expect(all.expenseLeft(lunch, 'me', 'aung'), 0);
      expect(all.expenseLeft(dinner, 'me', 'aung'), 0);

      // Just one share, still waiting: it covers the first, not the other.
      final one = paying([settlement('me', 'aung', 10000, SettlementStatus.pending)]);
      expect(one.expenseLeft(lunch, 'me', 'aung'), 10000);
      expect(one.expenseLeft(lunch, 'me', 'aung', includePending: true), 0);
      expect(one.expenseLeft(dinner, 'me', 'aung', includePending: true), 20000);
      expect(one.openExpenseCount('me', 'aung'), 1);
    });

    test('What the other person owes back takes off an expense still open', () {
      final dinner = expense('dinner', 'aung', {'me': 20000, 'aung': 20000});
      final ledger = SquadLedger(
        currency: GroupCurrency.thb,
        members: [member('me'), member('aung')],
        expenses: [expense('taxi', 'me', {'me': 5000, 'aung': 5000}), dinner],
      );
      expect(ledger.expenseLeft(dinner, 'me', 'aung'), 15000);
    });

    test('A payment changes balances only once the receiver confirms it', () {
      final expenses = [
        expense('dinner', 'aung', {'aung': 30000, 'toe': 30000}),
      ];
      SquadLedger withStatus(SettlementStatus status) => SquadLedger(
        currency: GroupCurrency.thb,
        members: [member('aung'), member('toe')],
        expenses: expenses,
        settlements: [settlement('toe', 'aung', 30000, status)],
      );

      final pending = withStatus(SettlementStatus.pending);
      expect(pending.balanceOf('toe'), -30000);
      expect(pending.pendingCentsFrom('toe'), 30000);
      expect(pending.awaitingConfirmationBy('aung'), hasLength(1));

      expect(withStatus(SettlementStatus.rejected).balanceOf('toe'), -30000);

      final confirmed = withStatus(SettlementStatus.confirmed);
      expect(confirmed.balanceOf('toe'), 0);
      expect(confirmed.balanceOf('aung'), 0);
      expect(confirmed.simplifiedDebts, isEmpty);
      expect(confirmed.rawDebts, isEmpty);
    });

    test('Send again shows once per receiver, and not after sending again', () {
      final now = DateTime(2026, 9, 29);
      Settlement attempt(int n, SettlementStatus status, {String to = 'aung'}) => Settlement(
        id: 'try-$n-$to',
        fromId: 'toe',
        toId: to,
        amountCents: 30000,
        method: SettlementMethod.qr,
        status: status,
        createdAt: DateTime(2026, 9, 28, n),
        slipPath: 'slip-$n',
      );
      SquadLedger ledger(List<Settlement> newestFirst) => SquadLedger(
        currency: GroupCurrency.thb,
        members: [member('aung'), member('toe'), member('min')],
        settlements: newestFirst,
      );

      final rejectedOnce = ledger([attempt(1, SettlementStatus.rejected)]);
      expect(rejectedOnce.sentBackTo('toe', now: now).map((s) => s.rejected.id), ['try-1-aung']);

      // Sent again: the same item, now waiting on Aung — nothing to send.
      final resent = ledger([
        attempt(2, SettlementStatus.pending),
        attempt(1, SettlementStatus.rejected),
      ]);
      final resentItem = resent.sentBackTo('toe', now: now).single;
      expect(resentItem.rejected.id, 'try-1-aung');
      expect(resentItem.resent?.id, 'try-2-aung');
      expect(resent.awaitingConfirmationBy('aung').map((s) => s.slipPath), ['slip-2']);

      // Rejected again: still one item, the latest.
      final rejectedTwice = ledger([
        attempt(2, SettlementStatus.rejected),
        attempt(1, SettlementStatus.rejected),
        attempt(3, SettlementStatus.rejected, to: 'min'),
      ]);
      expect(rejectedTwice.sentBackTo('toe', now: now).map((s) => (s.rejected.id, s.resent)), [
        ('try-2-aung', null),
        ('try-3-min', null),
      ]);
      expect(rejectedTwice.sentBackTo('aung', now: now), isEmpty);

      final confirmed = ledger([
        attempt(3, SettlementStatus.confirmed),
        attempt(2, SettlementStatus.rejected),
      ]);
      expect(confirmed.sentBackTo('toe', now: now), isEmpty);
    });

    test('Balances always sum to zero', () {
      final ledger = SquadLedger(
        currency: GroupCurrency.thb,
        members: [member('a'), member('b'), member('c'), member('d')],
        expenses: [
          expense('1', 'a', {'a': 28600, 'b': 28800, 'c': 28800, 'd': 28800}),
          expense('2', 'c', {'b': 15000, 'd': 9000}),
        ],
        settlements: [settlement('b', 'a', 20000, SettlementStatus.confirmed)],
      );
      expect(ledger.balances.values.reduce((x, y) => x + y), 0);
      final simplified = ledger.simplifiedDebts;
      expect(simplified.length, lessThanOrEqualTo(3));
      // Paying the suggestions zeroes everyone out.
      final after = Map.of(ledger.balances);
      for (final debt in simplified) {
        after[debt.fromId] = after[debt.fromId]! + debt.amountCents;
        after[debt.toId] = after[debt.toId]! - debt.amountCents;
      }
      expect(after.values.every((cents) => cents == 0), isTrue);
    });
  });
}
