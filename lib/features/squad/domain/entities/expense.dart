import 'package:equatable/equatable.dart';

/// Values match expenses.category in supabase/sql/024_squads.sql.
enum ExpenseCategory {
  food('Food'),
  drinks('Drinks'),
  shopping('Shopping'),
  transport('Transport'),
  stay('Stay'),
  tickets('Tickets'),
  other('Other');

  const ExpenseCategory(this.label);

  final String label;
}

/// How an expense is divided. Values match expenses.split_mode.
enum ExpenseSplitMode {
  /// Everyone in the squad, equally.
  equal('Equal'),

  /// Only the ticked people, equally.
  chosen('Chosen'),

  /// A typed amount per person, adding up to the total.
  exact('Exact'),

  /// On the payer — recorded, nobody owes anything.
  treat('Treat');

  const ExpenseSplitMode(this.label);

  final String label;
}

/// One shared cost. Money is in minor units (satang, or pya for kyat), so
/// ฿1,000 ÷ 3 is exactly 33333 and never a float like 333.3299999.
class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amountCents,
    required this.spentAt,
    required this.splitMode,
    required this.payerId,
    required this.shares,
    required this.createdBy,
    this.note,
    this.place,
  });

  final String id;
  final String title;
  final ExpenseCategory category;
  final int amountCents;
  final DateTime spentAt;
  final ExpenseSplitMode splitMode;

  /// Who fronted the money (one payer in Phase 1).
  final String payerId;

  /// What each person owes for it, in minor units — sums to [amountCents].
  /// For an equal split the payer's share is whatever's left after
  /// everyone else's whole-unit share.
  final Map<String, int> shares;

  final String createdBy;
  final String? note;
  final String? place;

  int shareOf(String profileId) => shares[profileId] ?? 0;

  bool includes(String profileId) => shares.containsKey(profileId);

  /// What [profileId] gets back (+) or owes (−) because of this expense.
  int netFor(String profileId) => (profileId == payerId ? amountCents : 0) - shareOf(profileId);

  /// Whoever added it, the payer and admins may edit or delete it.
  bool canEdit(String profileId, {required bool isAdmin}) =>
      isAdmin || profileId == createdBy || profileId == payerId;

  @override
  List<Object?> get props => [
    id,
    title,
    category,
    amountCents,
    spentAt,
    splitMode,
    payerId,
    shares,
    createdBy,
    note,
    place,
  ];
}
