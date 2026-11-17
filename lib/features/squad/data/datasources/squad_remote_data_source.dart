import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../comments/domain/entities/comment.dart';
import '../../../team_membership/data/models/team_model.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/payment_promise.dart';
import '../../domain/entities/recurring_expense.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/entities/squad_member.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/squad_repository.dart';

abstract interface class SquadRemoteDataSource {
  Future<SquadLedger> getLedger(String teamId);

  Future<String> saveExpense(ExpenseDraft draft);

  Future<void> deleteExpense(String expenseId);

  Future<String> saveTrip(TripDraft draft);

  Future<void> setTripClosed(String tripId, {required bool closed});

  Future<String> saveRecurring(RecurringDraft draft);

  Future<void> setRecurringPaused(String id, {required bool paused});

  Future<void> deleteRecurring(String id);

  Future<void> sendSettlement(SettlementDraft draft);

  Future<void> respondSettlement({
    required String settlementId,
    required bool accept,
    String? reason,
  });

  Future<int> remind({required String teamId, required Map<String, int> amounts, String? tripId});

  Future<void> nudgeSettlement(String settlementId);

  Future<void> promisePayment(PromiseDraft draft);

  Future<void> recordReceived(ReceivedDraft draft);

  Future<void> confirmPartialPayment({required String settlementId, required int receivedCents});

  Future<void> setReminderDay({required String teamId, int? day});

  Future<List<Comment>> getComments(String expenseId);

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
    final since = DateTime.now().subtract(const Duration(days: 2)).toUtc().toIso8601String();
    // Future.wait, not a record's .wait: it rethrows the first query's own
    // error (e.g. a PostgrestException naming a missing table), which
    // _guard turns into a readable message.
    final results = await Future.wait<Object?>([
      _supabase.from('teams').select('currency').eq('id', teamId).single(),
      _supabase
          .from('team_members')
          .select(
            // '*': reminder_day only exists once 044 runs.
            '*, profiles(name, username, avatar_url, wallet_qr_path, '
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
      _recentReminders(teamId, since),
      _trips(teamId),
      _recurring(teamId),
      _guests(teamId),
      _promises(teamId),
    ]);
    final teamRow = results[0]! as Map<String, dynamic>;
    final memberRows = (results[1]! as List<dynamic>).cast<Map<String, dynamic>>();
    final expenseRows = (results[2]! as List<dynamic>).cast<Map<String, dynamic>>();
    final settlementRows = (results[3]! as List<dynamic>).cast<Map<String, dynamic>>();
    final reminderRows = results[4]! as List<SquadReminder>;
    final guests = results[7]! as Map<String, List<ExpenseGuest>>;
    final promises = results[8]! as List<PaymentPromise>;
    final expenses = [for (final row in expenseRows) _expense(row, guests)];
    final settlements = [for (final row in settlementRows) _settlement(row)];
    return SquadLedger(
      currency: groupCurrencyFromDb(teamRow['currency'] as String?),
      members: [for (final row in memberRows) _member(row)],
      // Trips' expenses and payments are kept apart (SquadLedger.forTrip).
      expenses: [
        for (final e in expenses)
          if (e.tripId == null) e,
      ],
      settlements: [
        for (final s in settlements)
          if (s.tripId == null) s,
      ],
      reminders: [
        for (final r in reminderRows)
          if (r.tripId == null) r,
      ],
      tripReminders: [
        for (final r in reminderRows)
          if (r.tripId != null) r,
      ],
      trips: results[5]! as List<Trip>,
      recurring: results[6]! as List<RecurringExpense>,
      tripExpenses: [
        for (final e in expenses)
          if (e.tripId != null) e,
      ],
      tripSettlements: [
        for (final s in settlements)
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
    );
  });

  /// "I'll pay on …" promises. Optional: none before
  /// 044_squad_payments.sql runs.
  Future<List<PaymentPromise>> _promises(String teamId) async {
    try {
      final rows = await _supabase.from('payment_promises').select().eq('team_id', teamId);
      return [
        for (final row in rows)
          PaymentPromise(
            id: row['id'] as String,
            fromId: row['from_profile'] as String,
            toId: row['to_profile'] as String,
            promisedOn: DateTime.parse(row['promised_on'] as String),
            tripId: row['trip_id'] as String?,
          ),
      ];
    } on PostgrestException catch (e) {
      debugPrint('[squad] promises unavailable: ${e.message}');
      return const [];
    }
  }

  /// Reminders sent since [since]. Optional: if they can't load (e.g.
  /// 026_squad_reminders.sql isn't run yet) the squad still shows, with
  /// every "Remind" button enabled — the server still enforces once a day.
  Future<List<SquadReminder>> _recentReminders(String teamId, String since) async {
    try {
      final rows = await _supabase
          .from('squad_reminders')
          // '*': trip_id only exists once 035 runs.
          .select()
          .eq('team_id', teamId)
          .gte('reminded_at', since);
      return [
        for (final row in rows)
          SquadReminder(
            fromId: row['reminded_by'] as String,
            toId: row['profile_id'] as String,
            at: DateTime.parse(row['reminded_at'] as String),
            tripId: row['trip_id'] as String?,
          ),
      ];
    } on PostgrestException catch (e) {
      debugPrint('[squad] reminders unavailable: ${e.message}');
      return const [];
    }
  }

  /// The squad's trips, newest first. Optional like reminders: before
  /// 032_trips.sql runs there are none and the squad still shows.
  Future<List<Trip>> _trips(String teamId) async {
    try {
      final rows = await _supabase
          .from('trips')
          .select()
          .eq('team_id', teamId)
          .order('starts_on', ascending: false);
      return [
        for (final row in rows)
          Trip(
            id: row['id'] as String,
            name: row['name'] as String,
            startsOn: DateTime.parse(row['starts_on'] as String),
            endsOn: DateTime.parse(row['ends_on'] as String),
            memberIds: (row['member_ids'] as List<dynamic>).cast<String>(),
            createdBy: row['created_by'] as String,
            closedAt: switch (row['closed_at']) {
              final String at => DateTime.parse(at),
              _ => null,
            },
          ),
      ];
    } on PostgrestException catch (e) {
      debugPrint('[squad] trips unavailable: ${e.message}');
      return const [];
    }
  }

  /// The squad's monthly expenses, oldest first. Optional: none before
  /// 036_monthly_expenses.sql runs.
  Future<List<RecurringExpense>> _recurring(String teamId) async {
    DateTime? date(Object? value) => value is String ? DateTime.parse(value) : null;
    try {
      final rows = await _supabase
          .from('recurring_expenses')
          .select()
          .eq('team_id', teamId)
          .order('created_at');
      return [
        for (final row in rows)
          RecurringExpense(
            id: row['id'] as String,
            title: row['title'] as String,
            category: ExpenseCategory.values.asNameMap()[row['category']] ?? ExpenseCategory.other,
            amountCents: _cents(row['amount']),
            payerId: row['payer_id'] as String,
            splitMode:
                ExpenseSplitMode.values.asNameMap()[row['split_mode']] ?? ExpenseSplitMode.exact,
            shares: {
              for (final share in (row['shares'] as List<dynamic>).cast<Map<String, dynamic>>())
                share['profile_id'] as String: _cents(share['amount']),
            },
            chargeDay: row['charge_day'] as int,
            startsOn: DateTime.parse(row['starts_on'] as String),
            createdBy: row['created_by'] as String,
            note: row['note'] as String?,
            pausedAt: date(row['paused_at']),
            lastMonth: date(row['last_month']),
            categoryLabel: row['category_label'] as String?,
          ),
      ];
    } on PostgrestException catch (e) {
      debugPrint('[squad] monthly expenses unavailable: ${e.message}');
      return const [];
    }
  }

  /// Each expense's guests, by expense id. Optional: none before
  /// 037_expense_guests.sql runs.
  Future<Map<String, List<ExpenseGuest>>> _guests(String teamId) async {
    try {
      final rows = await _supabase
          .from('expense_guests')
          .select('expense_id, name, amount, host_id, expenses!inner(team_id)')
          .eq('expenses.team_id', teamId);
      final byExpense = <String, List<ExpenseGuest>>{};
      for (final row in rows) {
        byExpense
            .putIfAbsent(row['expense_id'] as String, () => [])
            .add(
              ExpenseGuest(
                name: row['name'] as String,
                amountCents: _cents(row['amount']),
                hostId: row['host_id'] as String?,
              ),
            );
      }
      return byExpense;
    } on PostgrestException catch (e) {
      debugPrint('[squad] guests unavailable: ${e.message}');
      return const {};
    }
  }

  static SquadMember _member(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>? ?? const {};
    return SquadMember(
      profileId: row['profile_id'] as String,
      name: profile['name'] as String? ?? 'Member',
      role: teamRoleFromDb(row['role'] as String),
      username: profile['username'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      walletQrPath: profile['wallet_qr_path'] as String?,
      bankName: profile['bank_name'] as String?,
      bankAccountName: profile['bank_account_name'] as String?,
      bankAccountNo: profile['bank_account_no'] as String?,
      reminderDay: row['reminder_day'] as int?,
    );
  }

  static Expense _expense(Map<String, dynamic> row, Map<String, List<ExpenseGuest>> guests) {
    final payers = (row['expense_payers'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return Expense(
      id: row['id'] as String,
      title: row['title'] as String,
      category: ExpenseCategory.values.asNameMap()[row['category']] ?? ExpenseCategory.other,
      amountCents: _cents(row['amount']),
      spentAt: DateTime.parse(row['spent_at'] as String),
      splitMode: ExpenseSplitMode.values.asNameMap()[row['split_mode']] ?? ExpenseSplitMode.exact,
      // The biggest payer leads; several payers keep each one's amount.
      payerId: payers.isEmpty
          ? row['created_by'] as String
          : (payers.toList()..sort((a, b) => _cents(b['amount']).compareTo(_cents(a['amount']))))
                    .first['profile_id']
                as String,
      payers: payers.length < 2
          ? null
          : {for (final payer in payers) payer['profile_id'] as String: _cents(payer['amount'])},
      shares: {
        for (final share
            in (row['expense_shares'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          share['profile_id'] as String: _cents(share['amount']),
      },
      createdBy: row['created_by'] as String,
      note: row['note'] as String?,
      place: row['place'] as String?,
      tripId: row['trip_id'] as String?,
      receiptPath: row['receipt_path'] as String?,
      recurringId: row['recurring_id'] as String?,
      guests: guests[row['id']] ?? const [],
      categoryLabel: row['category_label'] as String?,
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
    nudgedAt: switch (row['nudged_at']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    tripId: row['trip_id'] as String?,
    recordedBy: row['recorded_by'] as String?,
    sentCents: row['sent_amount'] == null ? null : _cents(row['sent_amount']),
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
        // Only for trips, so plain expenses still save before 032 runs.
        'p_trip_id': ?draft.tripId,
        'p_paid_by': draft.payerId,
        'p_payers': [
          for (final MapEntry(:key, :value)
              in (draft.payers ?? {draft.payerId: draft.amountCents}).entries)
            {'profile_id': key, 'amount': _units(value)},
        ],
        'p_shares': [
          for (final MapEntry(:key, :value) in draft.shares.entries)
            {'profile_id': key, 'amount': _units(value)},
        ],
      },
    );
    // "Other"'s name goes on once the expense exists (040).
    if (draft.setCategoryLabel) {
      await _supabase.rpc(
        'set_expense_category_label',
        params: {'p_expense_id': id, 'p_label': draft.categoryLabel},
      );
    }
    // Guests go on once the expense exists (037).
    if (draft.guests case final guests?) {
      await _supabase.rpc(
        'set_expense_guests',
        params: {
          'p_expense_id': id,
          'p_guests': [
            for (final g in guests)
              {'name': g.name, 'amount': _units(g.amountCents), 'host_id': g.hostId},
          ],
        },
      );
    }
    // Proof of payment goes on once the expense exists (033).
    final bytes = draft.receiptBytes;
    if (bytes != null) {
      final extension = draft.receiptExtension ?? 'jpg';
      final path =
          'receipts/${draft.teamId}/$_userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
      await _supabase.storage
          .from(_slipBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: extension == 'png' ? 'image/png' : 'image/jpeg'),
          );
      await _supabase.rpc('set_expense_receipt', params: {'p_expense_id': id, 'p_path': path});
    } else if (draft.removeReceipt) {
      await _supabase.rpc('set_expense_receipt', params: {'p_expense_id': id, 'p_path': null});
    }
    return id as String;
  });

  @override
  Future<void> deleteExpense(String expenseId) =>
      _guard(() => _supabase.rpc('delete_expense', params: {'p_id': expenseId}));

  @override
  Future<String> saveTrip(TripDraft draft) => _guard(() async {
    String day(DateTime at) =>
        '${at.year.toString().padLeft(4, '0')}-'
        '${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
    final id = await _supabase.rpc(
      'save_trip',
      params: {
        'p_id': draft.id,
        'p_team_id': draft.teamId,
        'p_name': draft.name,
        'p_starts_on': day(draft.startsOn),
        'p_ends_on': day(draft.endsOn),
        'p_member_ids': draft.memberIds,
      },
    );
    return id as String;
  });

  @override
  Future<void> setTripClosed(String tripId, {required bool closed}) =>
      _guard(() => _supabase.rpc('set_trip_closed', params: {'p_id': tripId, 'p_closed': closed}));

  @override
  Future<String> saveRecurring(RecurringDraft draft) => _guard(() async {
    final start = draft.startsOn;
    final id = await _supabase.rpc(
      'save_recurring_expense',
      params: {
        'p_id': draft.id,
        'p_team_id': draft.teamId,
        'p_title': draft.title,
        'p_category': draft.category.name,
        'p_amount': _units(draft.amountCents),
        'p_paid_by': draft.payerId,
        'p_split_mode': draft.splitMode.name,
        'p_shares': [
          for (final MapEntry(:key, :value) in draft.shares.entries)
            {'profile_id': key, 'amount': _units(value)},
        ],
        'p_charge_day': draft.chargeDay,
        'p_starts_on':
            '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-01',
        'p_note': draft.note,
      },
    );
    if (draft.setCategoryLabel) {
      await _supabase.rpc(
        'set_recurring_category_label',
        params: {'p_id': id, 'p_label': draft.categoryLabel},
      );
    }
    return id as String;
  });

  @override
  Future<void> setRecurringPaused(String id, {required bool paused}) =>
      _guard(() => _supabase.rpc('set_recurring_paused', params: {'p_id': id, 'p_paused': paused}));

  @override
  Future<void> deleteRecurring(String id) =>
      _guard(() => _supabase.rpc('delete_recurring_expense', params: {'p_id': id}));

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
        'p_trip_id': ?draft.tripId,
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
  Future<void> promisePayment(PromiseDraft draft) => _guard(
    () => _supabase.rpc(
      'promise_payment',
      params: {
        'p_team_id': draft.teamId,
        'p_to': draft.toId,
        'p_on': _date(draft.on),
        'p_trip_id': draft.tripId,
      },
    ),
  );

  @override
  Future<void> recordReceived(ReceivedDraft draft) => _guard(
    () => _supabase.rpc(
      'record_received',
      params: {
        'p_team_id': draft.teamId,
        'p_from': draft.fromId,
        'p_amount': _units(draft.amountCents),
        'p_trip_id': draft.tripId,
      },
    ),
  );

  @override
  Future<void> confirmPartialPayment({required String settlementId, required int receivedCents}) =>
      _guard(
        () => _supabase.rpc(
          'confirm_partial_payment',
          params: {'p_id': settlementId, 'p_amount': _units(receivedCents)},
        ),
      );

  @override
  Future<void> setReminderDay({required String teamId, int? day}) => _guard(
    () => _supabase.rpc('set_reminder_day', params: {'p_team_id': teamId, 'p_day': day}),
  );

  static String _date(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  Future<int> remind({required String teamId, required Map<String, int> amounts, String? tripId}) =>
      _guard(() async {
        final count = await _supabase.rpc(
          'remind_to_pay',
          params: {
            'p_team_id': teamId,
            'p_reminders': [
              for (final MapEntry(:key, :value) in amounts.entries)
                {'profile_id': key, 'amount': _units(value)},
            ],
            'p_trip_id': tripId,
          },
        );
        return count as int;
      });

  @override
  Future<void> nudgeSettlement(String settlementId) =>
      _guard(() => _supabase.rpc('nudge_settlement', params: {'p_id': settlementId}));

  @override
  Future<List<Comment>> getComments(String expenseId) => _guard(() async {
    final rows = await _supabase
        .from('expense_comments')
        .select('id, expense_id, parent_id, profile_id, body, created_at')
        .eq('expense_id', expenseId)
        .order('created_at');
    return [
      for (final row in rows)
        Comment(
          id: row['id'] as String,
          subjectId: row['expense_id'] as String,
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
