import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../comments/domain/entities/comment.dart';
import '../entities/expense.dart';
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
    this.payers,
    this.spentAt,
    this.note,
    this.place,
    this.tripId,
    this.receiptBytes,
    this.receiptExtension,
    this.removeReceipt = false,
    this.guests,
    this.categoryLabel,
    this.setCategoryLabel = false,
    this.weights,
  });

  final String? id;
  final String teamId;
  final String title;
  final ExpenseCategory category;
  final int amountCents;
  final ExpenseSplitMode splitMode;

  /// Each member's % or number of shares in hundredths, for a percent or
  /// shares split; [] clears them, null leaves them as they are.
  final Map<String, int>? weights;

  /// Whoever paid the most.
  final String payerId;

  /// Who paid how much when several people did (2 to Expense.maxPayers),
  /// summing to [amountCents]; null = [payerId] paid it all.
  final Map<String, int>? payers;

  /// Computed by ExpenseSplit; sums to [amountCents].
  final Map<String, int> shares;
  final DateTime? spentAt;
  final String? note;
  final String? place;

  /// A new trip expense's trip; an edit keeps the expense's own.
  final String? tripId;

  /// A new proof-of-payment photo to attach (replacing any), already
  /// compressed by the picker.
  final Uint8List? receiptBytes;
  final String? receiptExtension;

  /// Take the expense's current receipt off.
  final bool removeReceipt;

  /// Guests from outside the squad, already folded into [shares]; null =
  /// leave as they are, [] = none.
  final List<ExpenseGuest>? guests;

  /// What "Other" is; saved (null clears it) when [setCategoryLabel].
  final String? categoryLabel;
  final bool setCategoryLabel;

  @override
  List<Object?> get props => [
    id,
    teamId,
    title,
    category,
    amountCents,
    splitMode,
    payerId,
    payers,
    shares,
    spentAt,
    note,
    place,
    tripId,
    receiptBytes,
    receiptExtension,
    removeReceipt,
    guests,
    categoryLabel,
    setCategoryLabel,
    weights,
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
    this.tripId,
  });

  final String teamId;

  /// Paying back a (closed) trip; null for the squad's own.
  final String? tripId;
  final String toId;
  final int amountCents;
  final SettlementMethod method;
  final Uint8List? slipBytes;
  final String? slipExtension;

  @override
  List<Object?> get props => [teamId, toId, amountCents, method, slipBytes, slipExtension, tripId];
}

/// "I'll pay [toId] on [on]" — for a closed trip, or the squad.
class PromiseDraft extends Equatable {
  const PromiseDraft({required this.teamId, required this.toId, required this.on, this.tripId});

  final String teamId;
  final String toId;

  /// The day (time ignored).
  final DateTime on;
  final String? tripId;

  @override
  List<Object?> get props => [teamId, toId, on, tripId];
}

/// Whoever's owed records [amountCents] cash they got from [fromId].
class ReceivedDraft extends Equatable {
  const ReceivedDraft({
    required this.teamId,
    required this.fromId,
    required this.amountCents,
    this.tripId,
  });

  final String teamId;
  final String fromId;
  final int amountCents;
  final String? tripId;

  @override
  List<Object?> get props => [teamId, fromId, amountCents, tripId];
}

/// A new monthly expense ([id] null) or an edit to one (applies from the
/// next charge).
class RecurringDraft extends Equatable {
  const RecurringDraft({
    this.id,
    required this.teamId,
    required this.title,
    required this.category,
    required this.amountCents,
    required this.payerId,
    required this.splitMode,
    required this.shares,
    required this.chargeDay,
    required this.startsOn,
    this.note,
    this.categoryLabel,
    this.setCategoryLabel = false,
    this.weights = const {},
  });

  final String? id;
  final String teamId;
  final String title;
  final ExpenseCategory category;
  final int amountCents;
  final String payerId;
  final ExpenseSplitMode splitMode;
  final Map<String, int> shares;

  /// Each member's % or number of shares in hundredths, for a percent or
  /// shares split.
  final Map<String, int> weights;

  /// 1–28, or RecurringExpense.lastDay.
  final int chargeDay;

  /// The first month to charge (any day in it).
  final DateTime startsOn;
  final String? note;

  /// What "Other" is; saved (null clears it) when [setCategoryLabel].
  final String? categoryLabel;
  final bool setCategoryLabel;

  @override
  List<Object?> get props => [
    id,
    teamId,
    title,
    category,
    amountCents,
    payerId,
    splitMode,
    shares,
    chargeDay,
    startsOn,
    note,
    categoryLabel,
    setCategoryLabel,
    weights,
  ];
}

/// A new trip ([id] null) or an edit to one. Admins only.
class TripDraft extends Equatable {
  const TripDraft({
    this.id,
    required this.teamId,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.memberIds,
  });

  final String? id;
  final String teamId;
  final String name;
  final DateTime startsOn;
  final DateTime endsOn;
  final List<String> memberIds;

  @override
  List<Object?> get props => [id, teamId, name, startsOn, endsOn, memberIds];
}

abstract interface class SquadRepository {
  /// [teamId]'s members, every expense and every settlement.
  Future<Either<Failure, SquadLedger>> getLedger(String teamId);

  /// Saves [draft]; returns the expense id.
  Future<Either<Failure, String>> saveExpense(ExpenseDraft draft);

  Future<Either<Failure, Unit>> deleteExpense(String expenseId);

  /// Saves [draft]; returns the trip id.
  Future<Either<Failure, String>> saveTrip(TripDraft draft);

  /// Closes a trip for settling up, or ([closed] false) reopens it.
  Future<Either<Failure, Unit>> setTripClosed(String tripId, {required bool closed});

  /// Saves [draft] (and charges it if already due); returns its id.
  Future<Either<Failure, String>> saveRecurring(RecurringDraft draft);

  Future<Either<Failure, Unit>> setRecurringPaused(String id, {required bool paused});

  /// Stops it for good; months already charged stay.
  Future<Either<Failure, Unit>> deleteRecurring(String id);

  /// Uploads the slip (if any) and records the payment as pending.
  Future<Either<Failure, Unit>> sendSettlement(SettlementDraft draft);

  /// The receiver's answer: [accept] ("Received"), or a rejection with
  /// [reason].
  Future<Either<Failure, Unit>> respondSettlement({
    required String settlementId,
    required bool accept,
    String? reason,
  });

  /// Reminds [profileIds] who still owe (null = everyone owing) — once a
  /// day each. Returns how many were reminded.
  /// "Remind to pay": nudges each person in [amounts] about what they owe
  /// the caller (for [tripId], or the squad) — once a day each. Returns how
  /// many were reminded.
  Future<Either<Failure, int>> remind({
    required String teamId,
    required Map<String, int> amounts,
    String? tripId,
  });

  /// "Remind to confirm": the payer nudges the receiver of a payment that's
  /// been pending a day or more — once a day.
  Future<Either<Failure, Unit>> nudgeSettlement(String settlementId);

  /// "I'll pay on …": one date ahead at a time; reminders wait till then.
  Future<Either<Failure, Unit>> promisePayment(PromiseDraft draft);

  /// Cash received in hand — confirmed straight away.
  Future<Either<Failure, Unit>> recordReceived(ReceivedDraft draft);

  /// The receiver got only [receivedCents] of a pending payment: confirmed
  /// for that; the rest still counts as owed.
  Future<Either<Failure, Unit>> confirmPartialPayment({
    required String settlementId,
    required int receivedCents,
  });

  /// Your "you owe" reminder day in [teamId] (1–28), or null for month end.
  Future<Either<Failure, Unit>> setReminderDay({required String teamId, int? day});

  /// Every comment on [expenseId], oldest first.
  Future<Either<Failure, List<Comment>>> getComments(String expenseId);

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
