import 'package:dartz/dartz.dart';
import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/share/domain/entities/share_link.dart';
import 'package:squad_hq/features/share/domain/repositories/share_repository.dart';

/// One token per match and kind, like 054's share_link; opens only what
/// was shared from this fake.
class FakeShareRepository implements ShareRepository {
  final Map<String, OpenedShare> opens = {};

  /// What record_share was told, in order.
  final List<(String, ShareKind)> recorded = [];

  void reset() {
    opens.clear();
    recorded.clear();
  }

  static String tokenFor(String matchId, ShareKind kind) => '${kind.dbName}-$matchId';

  @override
  Future<Either<Failure, String>> getShareLink(String matchId, ShareKind kind) async {
    final token = tokenFor(matchId, kind);
    opens[token] = OpenedShare(kind: kind, matchId: matchId, teamId: 'team-1');
    return Right(shareUrl(token));
  }

  @override
  Future<Either<Failure, Unit>> recordShare(String matchId, ShareKind kind) async {
    recorded.add((matchId, kind));
    return const Right(unit);
  }

  @override
  Future<Either<Failure, OpenedShare?>> openShareLink(String token) async => Right(opens[token]);
}
