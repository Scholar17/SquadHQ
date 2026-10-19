import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/match.dart';
import '../entities/match_history.dart';
import '../entities/match_questions.dart';
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
    String? venueId,
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
    String? venueId,
    required int durationMinutes,
    int? playersNeeded,
  });

  /// Any team admin, at any time — even after the match (053's
  /// `delete_match`). Its RSVPs, games, answers, votes and bill go too.
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

  /// Saves game [gameNo] of [matchId] — null adds the next game. Null
  /// scores = "Not sure". Players in the match, from kickoff until the
  /// questions close (`save_match_game`, 053).
  Future<Either<Failure, Unit>> saveMatchGame({
    required String matchId,
    int? gameNo,
    int? ourScore,
    int? theirScore,
  });

  /// Removes the last game (`remove_match_game`).
  Future<Either<Failure, Unit>> removeMatchGame({required String matchId, required int gameNo});

  /// A Maybe player's "Did you play today?" (`set_match_played`).
  Future<Either<Failure, Unit>> setMatchPlayed({required String matchId, required bool played});

  /// Saves or changes the caller's after-match answers
  /// (`submit_match_answers`).
  Future<Either<Failure, Unit>> submitMatchAnswers({
    required String matchId,
    required MatchAnswers answers,
  });

  /// The caller's answers to [matchId] so far, or null.
  Future<Either<Failure, MatchAnswers?>> getMyMatchAnswers(String matchId);

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
