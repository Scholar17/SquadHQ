import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/buddy.dart';
import '../../domain/repositories/buddy_repository.dart';

class BuddyState extends Equatable {
  const BuddyState({this.teamId, this.ledger, this.loading = false, this.saving = false, this.error});

  /// The squad [ledger] is for.
  final String? teamId;
  final BuddyLedger? ledger;
  final bool loading;
  final bool saving;

  /// The last thing that went wrong, to show once.
  final String? error;

  BuddyState copyWith({
    String? teamId,
    BuddyLedger? ledger,
    bool? loading,
    bool? saving,
    String? error,
    bool clearLedger = false,
  }) => BuddyState(
    teamId: teamId ?? this.teamId,
    ledger: clearLedger ? null : ledger ?? this.ledger,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: error,
  );

  @override
  List<Object?> get props => [teamId, ledger, loading, saving, error];
}

/// The active squad's buddy expenses and payments; reloads after each
/// change. Shared app-wide like the squad's own ledger.
class BuddyCubit extends Cubit<BuddyState> {
  BuddyCubit(this._repository) : super(const BuddyState());

  final BuddyRepository _repository;

  /// Loads [teamId]'s; switching squads drops the other one's first.
  Future<void> load(String teamId) async {
    emit(state.copyWith(teamId: teamId, loading: true, clearLedger: state.teamId != teamId));
    final result = await _repository.load(teamId);
    if (isClosed || state.teamId != teamId) return;
    result.fold(
      (failure) => emit(state.copyWith(loading: false, error: failure.message)),
      (ledger) => emit(state.copyWith(loading: false, ledger: ledger)),
    );
  }

  Future<bool> _change(Future<Either<Failure, Unit>> Function() action) async {
    final teamId = state.teamId;
    emit(state.copyWith(saving: true));
    final result = await action();
    if (isClosed) return false;
    if (result case Left(value: final failure)) {
      emit(state.copyWith(saving: false, error: failure.message));
      return false;
    }
    emit(state.copyWith(saving: false));
    if (teamId != null) await load(teamId);
    return true;
  }

  Future<bool> save(BuddyExpenseDraft draft) => _change(() => _repository.saveExpense(draft));

  Future<bool> delete(String id) => _change(() => _repository.deleteExpense(id));

  Future<bool> pay(BuddyPaymentDraft draft) => _change(() => _repository.recordPayment(draft));

  Future<bool> respond(String id, {required bool confirm, String? reason}) =>
      _change(() => _repository.respondToPayment(id, confirm: confirm, reason: reason));

  Future<bool> cancel(String id) => _change(() => _repository.cancelPayment(id));
}
