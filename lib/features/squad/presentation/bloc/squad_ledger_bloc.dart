import 'dart:async';

import 'package:dartz/dartz.dart' show Either;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/realtime/team_changes.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/repositories/squad_repository.dart';
import '../../domain/usecases/squad_usecases.dart';

sealed class SquadLedgerEvent extends Equatable {
  const SquadLedgerEvent();

  @override
  List<Object?> get props => [];
}

/// The active group changed: [teamId] is the squad to show, or null when
/// the active group is a football team (or there's none).
final class SquadSelected extends SquadLedgerEvent {
  const SquadSelected(this.teamId);

  final String? teamId;

  @override
  List<Object?> get props => [teamId];
}

/// Reloads quietly — a squad-mate's change arrived, or pull-to-refresh.
final class SquadRefreshRequested extends SquadLedgerEvent {
  const SquadRefreshRequested({this.done});

  /// Completed once the reload finishes — for pull-to-refresh, since an
  /// unchanged ledger emits no new state to wait on.
  final Completer<void>? done;

  @override
  List<Object?> get props => [done];
}

final class ExpenseSaveRequested extends SquadLedgerEvent {
  const ExpenseSaveRequested(this.draft);

  final ExpenseDraft draft;

  @override
  List<Object?> get props => [draft];
}

final class ExpenseDeleteRequested extends SquadLedgerEvent {
  const ExpenseDeleteRequested(this.expenseId);

  final String expenseId;

  @override
  List<Object?> get props => [expenseId];
}

final class SettlementSendRequested extends SquadLedgerEvent {
  const SettlementSendRequested(this.draft);

  final SettlementDraft draft;

  @override
  List<Object?> get props => [draft];
}

/// The receiver's "Received" ([accept]) or "Send back" with [reason].
final class SettlementAnswered extends SquadLedgerEvent {
  const SettlementAnswered(this.settlementId, {required this.accept, this.reason});

  final String settlementId;
  final bool accept;
  final String? reason;

  @override
  List<Object?> get props => [settlementId, accept, reason];
}

sealed class SquadLedgerState extends Equatable {
  const SquadLedgerState();

  @override
  List<Object?> get props => [];
}

final class SquadLedgerLoading extends SquadLedgerState {
  const SquadLedgerLoading();
}

/// [SquadLedger.empty] when the active group isn't a squad.
final class SquadLedgerLoaded extends SquadLedgerState {
  const SquadLedgerLoaded(this.ledger);

  final SquadLedger ledger;

  @override
  List<Object?> get props => [ledger];
}

/// A save is in flight; [previous] is what to fall back to.
final class SquadLedgerSubmitting extends SquadLedgerState {
  const SquadLedgerSubmitting(this.previous);

  final SquadLedgerState previous;

  @override
  List<Object?> get props => [previous];
}

final class SquadLedgerFailure extends SquadLedgerState {
  const SquadLedgerFailure(this.message, this.previous);

  final String message;
  final SquadLedgerState previous;

  @override
  List<Object?> get props => [message, previous];
}

extension SquadLedgerStateX on SquadLedgerState {
  /// Unwraps Submitting/Failure — those never nest.
  SquadLedgerState get settled => switch (this) {
    SquadLedgerSubmitting(:final previous) || SquadLedgerFailure(:final previous) => previous,
    final state => state,
  };

  SquadLedger? get ledger => switch (settled) {
    SquadLedgerLoaded(:final ledger) => ledger,
    _ => null,
  };
}

/// Singleton, provided at the app root (see app.dart) like WalletBloc: the
/// four squad tabs and the expense, pay and confirm sheets share it.
class SquadLedgerBloc extends Bloc<SquadLedgerEvent, SquadLedgerState> {
  SquadLedgerBloc({
    required GetSquadLedger getSquadLedger,
    required SaveExpense saveExpense,
    required DeleteExpense deleteExpense,
    required SendSettlement sendSettlement,
    required RespondSettlement respondSettlement,
    required TeamChanges teamChanges,
  }) : _getSquadLedger = getSquadLedger,
       _saveExpense = saveExpense,
       _deleteExpense = deleteExpense,
       _sendSettlement = sendSettlement,
       _respondSettlement = respondSettlement,
       super(const SquadLedgerLoading()) {
    _serverChanges = TeamChangeWatcher(
      teamChanges,
      tables: const {
        TeamTable.teams,
        TeamTable.teamMembers,
        TeamTable.expenses,
        TeamTable.expensePayers,
        TeamTable.expenseShares,
        TeamTable.settlements,
      },
      onChange: () {
        if (!isClosed) add(const SquadRefreshRequested());
      },
    );
    on<SquadSelected>(_onSelected);
    on<SquadRefreshRequested>((event, emit) async {
      try {
        await _reload(emit);
      } finally {
        event.done?.complete();
      }
    });
    on<ExpenseSaveRequested>((event, emit) => _submit(emit, () => _saveExpense(event.draft)));
    on<ExpenseDeleteRequested>(
      (event, emit) => _submit(emit, () => _deleteExpense(event.expenseId)),
    );
    on<SettlementSendRequested>((event, emit) => _submit(emit, () => _sendSettlement(event.draft)));
    on<SettlementAnswered>(
      (event, emit) => _submit(
        emit,
        () => _respondSettlement((
          settlementId: event.settlementId,
          accept: event.accept,
          reason: event.reason,
        )),
      ),
    );
  }

  final GetSquadLedger _getSquadLedger;
  final SaveExpense _saveExpense;
  final DeleteExpense _deleteExpense;
  final SendSettlement _sendSettlement;
  final RespondSettlement _respondSettlement;

  /// Reloads when a squad-mate adds an expense, pays or confirms.
  late final TeamChangeWatcher _serverChanges;

  String? _teamId;

  @override
  Future<void> close() async {
    await _serverChanges.cancel();
    return super.close();
  }

  Future<void> _reload(Emitter<SquadLedgerState> emit) async {
    final teamId = _teamId;
    if (teamId == null) {
      emit(const SquadLedgerLoaded(SquadLedger.empty));
      return;
    }
    final result = await _getSquadLedger(teamId);
    // A switch may have happened while loading.
    if (teamId != _teamId) return;
    result.fold(
      (failure) =>
          emit(SquadLedgerFailure(failure.message, const SquadLedgerLoaded(SquadLedger.empty))),
      (ledger) => emit(SquadLedgerLoaded(ledger)),
    );
  }

  Future<void> _onSelected(SquadSelected event, Emitter<SquadLedgerState> emit) async {
    _serverChanges.watch(event.teamId);
    _teamId = event.teamId;
    emit(const SquadLedgerLoading());
    await _reload(emit);
  }

  Future<void> _submit(
    Emitter<SquadLedgerState> emit,
    Future<Either<Failure, Object?>> Function() action,
  ) async {
    final fallback = state.settled;
    emit(SquadLedgerSubmitting(fallback));
    final result = await action();
    await result.fold(
      (failure) async => emit(SquadLedgerFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }
}
