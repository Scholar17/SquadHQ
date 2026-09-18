import 'package:equatable/equatable.dart';

class Match extends Equatable {
  const Match({
    required this.id,
    required this.teamId,
    required this.opponent,
    required this.kickoffAt,
    this.venue,
    this.feePerPlayer,
  });

  final String id;
  final String teamId;
  final String opponent;
  final DateTime kickoffAt;
  final String? venue;
  final double? feePerPlayer;

  @override
  List<Object?> get props => [id, teamId, opponent, kickoffAt, venue, feePerPlayer];
}
