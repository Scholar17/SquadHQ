import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/share_link.dart';

abstract interface class ShareRepository {
  /// The link to share [matchId] (or its bill) — the same one each time.
  Future<Either<Failure, String>> getShareLink(String matchId, ShareKind kind);

  /// Tells the team [matchId] (or its bill) was shared — a push they can
  /// tap to open it in the app. At most once a day per sharer (055).
  Future<Either<Failure, Unit>> recordShare(String matchId, ShareKind kind);

  /// What [token]'s link opens, or null if it's not for one of your teams
  /// (or its match was deleted).
  Future<Either<Failure, OpenedShare?>> openShareLink(String token);
}
