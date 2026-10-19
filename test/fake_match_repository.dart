import 'package:dartz/dartz.dart';

import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/match/domain/entities/match.dart';
import 'package:squad_hq/features/match/domain/entities/match_history.dart';
import 'package:squad_hq/features/match/domain/entities/match_questions.dart';
import 'package:squad_hq/features/match/domain/entities/matchday_player.dart';
import 'package:squad_hq/features/match/domain/repositories/match_repository.dart';

/// In-memory [MatchRepository] for widget tests, so the real match blocs
/// run end to end without Supabase. Call [reset] between tests.
class FakeMatchRepository implements MatchRepository {
  FakeMatchRepository({required this.teamId, required this.userId}) {
    reset();
  }

  final String teamId;

  /// The signed-in profile — [setRsvp] records answers under this id.
  final String userId;

  late List<Match> _matches;

  /// Matches that have kicked off — the Match history.
  late List<Match> pastMatches;

  /// Man of the Match votes: match id → (voter id → nominee id).
  final motmVotes = <String, Map<String, String>>{};
  late List<MatchdayPlayer> _squad;
  final _answers = <(String, String), RsvpAnswer>{};

  /// Game scores: match id → its games, in order.
  final games = <String, List<MatchGame>>{};

  /// Maybe players' "Did you play?": (match id, profile id) → answer.
  final played = <(String, String), bool>{};

  /// The signed-in player's after-match answers, by match id.
  final myAnswers = <String, MatchAnswers>{};

  /// Read by FakeWalletRepository, which (like the real wallet) sees the
  /// same matches, squad and RSVPs.
  List<Match> get matches => _matches;
  List<MatchdayPlayer> get squad => _squad;
  Map<String, RsvpAnswer> answersFor(String matchId) => {
        for (final MapEntry(key: (id, profileId), :value) in _answers.entries)
          if (id == matchId) profileId: value,
      };

  /// [profileId]'s RSVP to [matchId], as if they voted on their own phone.
  void answerAs(String matchId, String profileId, RsvpAnswer answer) =>
      _answers[(matchId, profileId)] = answer;

  /// Adds teammates who've already RSVP'd [answer] to match-1.
  void addVoters(List<String> names, RsvpAnswer answer) {
    for (final (index, name) in names.indexed) {
      final profileId = 'extra-$index';
      _squad = [..._squad, MatchdayPlayer(profileId: profileId, name: name)];
      _answers[('match-1', profileId)] = answer;
    }
  }

  /// Marks [profileIds] as having RSVP'd "In" to [matchId].
  void addPlayed(String matchId, List<String> profileIds) {
    for (final profileId in profileIds) {
      _answers[(matchId, profileId)] = RsvpAnswer.yes;
    }
  }

  void reset() {
    nudged.clear();
    games.clear();
    played.clear();
    myAnswers.clear();
    _matches = [
      Match(
        id: 'match-1',
        teamId: teamId,
        opponent: 'Sundown United',
        kickoffAt: DateTime(2037, 10, 3, 19),
        venue: 'Lumpini Park Pitch 2',
        createdBy: userId,
      ),
    ];
    _squad = [
      MatchdayPlayer(profileId: userId, name: 'Test Player'),
      const MatchdayPlayer(profileId: 'p-2', name: 'Aung Ko'),
      const MatchdayPlayer(profileId: 'p-3', name: 'Min Thu'),
    ];
    _answers
      ..clear()
      ..[('match-1', 'p-2')] = RsvpAnswer.yes;
    // One finished match (all three played, Aung Ko already voted Min Thu
    // MOTM) and one kicked off 10 minutes ago that's still being played.
    pastMatches = [
      Match(
        id: 'past-live',
        teamId: teamId,
        opponent: 'Riverside Rovers',
        kickoffAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      Match(
        id: 'past-1',
        teamId: teamId,
        opponent: 'Thai Group',
        kickoffAt: DateTime(2026, 9, 13, 19, 30),
        venue: 'Polo Football Park',
      ),
    ];
    for (final profileId in [userId, 'p-2', 'p-3']) {
      _answers[('past-1', profileId)] = RsvpAnswer.yes;
    }
    motmVotes
      ..clear()
      ..['past-1'] = {'p-2': 'p-3'};
  }

  @override
  Future<Either<Failure, List<Match>>> getUpcomingMatches(String teamId) async =>
      Right(_matches.where((match) => match.teamId == teamId).toList());

  @override
  Future<Either<Failure, Match>> createMatch({
    required String teamId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    String? venueId,
    required int durationMinutes,
    int? playersNeeded,
  }) async {
    final match = Match(
      id: 'match-${_matches.length + 1}',
      teamId: teamId,
      opponent: opponent,
      kickoffAt: kickoffAt,
      venue: venue,
      venueId: venueId,
      durationMinutes: durationMinutes,
      playersNeeded: playersNeeded,
    );
    _matches = [..._matches, match];
    // Like create_match (016): the creator starts as "I'm in".
    _answers[(match.id, userId)] = RsvpAnswer.yes;
    return Right(match);
  }

  @override
  Future<Either<Failure, Match>> updateMatch({
    required String matchId,
    required String opponent,
    required DateTime kickoffAt,
    String? venue,
    String? venueId,
    required int durationMinutes,
    int? playersNeeded,
  }) async {
    final existing = _matches.firstWhere((match) => match.id == matchId);
    final updated = Match(
      id: matchId,
      teamId: existing.teamId,
      opponent: opponent,
      kickoffAt: kickoffAt,
      venue: venue,
      venueId: venueId,
      durationMinutes: durationMinutes,
      playersNeeded: playersNeeded,
    );
    _matches = [
      for (final match in _matches) match.id == matchId ? updated : match,
    ];
    return Right(updated);
  }

  @override
  Future<Either<Failure, Unit>> deleteMatch(String matchId) async {
    _matches = _matches.where((match) => match.id != matchId).toList();
    pastMatches = pastMatches.where((match) => match.id != matchId).toList();
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<MatchdayPlayer>>> getMatchdayRoster({
    required String teamId,
    required String matchId,
  }) async =>
      Right([
        for (final player in _squad)
          MatchdayPlayer(
            profileId: player.profileId,
            name: player.name,
            answer: _answers[(matchId, player.profileId)],
          ),
      ]);

  @override
  Future<Either<Failure, Unit>> setRsvp({
    required String matchId,
    required RsvpAnswer answer,
  }) async {
    _answers[(matchId, userId)] = answer;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, MatchHistory>> getMatchHistory(String teamId) async => Right(
        MatchHistory(
          members: [
            for (final player in _squad)
              MatchdayPlayer(profileId: player.profileId, name: player.name),
          ],
          matches: [
            for (final match in pastMatches)
              PastMatch(
                match: match,
                answers: answersFor(match.id),
                motmVotes: {...?motmVotes[match.id]},
                played: {
                  for (final MapEntry(key: (id, profileId), :value) in played.entries)
                    if (id == match.id) profileId: value,
                },
                games: [...?games[match.id]],
                answeredByMe: myAnswers.containsKey(match.id),
              ),
          ],
        ),
      );

  @override
  Future<Either<Failure, Unit>> saveMatchGame({
    required String matchId,
    int? gameNo,
    int? ourScore,
    int? theirScore,
  }) async {
    final list = games[matchId] ??= [];
    final number = gameNo ?? list.length + 1;
    final game = MatchGame(
      gameNo: number,
      ourScore: ourScore,
      theirScore: theirScore,
      updatedBy: userId,
      updatedAt: DateTime.now(),
    );
    if (number <= list.length) {
      list[number - 1] = game;
    } else {
      list.add(game);
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> removeMatchGame({required String matchId, required int gameNo}) async {
    games[matchId]?.removeWhere((game) => game.gameNo == gameNo);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> setMatchPlayed({required String matchId, required bool played}) async {
    this.played[(matchId, userId)] = played;
    if (!played) {
      myAnswers.remove(matchId);
      motmVotes[matchId]?.removeWhere((voter, nominee) => voter == userId || nominee == userId);
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> submitMatchAnswers({
    required String matchId,
    required MatchAnswers answers,
  }) async {
    if (answers.pickId == userId) return const Left(ServerFailure("You can't pick yourself"));
    if (_answers[(matchId, userId)] == RsvpAnswer.maybe) played[(matchId, userId)] = true;
    myAnswers[matchId] = answers;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, MatchAnswers?>> getMyMatchAnswers(String matchId) async =>
      Right(myAnswers[matchId]);

  @override
  Future<Either<Failure, Unit>> voteMotm({
    required String matchId,
    required String nomineeId,
  }) async {
    if (nomineeId == userId) return const Left(ServerFailure("You can't vote for yourself"));
    (motmVotes[matchId] ??= {})[userId] = nomineeId;
    return const Right(unit);
  }

  /// Match ids an admin sent "Remind players to vote" for.
  final nudged = <String>[];

  @override
  Future<Either<Failure, Unit>> nudgeMatchRsvp(String matchId) async {
    nudged.add(matchId);
    _matches = [
      for (final match in _matches)
        match.id == matchId
            ? Match(
                id: match.id,
                teamId: match.teamId,
                opponent: match.opponent,
                kickoffAt: match.kickoffAt,
                venue: match.venue,
                durationMinutes: match.durationMinutes,
                playersNeeded: match.playersNeeded,
                lastNudgedAt: DateTime.now(),
              )
            : match,
    ];
    return const Right(unit);
  }
}
