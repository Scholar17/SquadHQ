import 'package:equatable/equatable.dart';

import '../../../squad/domain/entities/expense.dart' show ExpenseCategory, ExpenseSplitMode;
import '../../../squad/domain/entities/settlement.dart' show SettlementMethod, SettlementStatus;

/// A cost shared by you and one squad-mate ([buddyId]), seen from your
/// side (061). Money is in minor units.
class BuddyExpense extends Equatable {
  const BuddyExpense({
    required this.id,
    required this.buddyId,
    required this.payerId,
    required this.title,
    required this.category,
    required this.amountCents,
    required this.splitMode,
    required this.myShareCents,
    required this.buddyShareCents,
    required this.spentAt,
    required this.createdBy,
    required this.updatedAt,
    this.categoryLabel,
    this.myWeight,
    this.buddyWeight,
    this.note,
    this.receiptPath,
  });

  final String id;
  final String buddyId;

  /// You or [buddyId].
  final String payerId;
  final String title;
  final ExpenseCategory category;
  final String? categoryLabel;
  final int amountCents;

  /// Equal, custom, percent or shares.
  final ExpenseSplitMode splitMode;
  final int myShareCents;
  final int buddyShareCents;

  /// A percent or shares split's typed weights, in hundredths.
  final int? myWeight;
  final int? buddyWeight;
  final DateTime spentAt;
  final String? note;
  final String? receiptPath;
  final String createdBy;
  final DateTime updatedAt;

  bool paidBy(String profileId) => payerId == profileId;

  /// What [buddyId] owes you for it (negative: what you owe them), given
  /// you're [me].
  int owedToMe(String me) => payerId == me ? buddyShareCents : -myShareCents;

  @override
  List<Object?> get props => [
    id,
    buddyId,
    payerId,
    title,
    category,
    categoryLabel,
    amountCents,
    splitMode,
    myShareCents,
    buddyShareCents,
    myWeight,
    buddyWeight,
    spentAt,
    note,
    receiptPath,
    createdBy,
    updatedAt,
  ];
}

/// One of you paying the other back on buddy expenses.
class BuddySettlement extends Equatable {
  const BuddySettlement({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.amountCents,
    required this.method,
    required this.status,
    required this.recordedBy,
    required this.createdAt,
    this.slipPath,
    this.rejectReason,
  });

  final String id;
  final String fromId;
  final String toId;
  final int amountCents;
  final SettlementMethod method;
  final SettlementStatus status;

  /// [fromId] said "I paid", or [toId] marked it received.
  final String recordedBy;
  final DateTime createdAt;
  final String? slipPath;
  final String? rejectReason;

  bool get isPending => status == SettlementStatus.pending;

  bool involves(String profileId) => fromId == profileId || toId == profileId;

  @override
  List<Object?> get props => [
    id,
    fromId,
    toId,
    amountCents,
    method,
    status,
    recordedBy,
    createdAt,
    slipPath,
    rejectReason,
  ];
}

/// Your buddy expenses and payments in one squad, apart from its balance.
class BuddyLedger extends Equatable {
  const BuddyLedger({required this.me, required this.expenses, required this.settlements});

  static BuddyLedger empty(String me) =>
      BuddyLedger(me: me, expenses: const [], settlements: const []);

  final String me;

  /// Newest first.
  final List<BuddyExpense> expenses;

  /// Newest first.
  final List<BuddySettlement> settlements;

  /// Everyone you share buddy expenses or payments with.
  List<String> get buddies => {
    for (final expense in expenses) expense.buddyId,
    for (final settlement in settlements) settlement.fromId == me ? settlement.toId : settlement.fromId,
  }.toList();

  /// What [buddyId] owes you after confirmed payments (negative: you owe
  /// them).
  int balanceWith(String buddyId) {
    var balance = 0;
    for (final expense in expenses) {
      if (expense.buddyId == buddyId) balance += expense.owedToMe(me);
    }
    for (final settlement in settlements) {
      if (settlement.status != SettlementStatus.confirmed || !settlement.involves(buddyId)) continue;
      // They paid you: they owe less. You paid them: you owe less.
      balance += settlement.fromId == me ? settlement.amountCents : -settlement.amountCents;
    }
    return balance;
  }

  List<BuddyExpense> expensesWith(String buddyId) => [
    for (final expense in expenses)
      if (expense.buddyId == buddyId) expense,
  ];

  List<BuddySettlement> settlementsWith(String buddyId) => [
    for (final settlement in settlements)
      if (settlement.involves(buddyId)) settlement,
  ];

  /// "I paid"s from [buddyId] waiting for you to confirm.
  List<BuddySettlement> awaitingMeFrom(String buddyId) => [
    for (final settlement in settlements)
      if (settlement.isPending && settlement.fromId == buddyId && settlement.toId == me) settlement,
  ];

  /// All "I paid"s waiting for you, from anyone.
  List<BuddySettlement> get awaitingMe => [
    for (final settlement in settlements)
      if (settlement.isPending && settlement.toId == me) settlement,
  ];

  BuddyExpense? expense(String id) => expenses.where((e) => e.id == id).firstOrNull;

  @override
  List<Object?> get props => [me, expenses, settlements];
}
