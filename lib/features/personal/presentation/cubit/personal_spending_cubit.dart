import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../team_membership/domain/entities/team.dart' show GroupCurrency;
import '../../domain/entities/personal_expense.dart';
import '../../domain/repositories/personal_repository.dart';

class PersonalSpendingState extends Equatable {
  const PersonalSpendingState({
    this.spending,
    this.loading = false,
    this.saving = false,
    this.error,
    this.savedAt,
  });

  /// Null until the first load.
  final PersonalSpending? spending;
  final bool loading;

  /// A save or delete is on its way.
  final bool saving;

  /// The last thing that went wrong, to show once.
  final String? error;

  /// Bumped after each save, so a sheet knows it can close.
  final DateTime? savedAt;

  PersonalSpendingState copyWith({
    PersonalSpending? spending,
    bool? loading,
    bool? saving,
    String? error,
    DateTime? savedAt,
  }) => PersonalSpendingState(
    spending: spending ?? this.spending,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: error,
    savedAt: savedAt ?? this.savedAt,
  );

  @override
  List<Object?> get props => [spending, loading, saving, error, savedAt];
}

/// Loads your personal spending and saves changes to it, reloading after
/// each so the page always shows what's stored.
class PersonalSpendingCubit extends Cubit<PersonalSpendingState> {
  PersonalSpendingCubit(this._repository) : super(const PersonalSpendingState());

  final PersonalRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final result = await _repository.load();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(loading: false, error: failure.message)),
      (spending) => emit(state.copyWith(loading: false, spending: spending)),
    );
  }

  /// Runs [action]; on success reloads and marks it saved. Returns whether
  /// it worked.
  Future<bool> _change(Future<Either<Failure, Object?>> Function() action) async {
    emit(state.copyWith(saving: true));
    final result = await action();
    if (isClosed) return false;
    if (result case Left(value: final failure)) {
      emit(state.copyWith(saving: false, error: failure.message));
      return false;
    }
    final reloaded = await _repository.load();
    if (isClosed) return true;
    emit(
      state.copyWith(
        saving: false,
        spending: reloaded.fold((_) => null, (spending) => spending),
        savedAt: DateTime.now(),
      ),
    );
    return true;
  }

  Future<bool> save(PersonalExpenseDraft draft) => _change(() => _repository.saveExpense(draft));

  Future<bool> delete(PersonalExpense expense) => _change(() => _repository.deleteExpense(expense));

  Future<bool> deleteCategory(String id) => _change(() => _repository.deleteCategory(id));

  Future<bool> setCurrency(GroupCurrency currency) => _change(() => _repository.setCurrency(currency));

  /// Adds one of your own categories and returns it (null if it failed).
  Future<CustomCategory?> addCategory(String name) async {
    final result = await _repository.addCategory(name);
    if (isClosed) return null;
    return result.fold(
      (failure) {
        emit(state.copyWith(error: failure.message));
        return null;
      },
      (category) {
        final spending = state.spending ?? PersonalSpending.empty;
        emit(
          state.copyWith(
            spending: PersonalSpending(
              expenses: spending.expenses,
              categories: [...spending.categories, category]
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
              currency: spending.currency,
            ),
          ),
        );
        return category;
      },
    );
  }
}
