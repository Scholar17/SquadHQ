import 'package:dartz/dartz.dart';
import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/player_rating/domain/entities/player_rating.dart';
import 'package:squad_hq/features/player_rating/domain/repositories/player_rating_repository.dart';

/// In-memory ratings. [userId] starts rated (so the Fill rating gate stays
/// out of other tests' way) unless a test calls [unrate].
class FakePlayerRatingRepository implements PlayerRatingRepository {
  FakePlayerRatingRepository({required this.userId}) {
    reset();
  }

  final String userId;
  final ratings = <String, PlayerRating>{};
  final submitted = <({List<String> positions, List<String> answerIds})>[];

  static const _roster = {'test-1': 'Test Player', 'p-2': 'Aung Ko', 'p-3': 'Min Thu'};

  static PlayerRating ratingOf(int ovr, List<String> positions) => PlayerRating(
    positions: positions,
    // Distinct from the OVR, so a test can find the OVR on its own.
    stats: {for (final key in StatKey.values) key: ovr - 20 - key.index},
    ovr: ovr,
    ratedAt: DateTime(2026, 9, 1),
  );

  void reset() {
    ratings
      ..clear()
      ..[userId] = ratingOf(74, ['CM'])
      ..['p-2'] = ratingOf(80, ['ST', 'W']);
    submitted.clear();
  }

  void unrate() => ratings.remove(userId);

  @override
  Future<Either<Failure, List<RatedPlayer>>> getTeamRatings(String teamId) async {
    final players = [
      for (final MapEntry(key: id, value: name) in _roster.entries)
        RatedPlayer(profileId: id, name: name, rating: ratings[id], apps: 3, goals: 1),
    ]..sort((a, b) => (b.rating?.ovr ?? -1).compareTo(a.rating?.ovr ?? -1));
    return Right(players);
  }

  @override
  Future<Either<Failure, PlayerRating?>> getMyRating() async => Right(ratings[userId]);

  @override
  Future<Either<Failure, List<RatingPosition>>> getPositions() async => const Right([
    RatingPosition(code: 'GK', name: 'Goalkeeper', group: PositionGroup.goalkeeper),
    RatingPosition(code: 'CB', name: 'Centre-back', group: PositionGroup.defender),
    RatingPosition(code: 'CM', name: 'Central midfield', group: PositionGroup.midfielder),
    RatingPosition(code: 'ST', name: 'Striker', group: PositionGroup.attacker),
  ]);

  @override
  Future<Either<Failure, List<RatingQuestion>>> getQuestions(String mainPosition) async => Right([
    for (var i = 1; i <= 2; i++)
      RatingQuestion(
        id: '$mainPosition-q$i',
        body: 'Question $i for $mainPosition',
        answers: [
          RatingAnswer(id: '$mainPosition-q$i-a', body: 'Answer A$i'),
          RatingAnswer(id: '$mainPosition-q$i-b', body: 'Answer B$i'),
        ],
      ),
  ]);

  @override
  Future<Either<Failure, PlayerRating>> submitRating({
    required List<String> positions,
    required List<String> answerIds,
  }) async {
    submitted.add((positions: positions, answerIds: answerIds));
    final rating = ratingOf(71, positions);
    ratings[userId] = rating;
    return Right(rating);
  }

  @override
  Future<Either<Failure, PlayerRating>> improveRating() async =>
      const Left(ServerFailure('Play 30 matches to improve your rating'));
}
