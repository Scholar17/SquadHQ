import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_messages.dart';
import '../../../core/error/failures.dart';
import '../../squad/domain/entities/expense.dart' show ExpenseCategory, ExpenseSplitMode;
import '../../squad/domain/entities/settlement.dart' show SettlementMethod, SettlementStatus;
import '../domain/entities/buddy.dart';
import '../domain/repositories/buddy_repository.dart';

/// Photos share the private payment-slips bucket, under
/// `buddy/<team id>/<uploader id>/` (061).
const _bucket = 'payment-slips';

int _cents(Object? value) => ((value as num) * 100).round();

int? _maybeCents(Object? value) => value == null ? null : _cents(value);

double _units(int cents) => cents / 100;

double? _maybeUnits(int? cents) => cents == null ? null : _units(cents);

class BuddyRepositoryImpl implements BuddyRepository {
  BuddyRepositoryImpl({required SupabaseClient supabaseClient}) : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  String get _userId {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('You are signed out');
    return userId;
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } on StorageException catch (e) {
      return Left(ServerFailure('Could not upload the photo: ${e.message}'));
    } on StateError catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  static BuddyExpense _expense(Map<String, dynamic> row, String me) {
    final meIsA = row['person_a'] == me;
    return BuddyExpense(
      id: row['id'] as String,
      buddyId: (meIsA ? row['person_b'] : row['person_a']) as String,
      payerId: row['payer_id'] as String,
      title: row['title'] as String,
      category: ExpenseCategory.values.asNameMap()[row['category']] ?? ExpenseCategory.other,
      categoryLabel: row['category_label'] as String?,
      amountCents: _cents(row['amount']),
      splitMode: ExpenseSplitMode.values.asNameMap()[row['split_mode']] ?? ExpenseSplitMode.custom,
      myShareCents: _cents(meIsA ? row['share_a'] : row['share_b']),
      buddyShareCents: _cents(meIsA ? row['share_b'] : row['share_a']),
      myWeight: _maybeCents(meIsA ? row['weight_a'] : row['weight_b']),
      buddyWeight: _maybeCents(meIsA ? row['weight_b'] : row['weight_a']),
      spentAt: DateTime.parse(row['spent_at'] as String),
      note: row['note'] as String?,
      receiptPath: row['receipt_path'] as String?,
      createdBy: row['created_by'] as String,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  static BuddySettlement _settlement(Map<String, dynamic> row) => BuddySettlement(
    id: row['id'] as String,
    fromId: row['from_id'] as String,
    toId: row['to_id'] as String,
    amountCents: _cents(row['amount']),
    method: SettlementMethod.values.asNameMap()[row['method']] ?? SettlementMethod.cash,
    status: SettlementStatus.values.asNameMap()[row['status']] ?? SettlementStatus.pending,
    recordedBy: row['recorded_by'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    slipPath: row['slip_path'] as String?,
    rejectReason: row['reject_reason'] as String?,
  );

  @override
  Future<Either<Failure, BuddyLedger>> load(String teamId) => _guard(() async {
    final me = _userId;
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _supabase
          .from('buddy_expenses')
          .select()
          .eq('team_id', teamId)
          .order('spent_at', ascending: false),
      _supabase
          .from('buddy_settlements')
          .select()
          .eq('team_id', teamId)
          .order('created_at', ascending: false),
    ]);
    return BuddyLedger(
      me: me,
      expenses: [for (final row in results[0]) _expense(row, me)],
      settlements: [for (final row in results[1]) _settlement(row)],
    );
  });

  Future<String> _upload(String teamId, Uint8List bytes, String? extension) async {
    final ext = extension ?? 'jpg';
    final path = 'buddy/$teamId/$_userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _supabase.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg'),
        );
    return path;
  }

  @override
  Future<Either<Failure, Unit>> saveExpense(BuddyExpenseDraft draft) => _guard(() async {
    final note = draft.note?.trim();
    final id = await _supabase.rpc(
      'save_buddy_expense',
      params: {
        'p_id': draft.id,
        'p_team_id': draft.teamId,
        'p_buddy': draft.buddyId,
        'p_payer': draft.payerId,
        'p_title': draft.title.trim(),
        'p_category': draft.category.name,
        'p_category_label': draft.categoryLabel,
        'p_amount': _units(draft.amountCents),
        'p_split_mode': draft.splitMode.name,
        'p_share_me': _units(draft.myShareCents),
        'p_share_buddy': _units(draft.buddyShareCents),
        'p_weight_me': _maybeUnits(draft.myWeight),
        'p_weight_buddy': _maybeUnits(draft.buddyWeight),
        'p_spent_at': draft.spentAt.toUtc().toIso8601String(),
        'p_note': note == null || note.isEmpty ? null : note,
      },
    );
    final bytes = draft.receiptBytes;
    if (bytes != null) {
      final path = await _upload(draft.teamId, bytes, draft.receiptExtension);
      await _supabase.rpc('set_buddy_expense_receipt', params: {'p_id': id, 'p_path': path});
    } else if (draft.removeReceipt) {
      await _supabase.rpc('set_buddy_expense_receipt', params: {'p_id': id, 'p_path': null});
    }
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> deleteExpense(String id) => _guard(() async {
    await _supabase.rpc('delete_buddy_expense', params: {'p_id': id});
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> recordPayment(BuddyPaymentDraft draft) => _guard(() async {
    final bytes = draft.slipBytes;
    final slip = bytes == null ? null : await _upload(draft.teamId, bytes, draft.slipExtension);
    await _supabase.rpc(
      'record_buddy_payment',
      params: {
        'p_team_id': draft.teamId,
        'p_from': draft.fromId,
        'p_to': draft.toId,
        'p_amount': _units(draft.amountCents),
        'p_method': draft.method.name,
        'p_slip_path': slip,
      },
    );
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> respondToPayment(
    String id, {
    required bool confirm,
    String? reason,
  }) => _guard(() async {
    await _supabase.rpc(
      'respond_buddy_payment',
      params: {'p_id': id, 'p_confirm': confirm, 'p_reason': reason},
    );
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> cancelPayment(String id) => _guard(() async {
    await _supabase.rpc('cancel_buddy_payment', params: {'p_id': id});
    return unit;
  });
}
