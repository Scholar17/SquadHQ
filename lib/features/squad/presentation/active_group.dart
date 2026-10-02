import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../team_membership/domain/entities/team.dart';
import '../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../team_membership/presentation/bloc/team_membership_state.dart';
import 'bloc/squad_ledger_bloc.dart';

/// The profile's active group, or null while loading / when it has none.
Team? activeGroupOf(TeamMembershipState state) {
  final settled = switch (state) {
    TeamMembershipSubmitting(:final previous) || TeamMembershipFailure(:final previous) => previous,
    _ => state,
  };
  if (settled is! TeamMembershipLoaded) return null;
  for (final team in settled.teams) {
    if (team.isActive) return team;
  }
  return null;
}

/// Rebuilds with the active group as it changes.
Team? watchActiveGroup(BuildContext context) =>
    activeGroupOf(context.watch<TeamMembershipBloc>().state);

/// "Friday Crew" → "FC".
String groupInitials(String name) {
  final initials = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => String.fromCharCode(word.runes.first).toUpperCase())
      .join();
  return initials.isEmpty ? '?' : initials;
}

/// Pull-to-refresh for the squad tabs.
Future<void> refreshSquad(BuildContext context) {
  final done = Completer<void>();
  context.read<SquadLedgerBloc>().add(SquadRefreshRequested(done: done));
  return done.future;
}
