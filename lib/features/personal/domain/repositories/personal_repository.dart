import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../team_membership/domain/entities/team.dart' show GroupCurrency;
import '../entities/personal_expense.dart';

/// A new personal expense ([id] null) or an edit to one.
class PersonalExpenseDraft extends Equatable {
  const PersonalExpenseDraft({
    this.id,
    required this.title,
    required this.amountCents,
    required this.spentAt,
    required this.category,
    this.customCategoryId,
    this.note,
    this.receiptBytes,
    this.receiptExtension,
    this.previousReceiptPath,
    this.removeReceipt = false,
  });

  final String? id;
  final String title;
  final int amountCents;
  final DateTime spentAt;
  final PersonalCategory category;
  final String? customCategoryId;
  final String? note;

  /// A new receipt photo (already compressed), replacing any saved one.
  final Uint8List? receiptBytes;
  final String? receiptExtension;
  final String? previousReceiptPath;

  /// Take the saved receipt off without a new one.
  final bool removeReceipt;

  @override
  List<Object?> get props => [
    id,
    title,
    amountCents,
    spentAt,
    category,
    customCategoryId,
    note,
    receiptBytes,
    receiptExtension,
    previousReceiptPath,
    removeReceipt,
  ];
}

/// Your private spending tracker (supabase/sql/060_personal_expenses.sql).
abstract interface class PersonalRepository {
  /// All your personal expenses, your own categories and your currency.
  Future<Either<Failure, PersonalSpending>> load();

  Future<Either<Failure, Unit>> saveExpense(PersonalExpenseDraft draft);

  /// Deletes it and its receipt photo.
  Future<Either<Failure, Unit>> deleteExpense(PersonalExpense expense);

  /// Adds one of your own categories; returns it.
  Future<Either<Failure, CustomCategory>> addCategory(String name);

  /// Its expenses move to Other.
  Future<Either<Failure, Unit>> deleteCategory(String id);

  Future<Either<Failure, Unit>> setCurrency(GroupCurrency currency);
}
