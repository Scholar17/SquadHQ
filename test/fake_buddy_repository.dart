import 'package:dartz/dartz.dart';

import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/buddy/domain/entities/buddy.dart';
import 'package:squad_hq/features/buddy/domain/repositories/buddy_repository.dart';
import 'package:squad_hq/features/squad/domain/entities/settlement.dart';

/// In-memory buddy expenses for [userId], like the live tables (061).
class FakeBuddyRepository implements BuddyRepository {
  FakeBuddyRepository({required this.userId});

  final String userId;
  final expenses = <BuddyExpense>[];
  final settlements = <BuddySettlement>[];
  var _nextId = 1;

  void reset() {
    expenses.clear();
    settlements.clear();
    _nextId = 1;
  }

  @override
  Future<Either<Failure, BuddyLedger>> load(String teamId) async => Right(
    BuddyLedger(
      me: userId,
      expenses: [...expenses]..sort((a, b) => b.spentAt.compareTo(a.spentAt)),
      settlements: [...settlements]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    ),
  );

  @override
  Future<Either<Failure, Unit>> saveExpense(BuddyExpenseDraft draft) async {
    if (draft.myShareCents + draft.buddyShareCents != draft.amountCents) {
      return const Left(ServerFailure('Shares must add up'));
    }
    final id = draft.id ?? 'buddy-${_nextId++}';
    final previous = expenses.where((e) => e.id == id).firstOrNull;
    expenses
      ..removeWhere((e) => e.id == id)
      ..add(
        BuddyExpense(
          id: id,
          buddyId: draft.buddyId,
          payerId: draft.payerId,
          title: draft.title,
          category: draft.category,
          categoryLabel: draft.categoryLabel,
          amountCents: draft.amountCents,
          splitMode: draft.splitMode,
          myShareCents: draft.myShareCents,
          buddyShareCents: draft.buddyShareCents,
          myWeight: draft.myWeight,
          buddyWeight: draft.buddyWeight,
          spentAt: draft.spentAt,
          note: (draft.note ?? '').trim().isEmpty ? null : draft.note!.trim(),
          receiptPath: draft.receiptBytes != null
              ? 'buddy/squad-1/$userId/$id.jpg'
              : (draft.removeReceipt ? null : previous?.receiptPath),
          createdBy: previous?.createdBy ?? userId,
          updatedAt: DateTime.now(),
        ),
      );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> recordPayment(BuddyPaymentDraft draft) async {
    final received = draft.toId == userId;
    settlements.add(
      BuddySettlement(
        id: 'pay-${_nextId++}',
        fromId: draft.fromId,
        toId: draft.toId,
        amountCents: draft.amountCents,
        method: draft.method,
        status: received ? SettlementStatus.confirmed : SettlementStatus.pending,
        recordedBy: userId,
        createdAt: DateTime.now(),
      ),
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> respondToPayment(String id, {required bool confirm, String? reason}) async {
    final index = settlements.indexWhere((s) => s.id == id);
    final s = settlements[index];
    settlements[index] = BuddySettlement(
      id: s.id,
      fromId: s.fromId,
      toId: s.toId,
      amountCents: s.amountCents,
      method: s.method,
      status: confirm ? SettlementStatus.confirmed : SettlementStatus.rejected,
      recordedBy: s.recordedBy,
      createdAt: s.createdAt,
      rejectReason: confirm ? null : reason,
    );
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> cancelPayment(String id) async {
    settlements.removeWhere((s) => s.id == id);
    return const Right(unit);
  }
}
