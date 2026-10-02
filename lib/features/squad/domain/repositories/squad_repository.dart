import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../entities/expense.dart';
import '../entities/expense_comment.dart';
import '../entities/settlement.dart';
import '../entities/squad_ledger.dart';
import '../entities/squad_member.dart';

/// A new expense ([id] null) or an edit to one.
class ExpenseDraft extends Equatable {
  const ExpenseDraft({
    this.id,
    required this.teamId,
    required this.title,
    required this.category,
    required this.amountCents,
    required this.splitMode,
    required this.payerId,
    required this.shares,
    this.spentAt,
    this.note,
    this.place,
  });

  final String? id;
  final String teamId;
  final String title;
  final ExpenseCategory category;
  final int amountCents;
  final ExpenseSplitMode splitMode;
  final String payerId;

  /// Computed by ExpenseSplit; sums to [amountCents].
  final Map<String, int> shares;
  final DateTime? spentAt;
  final String? note;
  final String? place;

  @override
  List<Object?> get props => [
    id,
    teamId,
    title,
    category,
    amountCents,
    splitMode,
    payerId,
    shares,
    spentAt,
    note,
    place,
  ];
}

/// The caller paying [toId] back. QR and bank payments carry a slip.
class SettlementDraft extends Equatable {
  const SettlementDraft({
    required this.teamId,
    required this.toId,
    required this.amountCents,
    required this.method,
    this.slipBytes,
    this.slipExtension,
  });

  final String teamId;
  final String toId;
  final int amountCents;
  final SettlementMethod method;
  final Uint8List? slipBytes;
  final String? slipExtension;

  @override
  List<Object?> get props => [teamId, toId, amountCents, method, slipBytes, slipExtension];
}

abstract interface class SquadRepository {
  /// [teamId]'s members, every expense and every settlement.
  Future<Either<Failure, SquadLedger>> getLedger(String teamId);

  /// Saves [draft]; returns the expense id.
  Future<Either<Failure, String>> saveExpense(ExpenseDraft draft);

  Future<Either<Failure, Unit>> deleteExpense(String expenseId);

  /// Uploads the slip (if any) and records the payment as pending.
  Future<Either<Failure, Unit>> sendSettlement(SettlementDraft draft);

  /// The receiver's answer: [accept] ("Received"), or a rejection with
  /// [reason].
  Future<Either<Failure, Unit>> respondSettlement({
    required String settlementId,
    required bool accept,
    String? reason,
  });

  /// Every comment on [expenseId], oldest first.
  Future<Either<Failure, List<ExpenseComment>>> getComments(String expenseId);

  /// Comments on [expenseId], or replies to [parentId].
  Future<Either<Failure, Unit>> addComment({
    required String expenseId,
    required String body,
    String? parentId,
  });

  /// The author or an admin; a top-level comment takes its replies.
  Future<Either<Failure, Unit>> deleteComment(String commentId);

  Future<Either<Failure, BankDetails>> getMyBankDetails();

  Future<Either<Failure, Unit>> saveMyBankDetails(BankDetails details);
}
