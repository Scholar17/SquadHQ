import 'package:equatable/equatable.dart';

/// Values match expenses.category (024; subscriptions in 039). Everyday
/// ones for normal and trip expenses; [isSubscription] ones — the service
/// — for monthly expenses.
enum ExpenseCategory {
  food('Food'),
  drinks('Drinks'),
  shopping('Shopping'),
  transport('Transport'),
  stay('Stay'),
  tickets('Tickets'),
  other('Other'),
  youtube('YouTube', isSubscription: true),
  netflix('Netflix', isSubscription: true),
  spotify('Spotify', isSubscription: true),
  canva('Canva', isSubscription: true),
  chatgpt('ChatGPT', isSubscription: true),
  icloud('iCloud', isSubscription: true),
  googleOne('Google One', isSubscription: true),
  appleMusic('Apple Music', isSubscription: true),
  disneyPlus('Disney+', isSubscription: true),
  microsoft365('Microsoft 365', isSubscription: true),
  subscription('Other', isSubscription: true);

  const ExpenseCategory(this.label, {this.isSubscription = false});

  final String label;
  final bool isSubscription;

  static List<ExpenseCategory> get everyday => [
    for (final c in values)
      if (!c.isSubscription) c,
  ];

  static List<ExpenseCategory> get subscriptions => [
    for (final c in values)
      if (c.isSubscription) c,
  ];
}

/// How an expense is divided. Values match expenses.split_mode.
enum ExpenseSplitMode {
  /// Everyone in the squad, equally.
  equal('Equal'),

  /// Only the ticked people, equally.
  chosen('Chosen'),

  /// A typed amount per person, adding up to the total.
  exact('Exact'),

  /// Only the ticked people, each with a typed amount adding up to the
  /// total.
  custom('Custom'),

  /// On the payer — recorded, nobody owes anything.
  treat('Treat');

  const ExpenseSplitMode(this.label);

  final String label;
}

/// Someone outside the squad in a split (037) — information only. Their
/// share is already inside a member's: their host's, or with no host, the
/// payer's (who collects it from them outside the app).
class ExpenseGuest extends Equatable {
  const ExpenseGuest({required this.name, required this.amountCents, this.hostId});

  final String name;
  final int amountCents;

  /// The member covering them; null = no one (the payer collects it).
  final String? hostId;

  @override
  List<Object?> get props => [name, amountCents, hostId];
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
    this._payers,
    this.note,
    this.place,
    this.tripId,
    this.receiptPath,
    this.recurringId,
    this.guests = const [],
    this.categoryLabel,
  });

  /// Up to this many people can pay for one expense.
  static const maxPayers = 5;

  final String id;
  final String title;
  final ExpenseCategory category;
  final int amountCents;
  final DateTime spentAt;
  final ExpenseSplitMode splitMode;

  /// Who fronted the money — with several payers, whoever paid the most.
  final String payerId;

  final Map<String, int>? _payers;

  /// Who fronted how much, summing to [amountCents]; one entry ([payerId],
  /// the whole amount) unless several people paid.
  Map<String, int> get payers => _payers ?? {payerId: amountCents};

  bool get hasSeveralPayers => payers.length > 1;

  int paidBy(String profileId) => payers[profileId] ?? 0;

  /// What each person owes for it, in minor units — sums to [amountCents].
  /// For an equal split the payer's share is whatever's left after
  /// everyone else's whole-unit share.
  final Map<String, int> shares;

  final String createdBy;
  final String? note;
  final String? place;

  /// The trip it belongs to; null for the squad's own.
  final String? tripId;

  /// Proof of payment — a receipt or slip photo in the payment-slips
  /// bucket — that everyone in the squad can open.
  final String? receiptPath;

  /// The monthly expense that charged it, if any (036).
  final String? recurringId;

  /// What "Other" is ("Gym", "Amazon Prime"), if named (040).
  final String? categoryLabel;

  /// The category as shown: its name for "Other", if given.
  String get categoryName => categoryLabel ?? category.label;

  /// Guests from outside the squad, shown for information; their amounts
  /// are already in [shares] (see [ExpenseGuest]).
  final List<ExpenseGuest> guests;

  /// Who a guest's share sits with: their host, or else the payer.
  String coverOf(ExpenseGuest guest) => guest.hostId ?? payerId;

  /// [profileId]'s share without the guests they cover.
  int ownShareOf(String profileId) =>
      shareOf(profileId) -
      guests.where((g) => coverOf(g) == profileId).fold(0, (sum, g) => sum + g.amountCents);

  int shareOf(String profileId) => shares[profileId] ?? 0;

  bool includes(String profileId) => shares.containsKey(profileId);

  /// What [profileId] gets back (+) or owes (−) because of this expense.
  int netFor(String profileId) => paidBy(profileId) - shareOf(profileId);

  /// Who owes whom because of this expense. With one payer, everyone else
  /// owes them their share. With several, each person who's short (share
  /// more than they paid) owes every payer who's over, in proportion to how
  /// much each is over: Aung +฿350 and Ko +฿150 means a ฿250 share is
  /// ฿175 to Aung and ฿75 to Ko. Exact to the minor unit.
  List<({String fromId, String toId, int cents})> get owed {
    final over = <String, int>{};
    final short = <String, int>{};
    for (final id in {...payers.keys, ...shares.keys}) {
      final net = netFor(id);
      if (net > 0) over[id] = net;
      if (net < 0) short[id] = -net;
    }
    final total = over.values.fold(0, (a, b) => a + b);
    if (total == 0) return const [];
    if (over.length == 1) {
      final to = over.keys.single;
      return [
        for (final MapEntry(:key, :value) in short.entries) (fromId: key, toId: to, cents: value),
      ];
    }
    // Splits the short × over grid by cumulative sums, so every row adds up
    // to what that person owes and every column to what that payer is owed.
    int cut(int x, int y) => x * y ~/ total;
    final result = <({String fromId, String toId, int cents})>[];
    var fromStart = 0;
    for (final MapEntry(key: fromId, value: owes) in short.entries) {
      final fromEnd = fromStart + owes;
      var toStart = 0;
      for (final MapEntry(key: toId, value: isOwed) in over.entries) {
        final toEnd = toStart + isOwed;
        final cents =
            cut(fromEnd, toEnd) -
            cut(fromStart, toEnd) -
            cut(fromEnd, toStart) +
            cut(fromStart, toStart);
        // Under one minor unit the rounding can dip below zero: fall back
        // to paying payers off in turn.
        if (cents < 0) return _owedInTurn(short, over);
        if (cents > 0) result.add((fromId: fromId, toId: toId, cents: cents));
        toStart = toEnd;
      }
      fromStart = fromEnd;
    }
    return result;
  }

  static List<({String fromId, String toId, int cents})> _owedInTurn(
    Map<String, int> short,
    Map<String, int> over,
  ) {
    final owing = short.entries.toList();
    final owedTo = over.entries.toList();
    final result = <({String fromId, String toId, int cents})>[];
    var i = 0, j = 0;
    var owe = owing.first.value, due = owedTo.first.value;
    while (i < owing.length && j < owedTo.length) {
      final cents = owe < due ? owe : due;
      if (cents > 0) result.add((fromId: owing[i].key, toId: owedTo[j].key, cents: cents));
      owe -= cents;
      due -= cents;
      if (owe == 0 && ++i < owing.length) owe = owing[i].value;
      if (due == 0 && ++j < owedTo.length) due = owedTo[j].value;
    }
    return result;
  }

  /// What [fromId] owes [toId] because of this expense; 0 if nothing.
  int owedBy(String fromId, String toId) {
    for (final debt in owed) {
      if (debt.fromId == fromId && debt.toId == toId) return debt.cents;
    }
    return 0;
  }

  /// Whoever added it, the payers and admins may edit or delete it.
  bool canEdit(String profileId, {required bool isAdmin}) =>
      isAdmin || profileId == createdBy || payers.containsKey(profileId);

  @override
  List<Object?> get props => [
    id,
    title,
    category,
    amountCents,
    spentAt,
    splitMode,
    payerId,
    payers,
    shares,
    createdBy,
    note,
    place,
    tripId,
    receiptPath,
    recurringId,
    guests,
    categoryLabel,
  ];
}
