import '../../domain/entities/match.dart';

class MatchModel extends Match {
  const MatchModel({
    required super.id,
    required super.teamId,
    required super.opponent,
    required super.kickoffAt,
    super.venue,
    super.durationMinutes,
    super.playersNeeded,
    super.lastNudgedAt,
    super.createdBy,
    super.ourScore,
    super.theirScore,
  });

  factory MatchModel.fromRow(Map<String, dynamic> row) => MatchModel(
        id: row['id'] as String,
        teamId: row['team_id'] as String,
        opponent: row['opponent'] as String,
        kickoffAt: DateTime.parse(row['kickoff_at'] as String),
        venue: row['venue'] as String?,
        durationMinutes: row['duration_minutes'] as int? ?? Match.defaultDurationMinutes,
        playersNeeded: row['players_needed'] as int?,
        createdBy: row['created_by'] as String?,
        lastNudgedAt: switch (row['last_nudged_at']) {
          final String at => DateTime.parse(at),
          _ => null,
        },
        ourScore: row['our_score'] as int?,
        theirScore: row['their_score'] as int?,
      );
}
