import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/team_wallet.dart';

/// Which private storage bucket an image lives in — see
/// supabase/sql/008_match_bills_and_wallet_qr.sql.
enum WalletImageKind { walletQr, paymentSlip }

abstract interface class WalletRepository {
  /// [teamId]'s members plus its recent and upcoming matches, with bills,
  /// payments and RSVPs.
  Future<Either<Failure, TeamWallet>> getTeamWallet(String teamId);

  /// Records the caller as having paid [matchId]'s [totalCost]. Fails
  /// unless the caller is a team admin, and — once a bill exists — unless
  /// they're the one who paid it (see `set_match_bill`).
  Future<Either<Failure, Unit>> setMatchBill({
    required String matchId,
    required double totalCost,
    required SplitMode splitMode,
    required Set<String> memberIds,
  });

  /// Uploads a payment slip screenshot and marks the caller's share of
  /// [matchId]'s bill as paid (see `submit_match_payment`).
  Future<Either<Failure, Unit>> submitPayment({
    required String matchId,
    required Uint8List slipBytes,
    required String fileExtension,
  });

  /// The signed-in profile's wallet QR path, or null if they haven't
  /// uploaded one.
  Future<Either<Failure, String?>> getMyWalletQr();

  /// Replaces the signed-in profile's wallet QR; returns its new path.
  Future<Either<Failure, String>> uploadWalletQr({
    required Uint8List bytes,
    required String fileExtension,
  });

  /// A short-lived URL for showing a private image.
  Future<Either<Failure, String>> getImageUrl(WalletImageKind kind, String path);

  Future<Either<Failure, Uint8List>> downloadImage(WalletImageKind kind, String path);

  /// "Remind unpaid": pushes [profileIds] — or, if null, everyone who
  /// still owes on [matchId]'s bill. The payer or a team admin only, once
  /// per day per player (see `remind_bill_payment` in
  /// supabase/sql/017_pick_unpaid_reminders.sql).
  Future<Either<Failure, Unit>> remindUnpaid(String matchId, {Set<String>? profileIds});
}
