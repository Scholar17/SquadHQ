import 'package:equatable/equatable.dart';
import 'package:timezone/timezone.dart' as tz;

import 'match.dart';
import 'match_questions.dart';
import 'matchday_player.dart';

/// A match that has kicked off, with everything its history page shows.
class PastMatch extends Equatable {
  const PastMatch({
    required this.match,
    this.answers = const {},
    this.motmVotes = const {},
    this.played = const {},
    this.games = const [],
    this.answeredByMe = false,
  });

  final Match match;

  /// RSVP answers keyed by profile id.
  final Map<String, RsvpAnswer> answers;

  /// Man of the Match votes: voter's profile id → nominee's profile id.
  final Map<String, String> motmVotes;

  /// Maybe players' "Did you play today?", by profile id (053). Missing =
  /// not answered yet.
  final Map<String, bool> played;

  /// Its games in order (Game 1, Game 2, …); empty until someone saves one.
  final List<MatchGame> games;

  /// The viewer has answered this match's questions.
  final bool answeredByMe;

  /// Who played: Yes players, and Maybe players who said they did.
  Set<String> get playedIds => {
        for (final MapEntry(key: profileId, value: answer) in answers.entries)
          if (answer == RsvpAnswer.yes || (answer == RsvpAnswer.maybe && played[profileId] == true))
            profileId,
      };

  /// Yes and Maybe players, minus a Maybe who said they didn't play — they
  /// fill in the scores and answer the questions.
  Set<String> get takingPartIds => {
        for (final MapEntry(key: profileId, value: answer) in answers.entries)
          if (answer == RsvpAnswer.yes || (answer == RsvpAnswer.maybe && played[profileId] != false))
            profileId,
      };

  /// [profileId] answered Maybe and hasn't said whether they played.
  bool needsPlayedCheck(String profileId) =>
      answers[profileId] == RsvpAnswer.maybe && !played.containsKey(profileId);

  /// Votes per nominee.
  Map<String, int> get motmTally {
    final tally = <String, int>{};
    for (final nominee in motmVotes.values) {
      tally[nominee] = (tally[nominee] ?? 0) + 1;
    }
    return tally;
  }

  /// The nominee(s) with the most votes — more than one on a tie; empty
  /// until someone votes. Only meaningful once the result is decided (see
  /// [MatchHistory.motmDecided]); until then voting is secret.
  Set<String> get motmWinnerIds {
    final tally = motmTally;
    if (tally.isEmpty) return const {};
    final top = tally.values.reduce((a, b) => a > b ? a : b);
    return {
      for (final MapEntry(key: nominee, value: count) in tally.entries)
        if (count == top) nominee,
    };
  }

  @override
  List<Object?> get props => [match, answers, motmVotes, played, games, answeredByMe];
}

/// A team's past matches (newest first) and its members, whose names and
/// photos the history shows. Members reuse [MatchdayPlayer] with no answer.
class MatchHistory extends Equatable {
  const MatchHistory({
    this.members = const [],
    this.matches = const [],
    this.timezone = 'Asia/Bangkok',
  });

  final List<MatchdayPlayer> members;
  final List<PastMatch> matches;

  /// The team's IANA time zone — decides when "end of match day" is.
  final String timezone;

  /// When Man of the Match voting closes at the latest: midnight, in the
  /// team's [timezone], at the end of the day the match finishes — same as
  /// `motm_voting_closes_at` (supabase/sql/011_team_timezone.sql). Falls
  /// back to UTC+7 if the zone isn't known (or the time zone database
  /// hasn't loaded).
  DateTime motmVotingClosesAt(PastMatch pastMatch) => _midnightAfter(pastMatch, days: 1);

  /// Midnight, [days] days after the start of the day [pastMatch] ends on.
  DateTime _midnightAfter(PastMatch pastMatch, {required int days}) {
    final endsAt = pastMatch.match.endsAt;
    try {
      final location = tz.getLocation(timezone);
      final local = tz.TZDateTime.from(endsAt, location);
      return tz.TZDateTime(location, local.year, local.month, local.day + days).toUtc();
    } on tz.LocationNotFoundException {
      const bangkok = Duration(hours: 7);
      final local = endsAt.toUtc().add(bangkok);
      return DateTime.utc(local.year, local.month, local.day + days).subtract(bangkok);
    }
  }

  MatchdayPlayer? member(String profileId) {
    for (final member in members) {
      if (member.profileId == profileId) return member;
    }
    return null;
  }

  PastMatch? forMatch(String matchId) {
    for (final pastMatch in matches) {
      if (pastMatch.match.id == matchId) return pastMatch;
    }
    return null;
  }

  /// Who votes Man of the Match (and can be voted for): Yes and Maybe
  /// players, never a Maybe who said they didn't play — or the whole team
  /// if no one answered Yes or Maybe. See `motm_voter_ids` (053).
  List<MatchdayPlayer> motmVoters(PastMatch pastMatch) {
    final nobodyAnswered = !pastMatch.answers.values.any(
      (answer) => answer == RsvpAnswer.yes || answer == RsvpAnswer.maybe,
    );
    final takingPart = pastMatch.takingPartIds;
    return [
      for (final member in members)
        if (nobodyAnswered || takingPart.contains(member.profileId)) member,
    ];
  }

  /// The after-match questions close at midnight 2 days after match day,
  /// in the team's [timezone] — `match_questions_close_at` (053).
  DateTime questionsCloseAt(PastMatch pastMatch) => _midnightAfter(pastMatch, days: 3);

  /// [profileId] can answer this match's questions right now: it has
  /// ended, they're a Yes or Maybe player who didn't say they missed it,
  /// and the questions are still open.
  bool canAnswerQuestions(PastMatch pastMatch, String profileId, DateTime now) =>
      !now.isBefore(pastMatch.match.endsAt) &&
      now.isBefore(questionsCloseAt(pastMatch)) &&
      pastMatch.takingPartIds.contains(profileId);

  /// [profileId] can add or change game scores: from kickoff until the
  /// questions close, if they take part (see `save_match_game`).
  bool canEditGames(PastMatch pastMatch, String profileId, DateTime now) =>
      !now.isBefore(pastMatch.match.kickoffAt) &&
      now.isBefore(questionsCloseAt(pastMatch)) &&
      motmVoters(pastMatch).any((voter) => voter.profileId == profileId);

  /// Who [voterId] can vote for: the other [motmVoters].
  List<MatchdayPlayer> motmCandidates(PastMatch pastMatch, String voterId) => [
        for (final voter in motmVoters(pastMatch))
          if (voter.profileId != voterId) voter,
      ];

  /// The result is decided — and voting closed — once every voter has
  /// voted, or at [motmVotingClosesAt], whichever comes first.
  /// With no votes by then, nobody is Man of the Match.
  bool motmDecided(PastMatch pastMatch, DateTime now) {
    if (!now.isBefore(motmVotingClosesAt(pastMatch))) return true;
    final voters = motmVoters(pastMatch);
    return voters.isNotEmpty &&
        voters.every((voter) => pastMatch.motmVotes.containsKey(voter.profileId));
  }

  /// Voting is open: the match has finished and the result isn't decided.
  bool motmVotingOpen(PastMatch pastMatch, DateTime now) =>
      !now.isBefore(pastMatch.match.endsAt) && !motmDecided(pastMatch, now);

  /// [voterId] can cast or change a vote right now.
  bool canVoteMotm(PastMatch pastMatch, String voterId, DateTime now) =>
      motmVotingOpen(pastMatch, now) &&
      motmVoters(pastMatch).any((voter) => voter.profileId == voterId) &&
      motmCandidates(pastMatch, voterId).isNotEmpty;

  @override
  List<Object?> get props => [members, matches, timezone];
}
