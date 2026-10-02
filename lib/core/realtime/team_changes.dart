import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The tables a team's screens read, as streamed by Supabase Realtime — see
/// supabase/sql/019_realtime_wallet.sql, 021_realtime_match_home.sql,
/// 024_squads.sql and 025_expense_comments.sql.
enum TeamTable {
  teams('teams'),
  teamMembers('team_members'),
  matches('matches'),
  matchRsvps('match_rsvps'),
  motmVotes('motm_votes'),
  matchBillMembers('match_bill_members'),
  matchPayments('match_payments'),
  billReminders('bill_reminders'),
  expenses('expenses'),
  expensePayers('expense_payers'),
  expenseShares('expense_shares'),
  settlements('settlements'),
  // Unfiltered (no team column below) so deletes arrive too: Realtime
  // doesn't apply filters to them.
  expenseComments('expense_comments');

  const TeamTable(this.dbName);

  final String dbName;
}

abstract interface class TeamChanges {
  /// Emits the table whenever a row [teamId]'s screens read may have
  /// changed on the server. Carries no data — reload to see what changed.
  Stream<TeamTable> watch(String teamId);
}

/// One Realtime channel per team, shared by every listener (Home, Match,
/// Wallet) and closed once the last one cancels. Channels also close while
/// the app is hidden, so a backgrounded phone or browser tab doesn't hold a
/// connection; on return each table is emitted once so listeners catch up.
class SupabaseTeamChanges implements TeamChanges {
  SupabaseTeamChanges(this._supabase) {
    _lifecycle = AppLifecycleListener(onHide: _pauseAll, onShow: _resumeAll);
  }

  final SupabaseClient _supabase;
  late final AppLifecycleListener _lifecycle;
  final _teams = <String, _TeamChannel>{};
  var _hidden = false;

  @override
  Stream<TeamTable> watch(String teamId) => _teams
      .putIfAbsent(
        teamId,
        () => _TeamChannel(
          onFirstListen: () {
            if (!_hidden) _open(teamId);
          },
          onLastCancel: () {
            _teams.remove(teamId)?.close(_supabase);
          },
        ),
      )
      .controller
      .stream;

  /// [catchUp]: emit every table once subscribed, as changes may have been
  /// missed while the channel was closed.
  void _open(String teamId, {bool catchUp = false}) {
    final team = _teams[teamId];
    if (team == null) return;
    // Never two channels for one team (e.g. a show without a hide first).
    team.closeChannel(_supabase);
    void changed(TeamTable table) {
      if (!team.controller.isClosed) team.controller.add(table);
    }

    var channel = _supabase.channel('team:$teamId');
    for (final table in TeamTable.values) {
      // Realtime filters on one column; the per-match tables have no
      // team_id, but RLS already limits them to the caller's own teams.
      final column = switch (table) {
        TeamTable.teams => 'id',
        TeamTable.teamMembers ||
        TeamTable.matches ||
        TeamTable.expenses ||
        TeamTable.settlements =>
          'team_id',
        _ => null,
      };
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table.dbName,
        filter: column == null
            ? null
            : PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: column,
                value: teamId,
              ),
        callback: (_) => changed(table),
      );
    }
    // After the first subscribe, another one follows a dropped connection.
    var missedChanges = catchUp;
    late final RealtimeChannel subscribed;
    subscribed = channel.subscribe((status, error) {
      debugPrint('[realtime] team $teamId: ${status.name}${error == null ? '' : ' - $error'}');
      // Ignore a channel already replaced or closed by us.
      if (team.channel != subscribed) return;
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          team.retryDelay = _firstRetry;
          if (missedChanges) TeamTable.values.forEach(changed);
          missedChanges = true;
        case RealtimeSubscribeStatus.channelError || RealtimeSubscribeStatus.timedOut:
          // A failed subscription stays "joined" but delivers nothing, and
          // the client never retries it — so start over with a new channel.
          _retry(teamId);
        case RealtimeSubscribeStatus.closed:
          break;
      }
    });
    team.channel = subscribed;
  }

  static const _firstRetry = Duration(seconds: 2);
  static const _maxRetry = Duration(seconds: 30);

  void _retry(String teamId) {
    final team = _teams[teamId];
    if (team == null) return;
    team.closeChannel(_supabase);
    final delay = team.retryDelay;
    team.retryDelay = delay * 2 > _maxRetry ? _maxRetry : delay * 2;
    team.retryTimer = Timer(delay, () {
      if (!_hidden && identical(_teams[teamId], team)) _open(teamId, catchUp: true);
    });
  }

  void _pauseAll() {
    _hidden = true;
    for (final team in _teams.values) {
      team.closeChannel(_supabase);
    }
  }

  void _resumeAll() {
    _hidden = false;
    for (final MapEntry(key: teamId, value: team) in _teams.entries) {
      team.retryDelay = _firstRetry;
      _open(teamId, catchUp: true);
    }
  }

  void dispose() {
    _lifecycle.dispose();
    for (final team in _teams.values) {
      team.close(_supabase);
    }
    _teams.clear();
  }
}

class _TeamChannel {
  _TeamChannel({required void Function() onFirstListen, required void Function() onLastCancel})
      : controller = StreamController<TeamTable>.broadcast(
          onListen: onFirstListen,
          onCancel: onLastCancel,
        );

  final StreamController<TeamTable> controller;
  RealtimeChannel? channel;
  Timer? retryTimer;
  Duration retryDelay = SupabaseTeamChanges._firstRetry;

  void closeChannel(SupabaseClient supabase) {
    retryTimer?.cancel();
    retryTimer = null;
    final current = channel;
    channel = null;
    if (current != null) unawaited(supabase.removeChannel(current));
  }

  void close(SupabaseClient supabase) {
    closeChannel(supabase);
    unawaited(controller.close());
  }
}

/// Reloads a bloc when its team changes on the server: listens to
/// [tables] of whichever team [watch] was last given, and calls [onChange]
/// once a burst of changes settles (one save can touch several rows).
class TeamChangeWatcher {
  TeamChangeWatcher(
    this._changes, {
    required this.tables,
    required this.onChange,
    this.debounce = const Duration(milliseconds: 500),
  });

  final TeamChanges _changes;
  final Set<TeamTable> tables;
  final void Function() onChange;
  final Duration debounce;

  String? _teamId;
  StreamSubscription<TeamTable>? _subscription;
  Timer? _timer;

  /// Switches to [teamId]; null stops watching.
  void watch(String? teamId) {
    if (teamId == _teamId && (_subscription != null || teamId == null)) return;
    _teamId = teamId;
    unawaited(_subscription?.cancel());
    _timer?.cancel();
    _subscription = teamId == null
        ? null
        : _changes.watch(teamId).where(tables.contains).listen((_) {
            _timer?.cancel();
            _timer = Timer(debounce, onChange);
          });
  }

  Future<void> cancel() async {
    _timer?.cancel();
    _teamId = null;
    await _subscription?.cancel();
    _subscription = null;
  }
}
