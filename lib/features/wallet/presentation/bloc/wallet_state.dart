import 'package:equatable/equatable.dart';

import '../../domain/entities/team_wallet.dart';

sealed class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

final class WalletLoading extends WalletState {
  const WalletLoading();
}

/// [TeamWallet.empty] when there's no active team.
final class WalletLoaded extends WalletState {
  const WalletLoaded(this.wallet);

  final TeamWallet wallet;

  @override
  List<Object?> get props => [wallet];
}

/// A bill save or payment is in flight; [previous] is what to fall back
/// to (always [WalletLoaded] in practice).
final class WalletSubmitting extends WalletState {
  const WalletSubmitting(this.previous);

  final WalletState previous;

  @override
  List<Object?> get props => [previous];
}

final class WalletFailure extends WalletState {
  const WalletFailure(this.message, this.previous);

  final String message;
  final WalletState previous;

  @override
  List<Object?> get props => [message, previous];
}

extension WalletStateX on WalletState {
  /// Unwraps Submitting/Failure — those never nest (see WalletBloc).
  WalletState get settled => switch (this) {
        WalletSubmitting(:final previous) => previous,
        WalletFailure(:final previous) => previous,
        _ => this,
      };

  /// The loaded wallet, or null while it's still loading.
  TeamWallet? get wallet => switch (settled) {
        WalletLoaded(:final wallet) => wallet,
        _ => null,
      };
}
