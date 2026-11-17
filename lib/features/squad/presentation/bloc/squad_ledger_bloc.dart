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

final class TripSaveRequested extends SquadLedgerEvent {
  const TripSaveRequested(this.draft);

  final TripDraft draft;

  @override
  List<Object?> get props => [draft];
}

/// An admin closes a trip for settling up, or reopens it.
final class TripClosedChanged extends SquadLedgerEvent {
  const TripClosedChanged(this.tripId, {required this.closed});

  final String tripId;
  final bool closed;

  @override
  List<Object?> get props => [tripId, closed];
}

final class RecurringSaveRequested extends SquadLedgerEvent {
  const RecurringSaveRequested(this.draft);

  final RecurringDraft draft;

  @override
  List<Object?> get props => [draft];
}

final class RecurringPausedChanged extends SquadLedgerEvent {
  const RecurringPausedChanged(this.id, {required this.paused});

  final String id;
  final bool paused;

  @override
  List<Object?> get props => [id, paused];
}

final class RecurringDeleteRequested extends SquadLedgerEvent {
  const RecurringDeleteRequested(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
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

/// The receiver got only [receivedCents] of a pending payment (044).
final class SettlementPartlyReceived extends SquadLedgerEvent {
  const SettlementPartlyReceived(this.settlementId, {required this.receivedCents});

  final String settlementId;
  final int receivedCents;

  @override
  List<Object?> get props => [settlementId, receivedCents];
}

/// "I'll pay on …" (044).
final class PaymentPromised extends SquadLedgerEvent {
  const PaymentPromised(this.draft);

  final PromiseDraft draft;

  @override
  List<Object?> get props => [draft];
}

/// Whoever's owed records cash they got, or calls what's left even (044).
final class ReceivedRecorded extends SquadLedgerEvent {
  const ReceivedRecorded(this.draft);

  final ReceivedDraft draft;

  @override
  List<Object?> get props => [draft];
}

/// Your "you owe" reminder day in the squad; null for month end (044).
final class ReminderDayChanged extends SquadLedgerEvent {
  const ReminderDayChanged({required this.teamId, required this.day});

  final String teamId;
  final int? day;

  @override
  List<Object?> get props => [teamId, day];
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
    required this._getSquadLedger,
    required this._saveExpense,
    required this._deleteExpense,
    required this._sendSettlement,
    required this._respondSettlement,
    required this._saveTrip,
    required this._setTripClosed,
    required this._saveRecurring,
    required this._setRecurringPaused,
    required this._deleteRecurring,
    required this._promisePayment,
    required this._recordReceived,
    required this._confirmPartialPayment,
    required this._setReminderDay,
    required TeamChanges teamChanges,
  }) : super(const SquadLedgerLoading()) {
    _serverChanges = TeamChangeWatcher(
      teamChanges,
      tables: const {
        TeamTable.teams,
        TeamTable.teamMembers,
        TeamTable.expenses,
        TeamTable.expensePayers,
        TeamTable.expenseShares,
        TeamTable.settlements,
        TeamTable.squadReminders,
        TeamTable.trips,
        TeamTable.recurringExpenses,
        TeamTable.expenseGuests,
        TeamTable.paymentPromises,
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
    on<TripSaveRequested>((event, emit) => _submit(emit, () => _saveTrip(event.draft)));
    on<TripClosedChanged>(
      (event, emit) =>
          _submit(emit, () => _setTripClosed((tripId: event.tripId, closed: event.closed))),
    );
    on<RecurringSaveRequested>((event, emit) => _submit(emit, () => _saveRecurring(event.draft)));
    on<RecurringPausedChanged>(
      (event, emit) =>
          _submit(emit, () => _setRecurringPaused((id: event.id, paused: event.paused))),
    );
    on<RecurringDeleteRequested>((event, emit) => _submit(emit, () => _deleteRecurring(event.id)));
    on<SettlementSendRequested>((event, emit) => _submit(emit, () => _sendSettlement(event.draft)));
    on<PaymentPromised>((event, emit) => _submit(emit, () => _promisePayment(event.draft)));
    on<ReceivedRecorded>((event, emit) => _submit(emit, () => _recordReceived(event.draft)));
    on<SettlementPartlyReceived>(
      (event, emit) => _submit(
        emit,
        () => _confirmPartialPayment((
          settlementId: event.settlementId,
          receivedCents: event.receivedCents,
        )),
      ),
    );
    on<ReminderDayChanged>(
      (event, emit) => _submit(emit, () => _setReminderDay((teamId: event.teamId, day: event.day))),
    );
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
  final SaveTrip _saveTrip;
  final SetTripClosed _setTripClosed;
  final SaveRecurring _saveRecurring;
  final SetRecurringPaused _setRecurringPaused;
  final DeleteRecurring _deleteRecurring;
  final SendSettlement _sendSettlement;
  final RespondSettlement _respondSettlement;
  final PromisePayment _promisePayment;
  final RecordReceived _recordReceived;
  final ConfirmPartialPayment _confirmPartialPayment;
  final SetReminderDay _setReminderDay;

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
      // Keep what's on screen if a refresh fails; a failed first load stays
      // Loading underneath, so screens show the error (never an empty squad).
      (failure) => emit(
        SquadLedgerFailure(failure.message, switch (state.settled) {
          final SquadLedgerLoaded loaded => loaded,
          _ => const SquadLedgerLoading(),
        }),
      ),
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
