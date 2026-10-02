import 'package:equatable/equatable.dart';

import '../../domain/entities/matchday_player.dart';

sealed class MatchdayEvent extends Equatable {
  const MatchdayEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the squad list for the bloc's match (or reloads it).
final class MatchdayStarted extends MatchdayEvent {
  const MatchdayStarted();
}

/// Reloads quietly (no spinner) — a teammate's RSVP arrived.
final class MatchdayRefreshRequested extends MatchdayEvent {
  const MatchdayRefreshRequested();
}

/// The signed-in profile's own RSVP.
final class MatchdayRsvpSubmitted extends MatchdayEvent {
  const MatchdayRsvpSubmitted(this.answer);

  final RsvpAnswer answer;

  @override
  List<Object?> get props => [answer];
}
