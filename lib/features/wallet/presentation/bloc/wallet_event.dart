import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../domain/entities/team_wallet.dart';

sealed class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

/// Fired whenever the active team changes (including to/from no team).
final class WalletTeamSelected extends WalletEvent {
  const WalletTeamSelected(this.teamId);

  final String? teamId;

  @override
  List<Object?> get props => [teamId];
}

/// Reloads quietly (no spinner) — e.g. after an RSVP changes who an
/// "In" split includes, or a match is edited or cancelled.
final class WalletRefreshRequested extends WalletEvent {
  const WalletRefreshRequested({this.done});

  /// Completed once the reload finishes — for pull-to-refresh, since an
  /// unchanged wallet emits no new state to wait on.
  final Completer<void>? done;

  @override
  List<Object?> get props => [done];
}

final class WalletBillSaveRequested extends WalletEvent {
  const WalletBillSaveRequested({
    required this.matchId,
    required this.totalCost,
    required this.splitMode,
    this.memberIds = const {},
  });

  final String matchId;
  final double totalCost;
  final SplitMode splitMode;
  final Set<String> memberIds;

  @override
  List<Object?> get props => [matchId, totalCost, splitMode, memberIds];
}

/// "Remind unpaid" on a bill — [profileIds], or everyone still owing if
/// null. Once per day per player.
final class WalletRemindUnpaidRequested extends WalletEvent {
  const WalletRemindUnpaidRequested(this.matchId, {this.profileIds});

  final String matchId;
  final Set<String>? profileIds;

  @override
  List<Object?> get props => [matchId, profileIds];
}

final class WalletPaymentSubmitted extends WalletEvent {
  const WalletPaymentSubmitted({
    required this.matchId,
    required this.slipBytes,
    required this.fileExtension,
  });

  final String matchId;
  final Uint8List slipBytes;
  final String fileExtension;

  @override
  List<Object?> get props => [matchId, slipBytes, fileExtension];
}
