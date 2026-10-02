import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/match.dart';
import '../entities/match_history.dart';
import '../entities/matchday_player.dart';

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
    required int durationMinutes,
    int? playersNeeded,
  });

  /// Fails unless the caller is the match's team admin or super admin — see
  /// `update_match` in supabase/sql/007_match_rsvps_and_actions.sql.
  Future<Either<Failure, Match>> updateMatch({
    required String matchId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    required int durationMinutes,
    int? playersNeeded,
  });

  /// Same admin-only rule as [updateMatch] — see `delete_match`.
  Future<Either<Failure, Unit>> deleteMatch(String matchId);

  /// Every member of [teamId], each with their RSVP to [matchId] (null if
  /// they haven't replied).
  Future<Either<Failure, List<MatchdayPlayer>>> getMatchdayRoster({
    required String teamId,
    required String matchId,
  });

  /// Sets the caller's own RSVP to [matchId] — see `set_match_rsvp`.
  Future<Either<Failure, Unit>> setRsvp({
    required String matchId,
    required RsvpAnswer answer,
  });

  /// [teamId]'s matches that have kicked off, newest first.
  Future<Either<Failure, MatchHistory>> getMatchHistory(String teamId);

  /// Admin-only, and only once the match has kicked off — see
  /// `set_match_score` in supabase/sql/009_match_scores_and_motm.sql.
  Future<Either<Failure, Unit>> setMatchScore({
    required String matchId,
    required int ourScore,
    required int theirScore,
  });

  /// The caller's Man of the Match vote — see `vote_motm`.
  Future<Either<Failure, Unit>> voteMotm({
    required String matchId,
    required String nomineeId,
  });

  /// Admin-only "Remind players to vote" — pushes everyone who hasn't
  /// answered. Once per day per match, before kick-off (see
  /// `nudge_match_rsvp` in supabase/sql/014_push_moments.sql).
  Future<Either<Failure, Unit>> nudgeMatchRsvp(String matchId);
}
