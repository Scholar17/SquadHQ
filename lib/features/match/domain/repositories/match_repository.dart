import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/match.dart';

abstract interface class MatchRepository {
  /// Every match for [teamId] that hasn't kicked off yet, soonest first.
  Future<Either<Failure, List<Match>>> getUpcomingMatches(String teamId);

  /// Fails unless the caller is [teamId]'s admin or super admin — see
  /// `create_match` in supabase/sql/006_create_matches.sql.
  Future<Either<Failure, Match>> createMatch({
    required String teamId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    double? feePerPlayer,
  });
}
