import 'package:flutter_test/flutter_test.dart';
import 'package:squad_hq/features/match/domain/entities/match.dart';
import 'package:squad_hq/features/match/domain/entities/match_history.dart';
import 'package:squad_hq/features/match/domain/entities/match_questions.dart';
import 'package:squad_hq/features/match/domain/entities/matchday_player.dart';
import 'package:squad_hq/features/player_rating/domain/entities/player_rating.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  const members = [
    MatchdayPlayer(profileId: 'yes', name: 'Yes'),
    MatchdayPlayer(profileId: 'maybe-played', name: 'Maybe played'),
    MatchdayPlayer(profileId: 'maybe-unsure', name: 'Maybe unsure'),
    MatchdayPlayer(profileId: 'maybe-out', name: 'Maybe out'),
    MatchdayPlayer(profileId: 'no', name: 'No'),
  ];
  // Sat 3 Oct 2026, 19:00–20:00 Bangkok.
  final match = Match(id: 'm', teamId: 't', opponent: 'X', kickoffAt: DateTime.utc(2026, 10, 3, 12));
  final pastMatch = PastMatch(
    match: match,
    answers: const {
      'yes': RsvpAnswer.yes,
      'maybe-played': RsvpAnswer.maybe,
      'maybe-unsure': RsvpAnswer.maybe,
      'maybe-out': RsvpAnswer.maybe,
      'no': RsvpAnswer.no,
    },
    played: const {'maybe-played': true, 'maybe-out': false},
  );
  const history = MatchHistory(members: members, timezone: 'Asia/Bangkok');

  test('Yes and Maybe players take part; a Maybe who said No is left out', () {
    expect(pastMatch.playedIds, {'yes', 'maybe-played'});
    expect(pastMatch.takingPartIds, {'yes', 'maybe-played', 'maybe-unsure'});
    expect(
      [for (final voter in history.motmVoters(pastMatch)) voter.profileId],
      ['yes', 'maybe-played', 'maybe-unsure'],
    );
    expect(pastMatch.needsPlayedCheck('maybe-unsure'), isTrue);
    expect(pastMatch.needsPlayedCheck('maybe-played'), isFalse);
    expect(pastMatch.needsPlayedCheck('yes'), isFalse);
  });

  test('Nobody answered Yes or Maybe: the whole team votes', () {
    final quiet = PastMatch(match: match, answers: const {'no': RsvpAnswer.no});
    expect(history.motmVoters(quiet), hasLength(members.length));
  });

  test('Questions close at midnight 2 days after match day', () {
    // Saturday's match: open until the end of Monday, Bangkok time.
    expect(history.questionsCloseAt(pastMatch), DateTime.utc(2026, 10, 5, 17));
    final endsAt = match.endsAt;
    expect(history.canAnswerQuestions(pastMatch, 'yes', endsAt), isTrue);
    expect(history.canAnswerQuestions(pastMatch, 'yes', endsAt.subtract(const Duration(minutes: 1))), isFalse);
    expect(history.canAnswerQuestions(pastMatch, 'maybe-out', endsAt), isFalse);
    expect(history.canAnswerQuestions(pastMatch, 'no', endsAt), isFalse);
    expect(history.canAnswerQuestions(pastMatch, 'yes', DateTime.utc(2026, 10, 5, 17)), isFalse);
    // Scores open at kickoff.
    expect(history.canEditGames(pastMatch, 'maybe-unsure', match.kickoffAt), isTrue);
  });

  test('History shows up to 2 game scores, then "+N more"', () {
    const games = [
      MatchGame(gameNo: 1, ourScore: 3, theirScore: 1),
      MatchGame(gameNo: 2, ourScore: 0, theirScore: 0),
      MatchGame(gameNo: 3),
      MatchGame(gameNo: 4, ourScore: 2, theirScore: 4),
    ];
    expect(gamesSummary(games), '3–1 · 0–0 · +2 more');
    expect(gamesSummary(games.take(2).toList()), '3–1 · 0–0');
    expect(gamesSummary(const []), '');
  });

  test('Every position has 3 questions and a teammate pick', () {
    for (final position in PlayedPosition.values) {
      expect(matchQuestions[position], hasLength(3));
      expect(matchPickQuestions[position], isNotNull);
    }
  });

  test('A level-up breakdown reads biggest first', () {
    expect(
      boostSummary(const [
        BoostPart(stat: StatKey.phy, points: 1, source: BoostSource.wins),
        BoostPart(stat: StatKey.sho, points: 3, source: BoostSource.motm),
        BoostPart(stat: StatKey.sho, points: 2, source: BoostSource.picks),
      ]),
      '+3 SHO from MOTM · +2 SHO from teammates · +1 PHY from wins',
    );
  });
}
