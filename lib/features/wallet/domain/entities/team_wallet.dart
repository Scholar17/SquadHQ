import 'package:equatable/equatable.dart';

import '../../../match/domain/entities/match.dart';
import '../../../match/domain/entities/matchday_player.dart';
import 'bill_split.dart';

/// Who a match bill is split between. Values match `matches.split_mode`
/// in supabase/sql/008_match_bills_and_wallet_qr.sql.
enum SplitMode {
  /// Everyone who RSVP'd "In" — shares change as RSVPs do.
  rsvpIn,

  /// Every member of the team.
  team,

  /// A hand-picked list of players ([MatchBill.customMemberIds]).
  custom,
}

/// A teammate's payment back to the bill's payer, with the slip they
/// uploaded as proof.
class BillPayment extends Equatable {
  const BillPayment({
    required this.profileId,
    required this.slipPath,
    required this.paidAt,
  });

  final String profileId;
  final String slipPath;
  final DateTime paidAt;

  @override
  List<Object?> get props => [profileId, slipPath, paidAt];
}

/// A match's total cost, fronted by one admin ([payerId]) and split
/// between teammates by [splitMode].
class MatchBill extends Equatable {
  const MatchBill({
    required this.totalCost,
    required this.payerId,
    required this.payerName,
    required this.splitMode,
    this.payerQrPath,
    this.customMemberIds = const {},
    this.payments = const {},
    this.remindedAt = const {},
  });

  final double totalCost;

  /// Null only if the payer's profile has since been deleted.
  final String? payerId;
  final String payerName;

  /// The payer's wallet QR in the `wallet-qr` bucket, if they uploaded one.
  final String? payerQrPath;
  final SplitMode splitMode;
  final Set<String> customMemberIds;

  /// Keyed by profile id.
  final Map<String, BillPayment> payments;

  /// When each player was last sent "Remind unpaid" (once a day each),
  /// keyed by profile id.
  final Map<String, DateTime> remindedAt;

  /// Whether [profileId] was already reminded today (this device's day).
  bool remindedToday(String profileId, DateTime now) {
    final at = remindedAt[profileId]?.toLocal();
    return at != null && at.year == now.year && at.month == now.month && at.day == now.day;
  }

  @override
  List<Object?> get props => [
        totalCost,
        payerId,
        payerName,
        payerQrPath,
        splitMode,
        customMemberIds,
        payments,
        remindedAt,
      ];
}

class WalletMember extends Equatable {
  const WalletMember({required this.profileId, required this.name});

  final String profileId;
  final String name;

  @override
  List<Object?> get props => [profileId, name];
}

/// One of the team's matches as the wallet sees it — its bill (if any)
/// and everyone's RSVP, which the [SplitMode.rsvpIn] split depends on.
class WalletMatch extends Equatable {
  const WalletMatch({
    required this.match,
    this.bill,
    this.answers = const {},
  });

  final Match match;
  final MatchBill? bill;

  /// RSVP answers keyed by profile id; no entry means no reply yet.
  final Map<String, RsvpAnswer> answers;

  @override
  List<Object?> get props => [match, bill, answers];
}

/// Everything the Wallet tab (and the Match tab's bill card) shows for one
/// team: its members, plus its recent and upcoming matches with any bills.
class TeamWallet extends Equatable {
  const TeamWallet({this.members = const [], this.matches = const []});

  static const empty = TeamWallet();

  final List<WalletMember> members;

  /// Newest kick-off first.
  final List<WalletMatch> matches;

  WalletMatch? forMatch(String matchId) {
    for (final walletMatch in matches) {
      if (walletMatch.match.id == matchId) return walletMatch;
    }
    return null;
  }

  BillSplit? splitFor(WalletMatch walletMatch) {
    final bill = walletMatch.bill;
    if (bill == null) return null;
    return BillSplit.compute(bill: bill, members: members, answers: walletMatch.answers);
  }

  /// Every match that has a bill, newest first, with its split.
  List<(WalletMatch, BillSplit)> get bills => [
        for (final walletMatch in matches)
          if (splitFor(walletMatch) case final split?) (walletMatch, split),
      ];

  /// Still owed to payers across every bill — the team balance.
  int get outstanding => bills.fold(0, (sum, bill) => sum + bill.$2.outstanding);

  /// Already paid back to payers across every bill.
  int get collected => bills.fold(0, (sum, bill) => sum + bill.$2.collected);

  double get billedTotal => bills.fold(0, (sum, bill) => sum + bill.$2.bill.totalCost);

  int get unpaidCount => bills.fold(0, (sum, bill) => sum + bill.$2.unpaid.length);

  /// What payers covered themselves across every bill (their own shares,
  /// plus any rounding) — so paid back + still owed + this = [billedTotal].
  double get payersCovered => bills.fold(0, (sum, bill) => sum + bill.$2.payerCovers);

  /// Bills [profileId] shares in but hasn't paid back yet.
  List<(WalletMatch, BillSplit)> owedBy(String profileId) => [
        for (final bill in bills)
          if (bill.$2.shareFor(profileId) case final share? when !share.isSettled) bill,
      ];

  @override
  List<Object?> get props => [members, matches];
}
