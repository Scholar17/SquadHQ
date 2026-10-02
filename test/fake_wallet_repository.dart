import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/wallet/domain/entities/team_wallet.dart';
import 'package:squad_hq/features/wallet/domain/repositories/wallet_repository.dart';

import 'fake_match_repository.dart';

/// In-memory [WalletRepository] over [FakeMatchRepository]'s matches,
/// squad and RSVPs. Bills are keyed by match id; call [reset] between
/// tests.
class FakeWalletRepository implements WalletRepository {
  FakeWalletRepository(this._matches);

  final FakeMatchRepository _matches;

  final bills = <String, MatchBill>{};
  String? myQrPath;

  String get _userId => _matches.userId;

  void reset() {
    reminded.clear();
    bills.clear();
    myQrPath = null;
  }

  String _nameOf(String profileId) =>
      _matches.squad.firstWhere((player) => player.profileId == profileId).name;

  @override
  Future<Either<Failure, TeamWallet>> getTeamWallet(String teamId) async => Right(
        TeamWallet(
          members: [
            for (final player in _matches.squad)
              WalletMember(profileId: player.profileId, name: player.name),
          ],
          matches: [
            for (final match in [..._matches.matches, ..._matches.pastMatches])
              WalletMatch(
                match: match,
                bill: bills[match.id],
                answers: _matches.answersFor(match.id),
              ),
          ],
        ),
      );

  @override
  Future<Either<Failure, Unit>> setMatchBill({
    required String matchId,
    required double totalCost,
    required SplitMode splitMode,
    required Set<String> memberIds,
  }) async {
    final existing = bills[matchId];
    if (existing != null && existing.payerId != _userId) {
      return const Left(ServerFailure('Only the admin who paid this bill can change it'));
    }
    bills[matchId] = MatchBill(
      totalCost: totalCost,
      payerId: _userId,
      payerName: _nameOf(_userId),
      payerQrPath: myQrPath,
      splitMode: splitMode,
      customMemberIds: memberIds,
      payments: existing?.payments ?? const {},
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> submitPayment({
    required String matchId,
    required Uint8List slipBytes,
    required String fileExtension,
  }) async {
    final bill = bills[matchId]!;
    bills[matchId] = MatchBill(
      totalCost: bill.totalCost,
      payerId: bill.payerId,
      payerName: bill.payerName,
      payerQrPath: bill.payerQrPath,
      splitMode: bill.splitMode,
      customMemberIds: bill.customMemberIds,
      payments: {
        ...bill.payments,
        _userId: BillPayment(
          profileId: _userId,
          slipPath: '$matchId/$_userId/slip.$fileExtension',
          paidAt: DateTime(2026, 10, 4),
        ),
      },
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, String?>> getMyWalletQr() async => Right(myQrPath);

  @override
  Future<Either<Failure, String>> uploadWalletQr({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    myQrPath = '$_userId/qr.$fileExtension';
    return Right(myQrPath!);
  }

  @override
  Future<Either<Failure, String>> getImageUrl(WalletImageKind kind, String path) async =>
      Right('https://storage.test/$path');

  @override
  Future<Either<Failure, Uint8List>> downloadImage(WalletImageKind kind, String path) async =>
      Right(Uint8List(0));

  /// Each "Remind unpaid": the match, and who (null = everyone unpaid).
  final reminded = <(String, Set<String>?)>[];

  @override
  Future<Either<Failure, Unit>> remindUnpaid(String matchId, {Set<String>? profileIds}) async {
    reminded.add((matchId, profileIds));
    final bill = bills[matchId]!;
    final wallet = (await getTeamWallet(_matches.teamId)).getOrElse(() => TeamWallet.empty);
    final split = wallet.splitFor(wallet.forMatch(matchId)!)!;
    final now = DateTime.now();
    bills[matchId] = MatchBill(
      totalCost: bill.totalCost,
      payerId: bill.payerId,
      payerName: bill.payerName,
      payerQrPath: bill.payerQrPath,
      splitMode: bill.splitMode,
      customMemberIds: bill.customMemberIds,
      payments: bill.payments,
      remindedAt: {
        ...bill.remindedAt,
        for (final share in split.unpaid)
          if (profileIds == null || profileIds.contains(share.member.profileId))
            share.member.profileId: now,
      },
    );
    return const Right(unit);
  }
}
