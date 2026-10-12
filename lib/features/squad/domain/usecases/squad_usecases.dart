import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../comments/domain/entities/comment.dart';
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

class SaveTrip implements UseCase<String, TripDraft> {
  const SaveTrip(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, String>> call(TripDraft draft) => _repository.saveTrip(draft);
}

typedef TripClosing = ({String tripId, bool closed});

class SetTripClosed implements UseCase<Unit, TripClosing> {
  const SetTripClosed(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(TripClosing params) =>
      _repository.setTripClosed(params.tripId, closed: params.closed);
}

class SaveRecurring implements UseCase<String, RecurringDraft> {
  const SaveRecurring(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, String>> call(RecurringDraft draft) => _repository.saveRecurring(draft);
}

typedef RecurringPausing = ({String id, bool paused});

class SetRecurringPaused implements UseCase<Unit, RecurringPausing> {
  const SetRecurringPaused(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(RecurringPausing params) =>
      _repository.setRecurringPaused(params.id, paused: params.paused);
}

class DeleteRecurring implements UseCase<Unit, String> {
  const DeleteRecurring(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String id) => _repository.deleteRecurring(id);
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

class PromisePayment implements UseCase<Unit, PromiseDraft> {
  const PromisePayment(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(PromiseDraft draft) => _repository.promisePayment(draft);
}

class RecordReceived implements UseCase<Unit, ReceivedDraft> {
  const RecordReceived(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(ReceivedDraft draft) => _repository.recordReceived(draft);
}

typedef PartialReceipt = ({String settlementId, int receivedCents});

class ConfirmPartialPayment implements UseCase<Unit, PartialReceipt> {
  const ConfirmPartialPayment(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(PartialReceipt receipt) => _repository.confirmPartialPayment(
    settlementId: receipt.settlementId,
    receivedCents: receipt.receivedCents,
  );
}

typedef ReminderDay = ({String teamId, int? day});

class SetReminderDay implements UseCase<Unit, ReminderDay> {
  const SetReminderDay(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(ReminderDay params) =>
      _repository.setReminderDay(teamId: params.teamId, day: params.day);
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

class GetExpenseComments implements UseCase<List<Comment>, String> {
  const GetExpenseComments(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, List<Comment>>> call(String expenseId) =>
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

/// Who to remind and what each owes the caller, for [tripId] or the squad.
typedef ReminderRequest = ({String teamId, Map<String, int> amounts, String? tripId});

class RemindToPay implements UseCase<int, ReminderRequest> {
  const RemindToPay(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, int>> call(ReminderRequest request) =>
      _repository.remind(teamId: request.teamId, amounts: request.amounts, tripId: request.tripId);
}

class NudgeSettlement implements UseCase<Unit, String> {
  const NudgeSettlement(this._repository);

  final SquadRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String settlementId) =>
      _repository.nudgeSettlement(settlementId);
}
