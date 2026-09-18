import '../../domain/entities/match.dart';

class MatchModel extends Match {
  const MatchModel({
    required super.id,
    required super.teamId,
    required super.opponent,
    required super.kickoffAt,
    super.venue,
    super.feePerPlayer,
  });

  factory MatchModel.fromRow(Map<String, dynamic> row) => MatchModel(
        id: row['id'] as String,
        teamId: row['team_id'] as String,
        opponent: row['opponent'] as String,
        kickoffAt: DateTime.parse(row['kickoff_at'] as String),
        venue: row['venue'] as String?,
        feePerPlayer: (row['fee_per_player'] as num?)?.toDouble(),
      );
}
