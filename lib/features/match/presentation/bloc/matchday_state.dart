import 'package:equatable/equatable.dart';

import '../../domain/entities/matchday_player.dart';

sealed class MatchdayState extends Equatable {
  const MatchdayState();

  @override
  List<Object?> get props => [];
}

final class MatchdayLoading extends MatchdayState {
  const MatchdayLoading();
}

/// The team's full squad for this match, each with their RSVP.
final class MatchdayLoaded extends MatchdayState {
  const MatchdayLoaded(this.players);

  final List<MatchdayPlayer> players;

  int countOf(RsvpAnswer? answer) =>
      players.where((player) => player.answer == answer).length;

  @override
  List<Object?> get props => [players];
}

/// An RSVP is in flight; [previous] is what to fall back to (always
/// [MatchdayLoaded] in practice).
final class MatchdaySubmitting extends MatchdayState {
  const MatchdaySubmitting(this.previous);

  final MatchdayState previous;

  @override
  List<Object?> get props => [previous];
}

final class MatchdayFailure extends MatchdayState {
  const MatchdayFailure(this.message, this.previous);

  final String message;
  final MatchdayState previous;

  @override
  List<Object?> get props => [message, previous];
}
