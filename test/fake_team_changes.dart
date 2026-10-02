import 'dart:async';

import 'package:squad_hq/core/realtime/team_changes.dart';

/// In-memory [TeamChanges]: [push] stands in for a teammate's change
/// arriving over Realtime.
class FakeTeamChanges implements TeamChanges {
  final _changes = StreamController<(String, TeamTable)>.broadcast();

  /// Open [watch] subscriptions, per team.
  final watchers = <String, int>{};

  void push(String teamId, TeamTable table) => _changes.add((teamId, table));

  @override
  Stream<TeamTable> watch(String teamId) {
    late final StreamController<TeamTable> controller;
    StreamSubscription<(String, TeamTable)>? source;
    controller = StreamController<TeamTable>(
      onListen: () {
        watchers.update(teamId, (n) => n + 1, ifAbsent: () => 1);
        source = _changes.stream
            .where((change) => change.$1 == teamId)
            .listen((change) => controller.add(change.$2));
      },
      onCancel: () async {
        watchers.update(teamId, (n) => n - 1);
        await source?.cancel();
      },
    );
    return controller.stream;
  }
}
