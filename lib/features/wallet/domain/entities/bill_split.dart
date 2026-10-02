import 'package:equatable/equatable.dart';

import '../../../match/domain/entities/matchday_player.dart';
import 'team_wallet.dart';

/// One player's part of a bill.
class BillShare extends Equatable {
  const BillShare({required this.member, required this.isPayer, this.payment});

  final WalletMember member;

  /// The payer fronted the whole bill, so their own share is already settled.
  final bool isPayer;
  final BillPayment? payment;

  bool get isSettled => isPayer || payment != null;

  @override
  List<Object?> get props => [member, isPayer, payment];
}

/// A bill divided evenly between the players its [SplitMode] picks.
/// Amounts are worked out in satang so e.g. ฿1,000 ÷ 3 is exactly ฿333.33,
/// never a float like 333.3299999.
class BillSplit extends Equatable {
  const BillSplit._({
    required this.bill,
    required this.shares,
    required this.exactShare,
    required this.roundedShare,
  });

  factory BillSplit.compute({
    required MatchBill bill,
    required List<WalletMember> members,
    required Map<String, RsvpAnswer> answers,
  }) {
    final participants = switch (bill.splitMode) {
      SplitMode.rsvpIn =>
        members.where((member) => answers[member.profileId] == RsvpAnswer.yes),
      SplitMode.team => members,
      SplitMode.custom =>
        members.where((member) => bill.customMemberIds.contains(member.profileId)),
    };
    final shares = [
      for (final member in participants)
        BillShare(
          member: member,
          isPayer: member.profileId == bill.payerId,
          payment: bill.payments[member.profileId],
        ),
    ];
    final totalSatang = (bill.totalCost * 100).round();
    final count = shares.length;
    return BillSplit._(
      bill: bill,
      shares: shares,
      exactShare: count == 0 ? 0 : (totalSatang / count).round() / 100,
      // Ceiling division, whole baht: each player rounds up.
      roundedShare: count == 0 ? 0 : (totalSatang + count * 100 - 1) ~/ (count * 100),
    );
  }

  final MatchBill bill;
  final List<BillShare> shares;

  /// Each player's share to the satang, e.g. 333.33.
  final double exactShare;

  /// Each player's share rounded up to whole baht, e.g. 334 — what players
  /// actually pay.
  final int roundedShare;

  List<BillShare> get unpaid => shares.where((share) => !share.isSettled).toList();

  List<BillShare> get paid =>
      shares.where((share) => !share.isPayer && share.payment != null).toList();

  /// Still owed back to the payer, in whole baht.
  int get outstanding => unpaid.length * roundedShare;

  /// Already paid back to the payer, in whole baht.
  int get collected => paid.length * roundedShare;

  /// Everyone but the payer — the shares that get paid back.
  int get owingShares => shares.where((share) => !share.isPayer).length;

  /// The part of the total the payer covers themselves: their own share
  /// plus any rounding (e.g. ฿1,000 ÷ 3 → others pay ฿334 each, the payer
  /// covers ฿332). So [collected] + [outstanding] + this = the total.
  double get payerCovers => bill.totalCost - roundedShare * owingShares;

  BillShare? shareFor(String profileId) {
    for (final share in shares) {
      if (share.member.profileId == profileId) return share;
    }
    return null;
  }

  @override
  List<Object?> get props => [bill, shares, exactShare, roundedShare];
}
