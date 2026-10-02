import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/expense_comment.dart';
import '../entities/squad_ledger.dart';
import '../entities/squad_member.dart';
import '../repositories/squad_repository.dart';

class GetSquadLedger implements UseCase<SquadLedger, String> {
  const GetSquadLedger(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, SquadLedger>> call(String teamId) => _repository.getLedger(teamId);
}

class SaveExpense implements UseCase<String, ExpenseDraft> {
  const SaveExpense(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, String>> call(ExpenseDraft draft) => _repository.saveExpense(draft);
}

class DeleteExpense implements UseCase<Unit, String> {
  const DeleteExpense(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String expenseId) => _repository.deleteExpense(expenseId);
}

class SendSettlement implements UseCase<Unit, SettlementDraft> {
  const SendSettlement(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SettlementDraft draft) => _repository.sendSettlement(draft);
}

typedef SettlementAnswer = ({String settlementId, bool accept, String? reason});

class RespondSettlement implements UseCase<Unit, SettlementAnswer> {
  const RespondSettlement(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SettlementAnswer answer) => _repository.respondSettlement(
    settlementId: answer.settlementId,
    accept: answer.accept,
    reason: answer.reason,
  );
}

class GetMyBankDetails implements UseCase<BankDetails, NoParams> {
  const GetMyBankDetails(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, BankDetails>> call(NoParams params) => _repository.getMyBankDetails();
}

class SaveMyBankDetails implements UseCase<Unit, BankDetails> {
  const SaveMyBankDetails(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(BankDetails details) => _repository.saveMyBankDetails(details);
}

class GetExpenseComments implements UseCase<List<ExpenseComment>, String> {
  const GetExpenseComments(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, List<ExpenseComment>>> call(String expenseId) =>
      _repository.getComments(expenseId);
}

typedef NewComment = ({String expenseId, String body, String? parentId});

class AddExpenseComment implements UseCase<Unit, NewComment> {
  const AddExpenseComment(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(NewComment comment) => _repository.addComment(
    expenseId: comment.expenseId,
    body: comment.body,
    parentId: comment.parentId,
  );
}

class DeleteExpenseComment implements UseCase<Unit, String> {
  const DeleteExpenseComment(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String commentId) => _repository.deleteComment(commentId);
}
