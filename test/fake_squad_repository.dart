import 'package:dartz/dartz.dart';

import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/comments/domain/entities/comment.dart';
import 'package:squad_hq/features/squad/domain/entities/expense.dart';
import 'package:squad_hq/features/squad/domain/entities/payment_promise.dart';
import 'package:squad_hq/features/squad/domain/entities/recurring_expense.dart';
import 'package:squad_hq/features/squad/domain/entities/settlement.dart';
import 'package:squad_hq/features/squad/domain/entities/squad_ledger.dart';
import 'package:squad_hq/features/squad/domain/entities/squad_member.dart';
import 'package:squad_hq/features/squad/domain/entities/trip.dart';
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
  final comments = <Comment>[];
  final trips = <Trip>[];
  final recurring = <RecurringExpense>[];
  final promises = <PaymentPromise>[];
  BankDetails bank = const BankDetails();

  /// Set to make getLedger fail with this message, as Supabase would.
  String? ledgerError;
  var _nextId = 0;

  void reset() {
    members = [
      // Has a payment QR, as adding an expense needs one.
      SquadMember(
        profileId: userId,
        name: 'Test Player',
        role: TeamRole.superAdmin,
        walletQrPath: '$userId/qr.png',
      ),
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
    trips.clear();
    recurring.clear();
    promises.clear();
    reminded.clear();
    nudged.clear();
    bank = const BankDetails();
    ledgerError = null;
  }

  @override
  Future<Either<Failure, SquadLedger>> getLedger(String teamId) async => ledgerError != null
      ? Left(ServerFailure(ledgerError!))
      : Right(
          SquadLedger(
            currency: GroupCurrency.thb,
            members: List.of(members),
            // Trips' kept apart, as the real data source does.
            expenses: [
              for (final e in expenses.reversed)
                if (e.tripId == null) e,
            ],
            settlements: [
              for (final s in settlements.reversed)
                if (s.tripId == null) s,
            ],
            reminders: [
              for (final (from, to, trip) in reminded)
                if (trip == null) SquadReminder(fromId: from, toId: to, at: DateTime.now()),
            ],
            tripReminders: [
              for (final (from, to, trip) in reminded)
                if (trip != null)
                  SquadReminder(fromId: from, toId: to, at: DateTime.now(), tripId: trip),
            ],
            trips: List.of(trips.reversed),
            recurring: List.of(recurring),
            tripExpenses: [
              for (final e in expenses.reversed)
                if (e.tripId != null) e,
            ],
            tripSettlements: [
              for (final s in settlements.reversed)
                if (s.tripId != null) s,
            ],
            promises: [
              for (final p in promises)
                if (p.tripId == null) p,
            ],
            tripPromises: [
              for (final p in promises)
                if (p.tripId != null) p,
            ],
          ),
        );

  @override
  Future<Either<Failure, String>> saveExpense(ExpenseDraft draft) async {
    final id = draft.id ?? 'expense-${_nextId++}';
    // An edit keeps the expense's trip, as upsert_expense does.
    final previous = expenses.where((e) => e.id == id).firstOrNull;
    final tripId = previous?.tripId ?? draft.tripId;
    final previousReceipt = previous?.receiptPath;
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
        payers: draft.payers,
        shares: draft.shares,
        createdBy: userId,
        note: (draft.note ?? '').isEmpty ? null : draft.note,
        tripId: tripId,
        guests: draft.guests ?? previous?.guests ?? const [],
        categoryLabel: draft.setCategoryLabel ? draft.categoryLabel : previous?.categoryLabel,
        receiptPath: draft.receiptBytes != null
            ? 'receipts/squad-1/$userId/$id.jpg'
            : (draft.removeReceipt ? null : previousReceipt),
      ),
    );
    return Right(id);
  }

  @override
  Future<Either<Failure, String>> saveRecurring(RecurringDraft draft) async {
    final id = draft.id ?? 'recurring-${_nextId++}';
    final existing = recurring.where((r) => r.id == id).firstOrNull;
    recurring
      ..removeWhere((r) => r.id == id)
      ..add(
        RecurringExpense(
          id: id,
          title: draft.title,
          category: draft.category,
          amountCents: draft.amountCents,
          payerId: draft.payerId,
          splitMode: draft.splitMode,
          shares: draft.shares,
          chargeDay: draft.chargeDay,
          startsOn: existing?.startsOn ?? DateTime(draft.startsOn.year, draft.startsOn.month),
          createdBy: existing?.createdBy ?? userId,
          note: draft.note,
          pausedAt: existing?.pausedAt,
          lastMonth: existing?.lastMonth,
          categoryLabel: draft.setCategoryLabel ? draft.categoryLabel : existing?.categoryLabel,
        ),
      );
    _charge(id);
    return Right(id);
  }

  /// generate_recurring_expenses for one: every due month not yet charged.
  void _charge(String id) {
    final index = recurring.indexWhere((r) => r.id == id);
    var rec = recurring[index];
    if (rec.isPaused) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var month = rec.lastMonth == null
        ? rec.startsOn
        : DateTime(rec.lastMonth!.year, rec.lastMonth!.month + 1);
    while (!month.isAfter(DateTime(today.year, today.month)) &&
        !rec.chargeDateIn(month).isAfter(today)) {
      expenses.add(
        Expense(
          id: 'expense-${_nextId++}',
          title:
              '${rec.title} · ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month.month - 1]} ${month.year}',
          category: rec.category,
          amountCents: rec.amountCents,
          spentAt: rec.chargeDateIn(month).add(const Duration(hours: 9)),
          splitMode: rec.splitMode,
          payerId: rec.payerId,
          shares: rec.shares,
          createdBy: rec.payerId,
          recurringId: rec.id,
        ),
      );
      rec = RecurringExpense(
        id: rec.id,
        title: rec.title,
        category: rec.category,
        amountCents: rec.amountCents,
        payerId: rec.payerId,
        splitMode: rec.splitMode,
        shares: rec.shares,
        chargeDay: rec.chargeDay,
        startsOn: rec.startsOn,
        createdBy: rec.createdBy,
        note: rec.note,
        lastMonth: month,
      );
      month = DateTime(month.year, month.month + 1);
    }
    recurring[index] = rec;
  }

  @override
  Future<Either<Failure, Unit>> setRecurringPaused(String id, {required bool paused}) async {
    final index = recurring.indexWhere((r) => r.id == id);
    final rec = recurring[index];
    recurring[index] = RecurringExpense(
      id: rec.id,
      title: rec.title,
      category: rec.category,
      amountCents: rec.amountCents,
      payerId: rec.payerId,
      splitMode: rec.splitMode,
      shares: rec.shares,
      chargeDay: rec.chargeDay,
      startsOn: rec.startsOn,
      createdBy: rec.createdBy,
      note: rec.note,
      pausedAt: paused ? DateTime.now() : null,
      lastMonth: rec.lastMonth,
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> deleteRecurring(String id) async {
    recurring.removeWhere((r) => r.id == id);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, String>> saveTrip(TripDraft draft) async {
    final id = draft.id ?? 'trip-${_nextId++}';
    final existing = trips.where((t) => t.id == id).firstOrNull;
    trips
      ..removeWhere((t) => t.id == id)
      ..add(
        Trip(
          id: id,
          name: draft.name,
          startsOn: draft.startsOn,
          endsOn: draft.endsOn,
          memberIds: draft.memberIds,
          createdBy: existing?.createdBy ?? userId,
          closedAt: existing?.closedAt,
        ),
      );
    return Right(id);
  }

  @override
  Future<Either<Failure, Unit>> setTripClosed(String tripId, {required bool closed}) async {
    final index = trips.indexWhere((t) => t.id == tripId);
    final trip = trips[index];
    trips[index] = Trip(
      id: trip.id,
      name: trip.name,
      startsOn: trip.startsOn,
      endsOn: trip.endsOn,
      memberIds: trip.memberIds,
      createdBy: trip.createdBy,
      closedAt: closed ? DateTime.now() : null,
    );
    return const Right(unit);
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
        tripId: draft.tripId,
      ),
    );
    return const Right(unit);
  }

  /// The signed-in member paid [toId] [ago] — still pending.
  void sentPaymentAgo(String toId, int cents, Duration ago) => settlements.add(
    Settlement(
      id: 'settlement-${_nextId++}',
      fromId: userId,
      toId: toId,
      amountCents: cents,
      method: SettlementMethod.cash,
      status: SettlementStatus.pending,
      createdAt: DateTime.now().subtract(ago),
    ),
  );

  /// Settlement ids nudged with "Remind to confirm".
  final nudged = <String>[];

  @override
  Future<Either<Failure, Unit>> nudgeSettlement(String settlementId) async {
    final index = settlements.indexWhere((s) => s.id == settlementId);
    final s = settlements[index];
    if (s.nudgedToday()) {
      return const Left(ServerFailure('Already reminded today — try again tomorrow'));
    }
    nudged.add(settlementId);
    settlements[index] = Settlement(
      id: s.id,
      fromId: s.fromId,
      toId: s.toId,
      amountCents: s.amountCents,
      method: s.method,
      status: s.status,
      createdAt: s.createdAt,
      nudgedAt: DateTime.now(),
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

  /// (who reminded, who was reminded) — like squad_reminders.
  /// (from, to, trip) — trip null for the squad's own.
  final reminded = <(String, String, String?)>[];

  @override
  Future<Either<Failure, int>> remind({
    required String teamId,
    required Map<String, int> amounts,
    String? tripId,
  }) async {
    // Once a day per person, per trip (or the squad), as remind_to_pay does.
    final targets = [
      for (final MapEntry(key: id, value: cents) in amounts.entries)
        if (id != userId && cents > 0 && !reminded.contains((userId, id, tripId))) id,
    ];
    if (targets.isEmpty) {
      return const Left(ServerFailure('Already reminded today — try again tomorrow'));
    }
    for (final id in targets) {
      reminded.add((userId, id, tripId));
    }
    return Right(targets.length);
  }

  @override
  Future<Either<Failure, List<Comment>>> getComments(String expenseId) async => Right([
    for (final comment in comments)
      if (comment.subjectId == expenseId) comment,
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
      Comment(
        id: 'comment-${_nextId++}',
        subjectId: expenseId,
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
  Future<Either<Failure, Unit>> promisePayment(PromiseDraft draft) async {
    final existing = promises.where(
      (p) => p.fromId == userId && p.toId == draft.toId && p.tripId == draft.tripId,
    );
    if (existing.any((p) => p.isActive())) {
      return const Left(ServerFailure('You already said you’d pay on that day'));
    }
    promises
      ..removeWhere(existing.contains)
      ..add(
        PaymentPromise(
          id: 'promise-${_nextId++}',
          fromId: userId,
          toId: draft.toId,
          promisedOn: DateTime(draft.on.year, draft.on.month, draft.on.day),
          tripId: draft.tripId,
        ),
      );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> recordReceived(ReceivedDraft draft) async {
    settlements.add(
      Settlement(
        id: 'settlement-${_nextId++}',
        fromId: draft.fromId,
        toId: userId,
        amountCents: draft.amountCents,
        method: SettlementMethod.cash,
        status: SettlementStatus.confirmed,
        createdAt: DateTime.now(),
        respondedAt: DateTime.now(),
        tripId: draft.tripId,
        recordedBy: userId,
      ),
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> confirmPartialPayment({
    required String settlementId,
    required int receivedCents,
  }) async {
    final index = settlements.indexWhere((s) => s.id == settlementId);
    final s = settlements[index];
    settlements[index] = Settlement(
      id: s.id,
      fromId: s.fromId,
      toId: s.toId,
      amountCents: receivedCents,
      method: s.method,
      status: SettlementStatus.confirmed,
      createdAt: s.createdAt,
      respondedAt: DateTime.now(),
      tripId: s.tripId,
      sentCents: s.amountCents,
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> setReminderDay({required String teamId, int? day}) async {
    members = [
      for (final m in members)
        if (m.profileId == userId)
          SquadMember(
            profileId: m.profileId,
            name: m.name,
            role: m.role,
            avatarUrl: m.avatarUrl,
            walletQrPath: m.walletQrPath,
            bankName: m.bankName,
            bankAccountName: m.bankAccountName,
            bankAccountNo: m.bankAccountNo,
            reminderDay: day,
          )
        else
          m,
    ];
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
