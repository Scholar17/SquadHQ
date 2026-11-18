import 'package:equatable/equatable.dart';

import '../../../team_membership/domain/entities/team.dart' show GroupCurrency;

/// The built-in categories, next to the user's own. Values match
/// personal_expenses.category (060); [custom] means one of the user's own.
enum PersonalCategory {
  food('Food'),
  transport('Transport'),
  sports('Sports'),
  shopping('Shopping'),
  bills('Bills'),
  other('Other'),
  custom('Custom');

  const PersonalCategory(this.label);

  final String label;

  /// The ones offered when adding an expense ([custom] is the user's own).
  static const builtIn = [food, transport, sports, shopping, bills, other];
}

/// A category the user added ("Coffee", "Gym").
class CustomCategory extends Equatable {
  const CustomCategory({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// Something you spent, for yourself only. Money is in minor units, like
/// squad expenses.
class PersonalExpense extends Equatable {
  const PersonalExpense({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.spentAt,
    required this.category,
    this.customCategoryId,
    this.note,
    this.receiptPath,
  });

  final String id;
  final String title;
  final int amountCents;
  final DateTime spentAt;

  /// [PersonalCategory.custom] with [customCategoryId] for one of the
  /// user's own; a deleted one comes back as custom with no id (Other).
  final PersonalCategory category;
  final String? customCategoryId;
  final String? note;

  /// In the payment-slips bucket, under `personal/<owner id>/`.
  final String? receiptPath;

  /// Groups it in reports: a built-in's name, or `custom:<id>`.
  String get categoryKey => switch ((category, customCategoryId)) {
    (PersonalCategory.custom, final id?) => 'custom:$id',
    (PersonalCategory.custom, null) => PersonalCategory.other.name,
    (final category, _) => category.name,
  };

  @override
  List<Object?> get props => [
    id,
    title,
    amountCents,
    spentAt,
    category,
    customCategoryId,
    note,
    receiptPath,
  ];
}

/// Everything on the My spending page: your expenses (newest first), your
/// own categories and the currency it's all in.
class PersonalSpending extends Equatable {
  const PersonalSpending({
    required this.expenses,
    required this.categories,
    required this.currency,
  });

  static const empty = PersonalSpending(
    expenses: [],
    categories: [],
    currency: GroupCurrency.thb,
  );

  final List<PersonalExpense> expenses;
  final List<CustomCategory> categories;
  final GroupCurrency currency;

  /// A category's name by its [PersonalExpense.categoryKey].
  String labelOf(String categoryKey) {
    if (categoryKey.startsWith('custom:')) {
      final id = categoryKey.substring('custom:'.length);
      return categories.where((c) => c.id == id).firstOrNull?.name ?? PersonalCategory.other.label;
    }
    return PersonalCategory.values.asNameMap()[categoryKey]?.label ?? PersonalCategory.other.label;
  }

  @override
  List<Object?> get props => [expenses, categories, currency];
}
