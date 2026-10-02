import 'package:dartz/dartz.dart';

import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/squad/domain/entities/expense.dart';
import 'package:squad_hq/features/squad/domain/entities/expense_comment.dart';
import 'package:squad_hq/features/squad/domain/entities/settlement.dart';
import 'package:squad_hq/features/squad/domain/entities/squad_ledger.dart';
import 'package:squad_hq/features/squad/domain/entities/squad_member.dart';
import 'package:squad_hq/features/squad/domain/repositories/squad_repository.dart';
import 'package:squad_hq/features/team_membership/domain/entities/team.dart';

/// In-memory [SquadRepository] for one squad. [userId] is the signed-in
/// member; [members] the squad. Call [reset] between tests.
class FakeSquadRepository implements SquadRepository {
  FakeSquadRepository({required this.userId});

  final String userId;

  late List<SquadMember> members;
  final expenses = <Expense>[];
  final settlements = <Settlement>[];
  final comments = <ExpenseComment>[];
  BankDetails bank = const BankDetails();
  var _nextId = 0;

  void reset() {
    members = [
      SquadMember(profileId: userId, name: 'Test Player', role: TeamRole.superAdmin),
      const SquadMember(
        profileId: 'aung',
        name: 'Aung',
        role: TeamRole.player,
        bankName: 'KBank',
        bankAccountName: 'Aung Ko',
        bankAccountNo: '123-4-56789',
      ),
      const SquadMember(profileId: 'ko', name: 'Ko', role: TeamRole.player),
    ];
    expenses.clear();
    settlements.clear();
    comments.clear();
    bank = const BankDetails();
  }

  @override
  Future<Either<Failure, SquadLedger>> getLedger(String teamId) async => Right(
    SquadLedger(
      currency: GroupCurrency.thb,
      members: List.of(members),
      expenses: List.of(expenses.reversed),
      settlements: List.of(settlements.reversed),
    ),
  );

  @override
  Future<Either<Failure, String>> saveExpense(ExpenseDraft draft) async {
    final id = draft.id ?? 'expense-${_nextId++}';
    expenses.removeWhere((expense) => expense.id == id);
    expenses.add(
      Expense(
        id: id,
        title: draft.title,
        category: draft.category,
        amountCents: draft.amountCents,
        spentAt: draft.spentAt ?? DateTime(2026, 9, 27, 20),
        splitMode: draft.splitMode,
        payerId: draft.payerId,
        shares: draft.shares,
        createdBy: userId,
        note: (draft.note ?? '').isEmpty ? null : draft.note,
      ),
    );
    return Right(id);
  }

  @override
  Future<Either<Failure, Unit>> deleteExpense(String expenseId) async {
    expenses.removeWhere((expense) => expense.id == expenseId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> sendSettlement(SettlementDraft draft) async {
    settlements.add(
      Settlement(
        id: 'settlement-${_nextId++}',
        fromId: userId,
        toId: draft.toId,
        amountCents: draft.amountCents,
        method: draft.method,
        status: SettlementStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    return const Right(unit);
  }

  /// [fromId] says they paid the signed-in member.
  void receivePayment(String fromId, int cents) => settlements.add(
    Settlement(
      id: 'settlement-${_nextId++}',
      fromId: fromId,
      toId: userId,
      amountCents: cents,
      method: SettlementMethod.cash,
      status: SettlementStatus.pending,
      createdAt: DateTime.now(),
    ),
  );

  @override
  Future<Either<Failure, Unit>> respondSettlement({
    required String settlementId,
    required bool accept,
    String? reason,
  }) async {
    final index = settlements.indexWhere((s) => s.id == settlementId);
    final s = settlements[index];
    settlements[index] = Settlement(
      id: s.id,
      fromId: s.fromId,
      toId: s.toId,
      amountCents: s.amountCents,
      method: s.method,
      status: accept ? SettlementStatus.confirmed : SettlementStatus.rejected,
      createdAt: s.createdAt,
      rejectReason: reason,
      respondedAt: DateTime.now(),
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<ExpenseComment>>> getComments(String expenseId) async => Right([
    for (final comment in comments)
      if (comment.expenseId == expenseId) comment,
  ]);

  @override
  Future<Either<Failure, Unit>> addComment({
    required String expenseId,
    required String body,
    String? parentId,
  }) async {
    commentAs(userId, expenseId, body, parentId: parentId);
    return const Right(unit);
  }

  /// [authorId] comments, as if on their own phone. Like
  /// add_expense_comment, a reply to a reply joins the top thread.
  void commentAs(String authorId, String expenseId, String body, {String? parentId}) {
    final parent = parentId == null ? null : comments.firstWhere((c) => c.id == parentId);
    comments.add(
      ExpenseComment(
        id: 'comment-${_nextId++}',
        expenseId: expenseId,
        parentId: parent?.parentId ?? parent?.id,
        authorId: authorId,
        body: body,
        createdAt: DateTime.now().add(Duration(milliseconds: _nextId)),
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> deleteComment(String commentId) async {
    comments.removeWhere((c) => c.id == commentId || c.parentId == commentId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, BankDetails>> getMyBankDetails() async => Right(bank);

  @override
  Future<Either<Failure, Unit>> saveMyBankDetails(BankDetails details) async {
    bank = details;
    return const Right(unit);
  }
}
