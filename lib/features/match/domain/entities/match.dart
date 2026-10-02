import 'package:equatable/equatable.dart';

enum MatchResult { win, draw, loss }

class Match extends Equatable {
  const Match({
    required this.id,
    required this.teamId,
    required this.opponent,
    required this.kickoffAt,
    this.venue,
    this.durationMinutes = defaultDurationMinutes,
    this.playersNeeded,
    this.lastNudgedAt,
    this.createdBy,
    this.ourScore,
    this.theirScore,
  });

  final String id;
  final String teamId;
  final String opponent;
  final DateTime kickoffAt;
  final String? venue;

  /// Play time — 1 hour unless set when the match is created or edited.
  final int durationMinutes;

  static const defaultDurationMinutes = 60;

  /// How many players the match needs (e.g. 10 for 5-a-side), if set —
  /// "Squad ready" goes out when this many say In.
  final int? playersNeeded;

  /// When an admin last sent "Remind players to vote" (once a day).
  final DateTime? lastNudgedAt;

  /// The admin who created the match — the only one who can cancel it.
  final String? createdBy;

  /// When the match finishes (kick-off + play time). Man of the Match
  /// voting opens then.
  DateTime get endsAt => kickoffAt.add(Duration(minutes: durationMinutes));

  /// Final score, once a team admin records it (supabase/sql/009).
  final int? ourScore;
  final int? theirScore;

  MatchResult? get result {
    final ours = ourScore;
    final theirs = theirScore;
    if (ours == null || theirs == null) return null;
    if (ours > theirs) return MatchResult.win;
    if (ours < theirs) return MatchResult.loss;
    return MatchResult.draw;
  }

  @override
  List<Object?> get props => [
        id,
        teamId,
        opponent,
        kickoffAt,
        venue,
        durationMinutes,
        playersNeeded,
        lastNudgedAt,
        createdBy,
        ourScore,
        theirScore,
      ];
}
