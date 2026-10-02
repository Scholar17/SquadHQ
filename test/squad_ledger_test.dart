import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/features/squad/domain/entities/expense.dart';
import 'package:squad_hq/features/squad/domain/entities/expense_split.dart';
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
