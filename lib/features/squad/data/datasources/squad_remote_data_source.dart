import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../team_membership/data/models/team_model.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_comment.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/entities/squad_member.dart';
import '../../domain/repositories/squad_repository.dart';

abstract interface class SquadRemoteDataSource {
  Future<SquadLedger> getLedger(String teamId);

  Future<String> saveExpense(ExpenseDraft draft);

  Future<void> deleteExpense(String expenseId);

  Future<void> sendSettlement(SettlementDraft draft);

  Future<void> respondSettlement({
    required String settlementId,
    required bool accept,
    String? reason,
  });

  Future<List<ExpenseComment>> getComments(String expenseId);

  Future<void> addComment({required String expenseId, required String body, String? parentId});

  Future<void> deleteComment(String commentId);

  Future<BankDetails> getMyBankDetails();

  Future<void> saveMyBankDetails(BankDetails details);
}

/// Money columns are numeric(12,2); the app works in minor units.
int _cents(Object? value) => ((value as num) * 100).round();

double _units(int cents) => cents / 100;

class SquadRemoteDataSourceImpl implements SquadRemoteDataSource {
  SquadRemoteDataSourceImpl({required SupabaseClient supabaseClient}) : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  static const _slipBucket = 'payment-slips';

  String get _userId {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const ServerException('You are signed out');
    return userId;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } on StorageException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<SquadLedger> getLedger(String teamId) => _guard(() async {
    final (teamRow, memberRows, expenseRows, settlementRows) = await (
      _supabase.from('teams').select('currency').eq('id', teamId).single(),
      _supabase
          .from('team_members')
          .select(
            'profile_id, role, profiles(name, avatar_url, wallet_qr_path, '
            'bank_name, bank_account_name, bank_account_no)',
          )
          .eq('team_id', teamId),
      _supabase
          .from('expenses')
          .select('*, expense_payers(profile_id, amount), expense_shares(profile_id, amount)')
          .eq('team_id', teamId)
          .order('spent_at', ascending: false),
      _supabase
          .from('settlements')
          .select()
          .eq('team_id', teamId)
          .order('created_at', ascending: false),
    ).wait;
    return SquadLedger(
      currency: groupCurrencyFromDb(teamRow['currency'] as String?),
      members: [for (final row in memberRows) _member(row)],
      expenses: [for (final row in expenseRows) _expense(row)],
      settlements: [for (final row in settlementRows) _settlement(row)],
    );
  });

  static SquadMember _member(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>? ?? const {};
    return SquadMember(
      profileId: row['profile_id'] as String,
      name: profile['name'] as String? ?? 'Member',
      role: teamRoleFromDb(row['role'] as String),
      avatarUrl: profile['avatar_url'] as String?,
      walletQrPath: profile['wallet_qr_path'] as String?,
      bankName: profile['bank_name'] as String?,
      bankAccountName: profile['bank_account_name'] as String?,
      bankAccountNo: profile['bank_account_no'] as String?,
    );
  }

  static Expense _expense(Map<String, dynamic> row) {
    final payers = (row['expense_payers'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return Expense(
      id: row['id'] as String,
      title: row['title'] as String,
      category: ExpenseCategory.values.asNameMap()[row['category']] ?? ExpenseCategory.other,
      amountCents: _cents(row['amount']),
      spentAt: DateTime.parse(row['spent_at'] as String),
      splitMode: ExpenseSplitMode.values.asNameMap()[row['split_mode']] ?? ExpenseSplitMode.exact,
      payerId: payers.isEmpty ? row['created_by'] as String : payers.first['profile_id'] as String,
      shares: {
        for (final share
            in (row['expense_shares'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          share['profile_id'] as String: _cents(share['amount']),
      },
      createdBy: row['created_by'] as String,
      note: row['note'] as String?,
      place: row['place'] as String?,
    );
  }

  static Settlement _settlement(Map<String, dynamic> row) => Settlement(
    id: row['id'] as String,
    fromId: row['from_profile'] as String,
    toId: row['to_profile'] as String,
    amountCents: _cents(row['amount']),
    method: SettlementMethod.values.asNameMap()[row['method']] ?? SettlementMethod.cash,
    status: SettlementStatus.values.asNameMap()[row['status']] ?? SettlementStatus.pending,
    createdAt: DateTime.parse(row['created_at'] as String),
    slipPath: row['slip_path'] as String?,
    rejectReason: row['reject_reason'] as String?,
    respondedAt: switch (row['responded_at']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
  );

  @override
  Future<String> saveExpense(ExpenseDraft draft) => _guard(() async {
    final id = await _supabase.rpc(
      'upsert_expense',
      params: {
        'p_id': draft.id,
        'p_team_id': draft.teamId,
        'p_title': draft.title,
        'p_category': draft.category.name,
        'p_amount': _units(draft.amountCents),
        'p_spent_at': draft.spentAt?.toUtc().toIso8601String(),
        'p_note': draft.note,
        'p_place': draft.place,
        'p_split_mode': draft.splitMode.name,
        'p_paid_by': draft.payerId,
        'p_shares': [
          for (final MapEntry(:key, :value) in draft.shares.entries)
            {'profile_id': key, 'amount': _units(value)},
        ],
      },
    );
    return id as String;
  });

  @override
  Future<void> deleteExpense(String expenseId) =>
      _guard(() => _supabase.rpc('delete_expense', params: {'p_id': expenseId}));

  @override
  Future<void> sendSettlement(SettlementDraft draft) => _guard(() async {
    String? slipPath;
    final bytes = draft.slipBytes;
    if (bytes != null && draft.method != SettlementMethod.cash) {
      final extension = draft.slipExtension ?? 'jpg';
      // A fresh file per upload, so a resend never overwrites one.
      slipPath =
          'squad/${draft.teamId}/$_userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _supabase.storage
          .from(_slipBucket)
          .uploadBinary(
            slipPath,
            bytes,
            fileOptions: FileOptions(contentType: extension == 'png' ? 'image/png' : 'image/jpeg'),
          );
    }
    await _supabase.rpc(
      'create_settlement',
      params: {
        'p_team_id': draft.teamId,
        'p_to': draft.toId,
        'p_amount': _units(draft.amountCents),
        'p_method': draft.method.name,
        'p_slip_path': slipPath,
      },
    );
  });

  @override
  Future<void> respondSettlement({
    required String settlementId,
    required bool accept,
    String? reason,
  }) => _guard(
    () => _supabase.rpc(
      'respond_settlement',
      params: {'p_id': settlementId, 'p_accept': accept, 'p_reason': reason},
    ),
  );

  @override
  Future<List<ExpenseComment>> getComments(String expenseId) => _guard(() async {
    final rows = await _supabase
        .from('expense_comments')
        .select('id, expense_id, parent_id, profile_id, body, created_at')
        .eq('expense_id', expenseId)
        .order('created_at');
    return [
      for (final row in rows)
        ExpenseComment(
          id: row['id'] as String,
          expenseId: row['expense_id'] as String,
          parentId: row['parent_id'] as String?,
          authorId: row['profile_id'] as String,
          body: row['body'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
    ];
  });

  @override
  Future<void> addComment({required String expenseId, required String body, String? parentId}) =>
      _guard(
        () => _supabase.rpc(
          'add_expense_comment',
          params: {'p_expense_id': expenseId, 'p_parent_id': parentId, 'p_body': body},
        ),
      );

  @override
  Future<void> deleteComment(String commentId) =>
      _guard(() => _supabase.rpc('delete_expense_comment', params: {'p_id': commentId}));

  @override
  Future<BankDetails> getMyBankDetails() => _guard(() async {
    final row = await _supabase
        .from('profiles')
        .select('bank_name, bank_account_name, bank_account_no')
        .eq('id', _userId)
        .single();
    return BankDetails(
      bankName: row['bank_name'] as String?,
      accountName: row['bank_account_name'] as String?,
      accountNo: row['bank_account_no'] as String?,
    );
  });

  @override
  Future<void> saveMyBankDetails(BankDetails details) => _guard(() async {
    String? clean(String? value) => (value ?? '').trim().isEmpty ? null : value!.trim();
    await _supabase
        .from('profiles')
        .update({
          'bank_name': clean(details.bankName),
          'bank_account_name': clean(details.accountName),
          'bank_account_no': clean(details.accountNo),
        })
        .eq('id', _userId);
  });
}
