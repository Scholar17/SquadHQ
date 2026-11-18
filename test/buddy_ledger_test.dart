import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/features/buddy/domain/entities/buddy.dart';
import 'package:squad_hq/features/squad/domain/entities/expense.dart';
import 'package:squad_hq/features/squad/domain/entities/settlement.dart';

BuddyExpense shared(String id, {required String buddy, required String payer, required int mine, required int theirs}) =>
    BuddyExpense(
      id: id,
      buddyId: buddy,
      payerId: payer,
      title: id,
      category: ExpenseCategory.food,
      amountCents: mine + theirs,
      splitMode: ExpenseSplitMode.custom,
      myShareCents: mine,
      buddyShareCents: theirs,
      spentAt: DateTime(2026, 11, 18),
      createdBy: 'me',
      updatedAt: DateTime(2026, 11, 18),
    );

BuddySettlement paid(String from, String to, int cents, SettlementStatus status) => BuddySettlement(
  id: '$from-$to-$cents',
  fromId: from,
  toId: to,
  amountCents: cents,
  method: SettlementMethod.cash,
  status: status,
  recordedBy: from,
  createdAt: DateTime(2026, 11, 18),
);

void main() {
  test('You paid: they owe their share. They paid: you owe yours', () {
    final ledger = BuddyLedger(
      me: 'me',
      expenses: [
        shared('dinner', buddy: 'ko', payer: 'me', mine: 15000, theirs: 15000),
        shared('taxi', buddy: 'ko', payer: 'ko', mine: 4000, theirs: 4000),
        shared('other', buddy: 'su', payer: 'su', mine: 10000, theirs: 0),
      ],
      settlements: const [],
    );
    expect(ledger.balanceWith('ko'), 11000);
    expect(ledger.balanceWith('su'), -10000);
    expect(ledger.buddies, ['ko', 'su']);
  });

  test('Only confirmed payments count; pending ones wait to confirm', () {
    final ledger = BuddyLedger(
      me: 'me',
      expenses: [shared('dinner', buddy: 'ko', payer: 'me', mine: 15000, theirs: 15000)],
      settlements: [
        paid('ko', 'me', 5000, SettlementStatus.confirmed),
        paid('ko', 'me', 10000, SettlementStatus.pending),
        paid('ko', 'me', 999, SettlementStatus.rejected),
      ],
    );
    expect(ledger.balanceWith('ko'), 10000);
    expect(ledger.awaitingMeFrom('ko').single.amountCents, 10000);
  });

  test('Paying them back what you owe brings it to square', () {
    final ledger = BuddyLedger(
      me: 'me',
      expenses: [shared('boots', buddy: 'su', payer: 'su', mine: 20000, theirs: 0)],
      settlements: [paid('me', 'su', 20000, SettlementStatus.confirmed)],
    );
    expect(ledger.balanceWith('su'), 0);
  });
}
