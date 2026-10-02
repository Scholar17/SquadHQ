import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/features/match/domain/entities/matchday_player.dart';
import 'package:squad_hq/features/wallet/domain/entities/bill_split.dart';
import 'package:squad_hq/features/wallet/domain/entities/team_wallet.dart';
import 'package:squad_hq/features/wallet/presentation/wallet_formatting.dart';

void main() {
  const members = [
    WalletMember(profileId: 'admin', name: 'Aung Ko'),
    WalletMember(profileId: 'p-2', name: 'Min Thu'),
    WalletMember(profileId: 'p-3', name: 'Test Player'),
    WalletMember(profileId: 'p-4', name: 'Zaw Win'),
  ];

  MatchBill bill(SplitMode mode, {double total = 1000, Set<String> custom = const {}}) =>
      MatchBill(
        totalCost: total,
        payerId: 'admin',
        payerName: 'Aung Ko',
        splitMode: mode,
        customMemberIds: custom,
        payments: {
          'p-2': BillPayment(profileId: 'p-2', slipPath: 'x', paidAt: DateTime(2026)),
        },
      );

  test('Players who said In splits only between yes RSVPs', () {
    final split = BillSplit.compute(
      bill: bill(SplitMode.rsvpIn),
      members: members,
      answers: const {
        'admin': RsvpAnswer.yes,
        'p-2': RsvpAnswer.yes,
        'p-3': RsvpAnswer.yes,
        'p-4': RsvpAnswer.maybe,
      },
    );

    expect(split.shares.map((share) => share.member.profileId), ['admin', 'p-2', 'p-3']);
    // ฿1,000 ÷ 3: exact ฿333.33, everyone pays ฿334 rounded up.
    expect(split.exactShare, 333.33);
    expect(split.roundedShare, 334);
    // The payer's own share is settled; p-2 has paid; only p-3 still owes.
    expect(split.unpaid.map((share) => share.member.profileId), ['p-3']);
    expect(split.outstanding, 334);
    expect(split.collected, 334);
  });

  test('Whole team splits between every member', () {
    final split = BillSplit.compute(
      bill: bill(SplitMode.team, total: 1200),
      members: members,
      answers: const {},
    );

    expect(split.shares, hasLength(4));
    expect(split.exactShare, 300);
    expect(split.roundedShare, 300);
    expect(split.outstanding, 600);
  });

  test('Picked players splits only between the custom list', () {
    final split = BillSplit.compute(
      bill: bill(SplitMode.custom, total: 250.5, custom: {'p-3', 'p-4'}),
      members: members,
      answers: const {},
    );

    expect(split.shares.map((share) => share.member.profileId), ['p-3', 'p-4']);
    expect(split.exactShare, 125.25);
    expect(split.roundedShare, 126);
  });

  test('An In split with no RSVPs yet has no shares and owes nothing', () {
    final split = BillSplit.compute(
      bill: bill(SplitMode.rsvpIn),
      members: members,
      answers: const {},
    );

    expect(split.shares, isEmpty);
    expect(split.roundedShare, 0);
    expect(split.outstanding, 0);
  });

  test('Baht formatting shows whole and exact amounts', () {
    expect(formatBaht(1250), '฿1,250');
    expect(formatBahtExact(1000 / 3), '฿333.33');
    expect(formatBahtExact(12500), '฿12,500.00');
  });
}
