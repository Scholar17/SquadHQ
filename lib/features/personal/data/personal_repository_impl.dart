import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_messages.dart';
import '../../../core/error/failures.dart';
import '../../team_membership/domain/entities/team.dart' show GroupCurrency;
import '../domain/entities/personal_expense.dart';
import '../domain/repositories/personal_repository.dart';

/// Postgres' code for a unique index refusing a row — a category name you
/// already have (any case).
const _uniqueViolation = '23505';

/// Receipts share the private payment-slips bucket, under
/// `personal/<owner id>/` (060).
const _bucket = 'payment-slips';

int _cents(Object? value) => ((value as num) * 100).round();

double _units(int cents) => cents / 100;

class PersonalRepositoryImpl implements PersonalRepository {
  PersonalRepositoryImpl({required SupabaseClient supabaseClient}) : _supabase = supabaseClient;

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
      if (e.code == _uniqueViolation) {
        return const Left(ServerFailure('You already have a category with that name'));
      }
      return Left(ServerFailure(e.message));
    } on StorageException catch (e) {
      return Left(ServerFailure('Could not upload the receipt: ${e.message}'));
    } on StateError catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  static PersonalExpense _expense(Map<String, dynamic> row) => PersonalExpense(
    id: row['id'] as String,
    title: row['title'] as String,
    amountCents: _cents(row['amount']),
    spentAt: DateTime.parse(row['spent_at'] as String),
    category:
        PersonalCategory.values.asNameMap()[row['category']] ?? PersonalCategory.other,
    customCategoryId: row['custom_category_id'] as String?,
    note: row['note'] as String?,
    receiptPath: row['receipt_path'] as String?,
  );

  @override
  Future<Either<Failure, PersonalSpending>> load() => _guard(() async {
    final me = _userId;
    final results = await Future.wait<Object?>([
      _supabase
          .from('personal_expenses')
          .select()
          .eq('owner_id', me)
          .order('spent_at', ascending: false),
      _supabase.from('personal_expense_categories').select().eq('owner_id', me).order('name'),
      _supabase.from('personal_settings').select('currency').eq('owner_id', me).maybeSingle(),
    ]);
    final settings = results[2] as Map<String, dynamic>?;
    return PersonalSpending(
      expenses: [
        for (final row in (results[0]! as List<dynamic>).cast<Map<String, dynamic>>())
          _expense(row),
      ],
      categories: [
        for (final row in (results[1]! as List<dynamic>).cast<Map<String, dynamic>>())
          CustomCategory(id: row['id'] as String, name: row['name'] as String),
      ],
      currency: GroupCurrency.values.asNameMap()[settings?['currency']] ?? GroupCurrency.thb,
    );
  });

  @override
  Future<Either<Failure, Unit>> saveExpense(PersonalExpenseDraft draft) => _guard(() async {
    final me = _userId;
    String? receiptPath = draft.removeReceipt ? null : draft.previousReceiptPath;
    final bytes = draft.receiptBytes;
    if (bytes != null) {
      final extension = draft.receiptExtension ?? 'jpg';
      receiptPath = 'personal/$me/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _supabase.storage
          .from(_bucket)
          .uploadBinary(
            receiptPath,
            bytes,
            fileOptions: FileOptions(contentType: extension == 'png' ? 'image/png' : 'image/jpeg'),
          );
    }
    final note = draft.note?.trim();
    final row = {
      'title': draft.title.trim(),
      'amount': _units(draft.amountCents),
      'spent_at': draft.spentAt.toUtc().toIso8601String(),
      'category': draft.customCategoryId == null ? draft.category.name : PersonalCategory.custom.name,
      'custom_category_id': draft.customCategoryId,
      'note': note == null || note.isEmpty ? null : note,
      'receipt_path': receiptPath,
    };
    if (draft.id case final id?) {
      await _supabase
          .from('personal_expenses')
          .update({...row, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } else {
      await _supabase.from('personal_expenses').insert(row);
    }
    // The old photo's no longer used.
    final previous = draft.previousReceiptPath;
    if (previous != null && previous != receiptPath) await _removeReceipt(previous);
    return unit;
  });

  /// Best effort: a photo left behind is only wasted space.
  Future<void> _removeReceipt(String path) async {
    try {
      await _supabase.storage.from(_bucket).remove([path]);
    } on StorageException catch (e) {
      debugPrint('[personal] could not remove receipt: ${e.message}');
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteExpense(PersonalExpense expense) => _guard(() async {
    await _supabase.from('personal_expenses').delete().eq('id', expense.id);
    if (expense.receiptPath case final path?) await _removeReceipt(path);
    return unit;
  });

  @override
  Future<Either<Failure, CustomCategory>> addCategory(String name) => _guard(() async {
    final row = await _supabase
        .from('personal_expense_categories')
        .insert({'name': name.trim()})
        .select()
        .single();
    return CustomCategory(id: row['id'] as String, name: row['name'] as String);
  });

  @override
  Future<Either<Failure, Unit>> deleteCategory(String id) => _guard(() async {
    await _supabase.from('personal_expense_categories').delete().eq('id', id);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> setCurrency(GroupCurrency currency) => _guard(() async {
    await _supabase.from('personal_settings').upsert({
      'owner_id': _userId,
      'currency': currency.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    return unit;
  });
}
