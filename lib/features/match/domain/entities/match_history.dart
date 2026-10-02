import 'package:equatable/equatable.dart';
import 'package:timezone/timezone.dart' as tz;

import 'match.dart';
import 'matchday_player.dart';

/// A match that has kicked off, with everything its history page shows.
class PastMatch extends Equatable {
  const PastMatch({
    required this.match,
    this.answers = const {},
    this.motmVotes = const {},
  });

  final Match match;

  /// RSVP answers keyed by profile id.
  final Map<String, RsvpAnswer> answers;

  /// Man of the Match votes: voter's profile id → nominee's profile id.
  final Map<String, String> motmVotes;

  /// Everyone who RSVP'd "In" — treated as who played.
  Set<String> get playedIds => {
        for (final MapEntry(key: profileId, value: answer) in answers.entries)
          if (answer == RsvpAnswer.yes) profileId,
      };

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
  List<Object?> get props => [match, answers, motmVotes];
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
  DateTime motmVotingClosesAt(PastMatch pastMatch) {
    final endsAt = pastMatch.match.endsAt;
    try {
      final location = tz.getLocation(timezone);
      final local = tz.TZDateTime.from(endsAt, location);
      return tz.TZDateTime(location, local.year, local.month, local.day + 1).toUtc();
    } on tz.LocationNotFoundException {
      const bangkok = Duration(hours: 7);
      final local = endsAt.toUtc().add(bangkok);
      return DateTime.utc(local.year, local.month, local.day + 1).subtract(bangkok);
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

  /// Who votes Man of the Match (and can be voted for): whoever played,
  /// or the whole team if no one RSVP'd "In" — see `motm_voter_ids`.
  List<MatchdayPlayer> motmVoters(PastMatch pastMatch) {
    final played = pastMatch.playedIds;
    return [
      for (final member in members)
        if (played.isEmpty || played.contains(member.profileId)) member,
    ];
  }

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
