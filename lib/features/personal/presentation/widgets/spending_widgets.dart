import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../squad/presentation/squad_formatting.dart';
import '../../../squad/presentation/widgets/sheet_parts.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../../team_membership/domain/entities/team.dart' show GroupCurrency;
import '../../domain/entities/personal_expense.dart';
import '../cubit/personal_spending_cubit.dart';
import '../personal_formatting.dart';
import 'personal_expense_sheet.dart';

/// A category's rounded icon tile, in its colour.
class PersonalCategoryTile extends StatelessWidget {
  const PersonalCategoryTile({super.key, required this.categoryKey, this.size = 40});

  final String categoryKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = personalCategoryTone(categoryKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tone.background, borderRadius: AppRadius.sm),
      child: Icon(personalCategoryIcon(categoryKey), size: size * 0.5, color: tone.foreground),
    );
  }
}

/// The total for the day, month, year or range on the dark hero: what you
/// spent, on how many expenses, and that only you see it.
class SpendingTotalHero extends StatelessWidget {
  const SpendingTotalHero({
    super.key,
    required this.totalCents,
    required this.count,
    required this.currency,
  });

  final int totalCents;
  final int count;
  final GroupCurrency currency;

  @override
  Widget build(BuildContext context) {
    const light = AppColors.onDark;
    return DarkHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOU SPENT', style: AppTextStyles.label(color: AppColors.teamGold)),
          const SizedBox(height: 4),
          Text(
            formatMoney(totalCents, currency),
            key: const ValueKey('report-total'),
            style: AppTextStyles.heading(size: 34, color: AppColors.teamGold, height: 1.15),
          ),
          const SizedBox(height: 4),
          Text(
            switch (count) {
              0 => 'Nothing yet',
              1 => '1 expense',
              final n => '$n expenses',
            },
            style: AppTextStyles.body(size: 12.5, color: light.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: light.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Only you can see your personal spending',
                  style: AppTextStyles.body(size: 12, color: light.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row of [SpendingBars].
typedef SpendingBar = ({String label, String? sub, int cents, String? categoryKey});

/// Amounts as rows with a bar against the biggest; with [total], each
/// row's % of it too. Category rows lead with their tile and take its
/// colour for the bar.
class SpendingBars extends StatelessWidget {
  const SpendingBars({super.key, required this.rows, required this.currency, this.total});

  final List<SpendingBar> rows;
  final GroupCurrency currency;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final biggest = rows.fold(0, (a, row) => row.cents > a ? row.cents : a);
    return SquadCard(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  if (row.categoryKey case final key?) ...[
                    PersonalCategoryTile(categoryKey: key, size: 32),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.label,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              formatMoney(row.cents, currency),
                              style: AppTextStyles.body(size: 13.5, weight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: biggest == 0 ? 0 : row.cents / biggest,
                            minHeight: 6,
                            backgroundColor: AppColors.surface,
                            color: switch (row.categoryKey) {
                              final key? => personalCategoryTone(key).foreground,
                              null => AppColors.accentFill,
                            },
                          ),
                        ),
                        if (row.sub != null || (total ?? 0) > 0) ...[
                          const SizedBox(height: 3),
                          Text(
                            [
                              ?row.sub,
                              if (total case final total? when total > 0)
                                '${(row.cents * 100 / total).round()}% of the total',
                            ].join(' · '),
                            style: AppTextStyles.body(size: 11.5, color: squadMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One personal expense: its category tile, title, category and day, and
/// the amount. Tap to edit.
class PersonalExpenseTile extends StatelessWidget {
  const PersonalExpenseTile({super.key, required this.expense, required this.spending});

  final PersonalExpense expense;
  final PersonalSpending spending;

  @override
  Widget build(BuildContext context) {
    return SquadCard(
      onTap: () => showPersonalExpenseSheet(context, editing: expense),
      child: Row(
        children: [
          PersonalCategoryTile(categoryKey: expense.categoryKey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(size: 15, height: 1.3),
                ),
                Text(
                  [spending.labelOf(expense.categoryKey), formatDayLabel(expense.spentAt)].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
                ),
                if (expense.note case final note? when note.trim().isNotEmpty)
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (expense.receiptPath != null) ...[
            Tooltip(
              message: 'Has a receipt',
              child: Icon(Icons.receipt_long_outlined, size: 16, color: squadMuted),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            formatMoney(expense.amountCents, spending.currency),
            style: AppTextStyles.body(size: 14, weight: FontWeight.w800, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// Nothing in the window: what this page is for, or that this stretch is
/// empty.
class SpendingEmpty extends StatelessWidget {
  const SpendingEmpty({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SquadCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: Icon(Icons.savings_outlined, size: 20, color: squadMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTextStyles.body(size: 13, color: squadMuted, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// "Your categories": delete one (its expenses move to Other).
Future<void> showYourCategoriesSheet(BuildContext context, PersonalSpendingCubit cubit) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (_) => BlocProvider.value(value: cubit, child: const _CategoriesSheet()),
    );

class _CategoriesSheet extends StatelessWidget {
  const _CategoriesSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersonalSpendingCubit, PersonalSpendingState>(
      builder: (context, state) {
        final categories = state.spending?.categories ?? const <CustomCategory>[];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              const SheetGrabber(),
              const SheetHeader(title: 'Your categories'),
              Text(
                'Add one from “New category” when you add an expense. '
                'Deleting one moves its expenses to Other.',
                style: AppTextStyles.body(size: 12.5, color: squadMuted),
              ),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                const SheetNotice('None yet.', icon: Icons.label_outline_rounded),
              for (final category in categories) ...[
                SquadCard(
                  child: Row(
                    children: [
                      PersonalCategoryTile(categoryKey: 'custom:${category.id}', size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category.name,
                          style: AppTextStyles.body(size: 14.5, weight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: state.saving
                            ? null
                            : () => context.read<PersonalSpendingCubit>().deleteCategory(category.id),
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Delete ${category.name}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}
