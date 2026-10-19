import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/player_rating.dart';

/// supabase/sql/045_player_ratings.sql — every number is worked out
/// server-side from the answers.
abstract interface class PlayerRatingRepository {
  /// Everyone on [teamId], best OVR first; unrated players last.
  Future<Either<Failure, List<RatedPlayer>>> getTeamRatings(String teamId);

  /// The signed-in player's own card, or null before they've rated.
  Future<Either<Failure, PlayerRating?>> getMyRating();

  Future<Either<Failure, List<RatingPosition>>> getPositions();

  /// The 8 questions this player gets for [mainPosition] — their own
  /// shuffle, not their teammates'.
  Future<Either<Failure, List<RatingQuestion>>> getQuestions(String mainPosition);

  /// Once only. [positions] main first; one answer id per question.
  Future<Either<Failure, PlayerRating>> submitRating({
    required List<String> positions,
    required List<String> answerIds,
  });

  /// Every 10 matches played: a boost from the after-match questions,
  /// teammates' picks, wins, clean sheets and MOTM wins (053).
  Future<Either<Failure, PlayerRating>> improveRating();
}
