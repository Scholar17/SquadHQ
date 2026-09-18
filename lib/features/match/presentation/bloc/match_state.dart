import 'package:equatable/equatable.dart';

import '../../domain/entities/match.dart';

sealed class MatchState extends Equatable {
  const MatchState();

  @override
  List<Object?> get props => [];
}

final class MatchLoading extends MatchState {
  const MatchLoading();
}

/// Every upcoming match for the active team, soonest first — empty if it
/// has none (or there's no active team at all).
final class MatchLoaded extends MatchState {
  const MatchLoaded(this.matches);

  final List<Match> matches;

  @override
  List<Object?> get props => [matches];
}

/// A create submission is in flight; [previous] is what to fall back to
/// (always [MatchLoaded] in practice).
final class MatchSubmitting extends MatchState {
  const MatchSubmitting(this.previous);

  final MatchState previous;

  @override
  List<Object?> get props => [previous];
}

final class MatchFailure extends MatchState {
  const MatchFailure(this.message, this.previous);

  final String message;
  final MatchState previous;

  @override
  List<Object?> get props => [message, previous];
}
