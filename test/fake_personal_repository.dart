import 'package:dartz/dartz.dart';

import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/personal/domain/entities/personal_expense.dart';
import 'package:squad_hq/features/personal/domain/repositories/personal_repository.dart';
import 'package:squad_hq/features/team_membership/domain/entities/team.dart';

/// In-memory personal spending, like the live tables (060).
class FakePersonalRepository implements PersonalRepository {
  final expenses = <PersonalExpense>[];
  final categories = <CustomCategory>[];
  GroupCurrency currency = GroupCurrency.thb;
  var _nextId = 1;

  void reset() {
    expenses.clear();
    categories.clear();
    currency = GroupCurrency.thb;
    _nextId = 1;
  }

  @override
  Future<Either<Failure, PersonalSpending>> load() async => Right(
    PersonalSpending(
      expenses: [...expenses]..sort((a, b) => b.spentAt.compareTo(a.spentAt)),
      categories: [...categories],
      currency: currency,
    ),
  );

  @override
  Future<Either<Failure, Unit>> saveExpense(PersonalExpenseDraft draft) async {
    final id = draft.id ?? 'personal-${_nextId++}';
    expenses
      ..removeWhere((e) => e.id == id)
      ..add(
        PersonalExpense(
          id: id,
          title: draft.title,
          amountCents: draft.amountCents,
          spentAt: draft.spentAt,
          category: draft.category,
          customCategoryId: draft.customCategoryId,
          note: (draft.note ?? '').trim().isEmpty ? null : draft.note!.trim(),
          receiptPath: draft.receiptBytes != null
              ? 'personal/test-1/$id.jpg'
              : (draft.removeReceipt ? null : draft.previousReceiptPath),
        ),
      );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> deleteExpense(PersonalExpense expense) async {
    expenses.removeWhere((e) => e.id == expense.id);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, CustomCategory>> addCategory(String name) async {
    if (categories.any((c) => c.name.toLowerCase() == name.trim().toLowerCase())) {
      return const Left(ServerFailure('You already have a category with that name'));
    }
    final category = CustomCategory(id: 'cat-${_nextId++}', name: name.trim());
    categories.add(category);
    return Right(category);
  }

  @override
  Future<Either<Failure, Unit>> deleteCategory(String id) async {
    categories.removeWhere((c) => c.id == id);
    for (final (index, expense) in expenses.indexed.toList()) {
      if (expense.customCategoryId == id) {
        expenses[index] = PersonalExpense(
          id: expense.id,
          title: expense.title,
          amountCents: expense.amountCents,
          spentAt: expense.spentAt,
          category: PersonalCategory.custom,
          note: expense.note,
          receiptPath: expense.receiptPath,
        );
      }
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> setCurrency(GroupCurrency currency) async {
    this.currency = currency;
    return const Right(unit);
  }
}
