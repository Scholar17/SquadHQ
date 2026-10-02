import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/clock/clock_scope.dart';
import '../../match/domain/entities/match.dart';
import '../../match/domain/entities/match_history.dart';
import '../../match/presentation/bloc/match_bloc.dart';
import '../../match/presentation/bloc/match_history_bloc.dart';
import '../../match/presentation/bloc/match_state.dart';
import '../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../team_membership/presentation/bloc/team_membership_state.dart';
import '../../wallet/domain/entities/bill_split.dart';
import '../../wallet/domain/entities/team_wallet.dart';
import '../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../wallet/presentation/bloc/wallet_state.dart';
import '../domain/entities/team_snapshot.dart' show SquadRole;
import 'bloc/team_bloc.dart';
import 'view_role.dart';

/// A finished match worth recapping on Home: its result, the Man of the
/// Match vote, and the viewer's unpaid share of its bill, if any.
class MatchRecap {
  const MatchRecap({required this.pastMatch, required this.needsMotmVote, this.owed});

  final PastMatch pastMatch;

  /// Voting is open, and the viewer played but hasn't voted yet.
  final bool needsMotmVote;

  /// The viewer's unpaid share of this match's bill.
  final (WalletMatch, BillSplit)? owed;
}

/// Everything waiting on the signed-in player, worked out from the app's
/// match, history and wallet data plus the current time. Home's recaps,
/// its bell count and the tab badges all read this, so they agree.
class PendingActions {
  const PendingActions({
    this.recaps = const [],
    this.rsvpNeeded = false,
    this.motmVotesNeeded = 0,
    this.feesOwed = 0,
  });

  /// How long after a match ends it stays in Home's recaps.
  static const recapWindow = Duration(days: 7);

  /// Finished matches within [recapWindow], newest first.
  final List<MatchRecap> recaps;

  /// The next match still needs the viewer's RSVP (Player view only).
  final bool rsvpNeeded;

  /// Recapped matches whose Man of the Match the viewer can still vote on.
  final int motmVotesNeeded;

  /// Bills for finished matches (of any age) the viewer hasn't paid their
  /// share of. A bill for a match that hasn't finished doesn't nag yet.
  final int feesOwed;

  int get total => (rsvpNeeded ? 1 : 0) + motmVotesNeeded + feesOwed;

  /// Match tab: only the next match's RSVP.
  bool get matchTabAlert => rsvpNeeded;

  /// Home tab: anything to do after a match — vote MOTM or pay a fee.
  bool get homeTabAlert => motmVotesNeeded > 0 || feesOwed > 0;

  /// Wallet tab: a fee to pay (the only place with a Pay button).
  bool get walletTabAlert => feesOwed > 0;

  /// [compute] from the app-root blocs, the shell's TeamBloc (for the
  /// Manager/Player view) and [ClockScope] — rebuilding [context] whenever
  /// any of them change.
  static PendingActions of(BuildContext context, String userId) {
    final membership = switch (context.watch<TeamMembershipBloc>().state) {
      TeamMembershipSubmitting(:final previous) => previous,
      TeamMembershipFailure(:final previous) => previous,
      final state => state,
    };
    if (membership is! TeamMembershipLoaded) return const PendingActions();
    final active = membership.teams.where((team) => team.isActive).firstOrNull;
    if (active == null) return const PendingActions();
    final upcoming = switch (context.watch<MatchBloc>().state) {
      MatchLoaded(:final matches) => matches,
      MatchSubmitting(previous: MatchLoaded(:final matches)) => matches,
      MatchFailure(previous: MatchLoaded(:final matches)) => matches,
      _ => const <Match>[],
    };
    return compute(
      userId: userId,
      playerView: viewRoleFor(active.role, context.watch<TeamBloc>().state) == SquadRole.player,
      now: ClockScope.now(context),
      upcoming: upcoming,
      history: context.watch<MatchHistoryBloc>().state.history,
      wallet: context.watch<WalletBloc>().state.wallet,
    );
  }

  /// A match is finished once kick-off + play time has passed.
  static PendingActions compute({
    required String userId,
    required bool playerView,
    required DateTime now,
    List<Match> upcoming = const [],
    MatchHistory? history,
    TeamWallet? wallet,
  }) {
    final owed = [
      for (final bill in wallet?.owedBy(userId) ?? const <(WalletMatch, BillSplit)>[])
        if (!bill.$1.match.endsAt.isAfter(now)) bill,
    ];
    final owedByMatch = {for (final bill in owed) bill.$1.match.id: bill};

    final recaps = <MatchRecap>[];
    if (history != null) {
      for (final pastMatch in history.matches) {
        final endsAt = pastMatch.match.endsAt;
        if (endsAt.isAfter(now) || now.difference(endsAt) > recapWindow) continue;
        recaps.add(
          MatchRecap(
            pastMatch: pastMatch,
            needsMotmVote:
                !pastMatch.motmVotes.containsKey(userId) &&
                history.canVoteMotm(pastMatch, userId, now),
            owed: owedByMatch[pastMatch.match.id],
          ),
        );
      }
    }

    // The next match's RSVP, read from the wallet (which reloads after
    // every RSVP) — only nagged in the Player view.
    var rsvpNeeded = false;
    if (playerView && upcoming.isNotEmpty) {
      final walletMatch = wallet?.forMatch(upcoming.first.id);
      rsvpNeeded = walletMatch != null && !walletMatch.answers.containsKey(userId);
    }

    return PendingActions(
      recaps: recaps,
      rsvpNeeded: rsvpNeeded,
      motmVotesNeeded: recaps.where((recap) => recap.needsMotmVote).length,
      feesOwed: owed.length,
    );
  }
}
