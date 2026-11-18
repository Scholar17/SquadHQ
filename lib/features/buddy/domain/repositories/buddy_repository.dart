import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../squad/domain/entities/expense.dart' show ExpenseCategory, ExpenseSplitMode;
import '../../../squad/domain/entities/settlement.dart' show SettlementMethod;
import '../entities/buddy.dart';

/// A new buddy expense ([id] null) or an edit to one, from your side.
class BuddyExpenseDraft extends Equatable {
  const BuddyExpenseDraft({
    this.id,
    required this.teamId,
    required this.buddyId,
    required this.payerId,
    required this.title,
    required this.category,
    required this.amountCents,
    required this.splitMode,
    required this.myShareCents,
    required this.buddyShareCents,
    required this.spentAt,
    this.categoryLabel,
    this.myWeight,
    this.buddyWeight,
    this.note,
    this.receiptBytes,
    this.receiptExtension,
    this.removeReceipt = false,
  });

  final String? id;
  final String teamId;
  final String buddyId;
  final String payerId;
  final String title;
  final ExpenseCategory category;
  final String? categoryLabel;
  final int amountCents;
  final ExpenseSplitMode splitMode;
  final int myShareCents;
  final int buddyShareCents;

  /// Percent or shares: the typed weights, in hundredths.
  final int? myWeight;
  final int? buddyWeight;
  final DateTime spentAt;
  final String? note;

  /// A new receipt photo (compressed), replacing any.
  final Uint8List? receiptBytes;
  final String? receiptExtension;
  final bool removeReceipt;

  @override
  List<Object?> get props => [
    id,
    teamId,
    buddyId,
    payerId,
    title,
    category,
    categoryLabel,
    amountCents,
    splitMode,
    myShareCents,
    buddyShareCents,
    myWeight,
    buddyWeight,
    spentAt,
    note,
    receiptBytes,
    receiptExtension,
    removeReceipt,
  ];
}

/// Paying back: [fromId] paid [toId]. Recorded by you as either one.
class BuddyPaymentDraft extends Equatable {
  const BuddyPaymentDraft({
    required this.teamId,
    required this.fromId,
    required this.toId,
    required this.amountCents,
    required this.method,
    this.slipBytes,
    this.slipExtension,
  });

  final String teamId;
  final String fromId;
  final String toId;
  final int amountCents;
  final SettlementMethod method;
  final Uint8List? slipBytes;
  final String? slipExtension;

  @override
  List<Object?> get props => [teamId, fromId, toId, amountCents, method, slipBytes, slipExtension];
}

/// Buddy expenses (supabase/migrations/061_buddy_expenses.sql).
abstract interface class BuddyRepository {
  /// Your buddy expenses and payments in [teamId].
  Future<Either<Failure, BuddyLedger>> load(String teamId);

  Future<Either<Failure, Unit>> saveExpense(BuddyExpenseDraft draft);

  Future<Either<Failure, Unit>> deleteExpense(String id);

  /// "I paid" (pending) when you're [BuddyPaymentDraft.fromId]; "Mark as
  /// received" (confirmed) when you're [BuddyPaymentDraft.toId].
  Future<Either<Failure, Unit>> recordPayment(BuddyPaymentDraft draft);

  /// Confirm or reject an "I paid" sent to you.
  Future<Either<Failure, Unit>> respondToPayment(String id, {required bool confirm, String? reason});

  /// Take back your own pending "I paid".
  Future<Either<Failure, Unit>> cancelPayment(String id);
}
