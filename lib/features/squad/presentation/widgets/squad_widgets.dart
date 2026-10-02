import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/squad_ledger.dart';
import '../squad_formatting.dart';

/// Caption grey on the cream background.
const squadMuted = AppColors.neutral700;

/// "You owe" / "is owed" colours, as the design uses them.
const oweColor = AppColors.accent700;
const owedColor = AppColors.accent2_700;

class SquadSectionLabel extends StatelessWidget {
  const SquadSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(text, style: AppTextStyles.label(color: squadMuted)),
        ),
        if (trailing != null) Text(trailing!, style: AppTextStyles.label(color: squadMuted)),
      ],
    );
  }
}

/// A round initial, gold for whoever's being paid or highlighted.
class SquadAvatar extends StatelessWidget {
  const SquadAvatar({super.key, required this.initial, this.size = 40, this.color});

  final String initial;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color ?? AppColors.neutral300, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.body(size: size * 0.32, weight: FontWeight.w800, height: 1),
      ),
    );
  }
}

/// A cream surface card with a hairline border, tappable when [onTap].
class SquadCard extends StatelessWidget {
  const SquadCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.radius = 16,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: AppColors.text.withValues(alpha: 0.1)),
    );
    return Material(
      color: AppColors.neutral100,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// The dark card the squad's balances lead with.
class DarkHeroCard extends StatelessWidget {
  const DarkHeroCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

/// A pill-shaped button on the dark card: [light] filled, else outlined.
class HeroPillButton extends StatelessWidget {
  const HeroPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.light = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool light;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = light ? AppColors.text : AppColors.neutral100;
    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: light ? AppColors.neutral100 : Colors.transparent,
          foregroundColor: fg,
          shape: StadiumBorder(
            side: light
                ? BorderSide.none
                : BorderSide(color: AppColors.neutral100.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        // Half the hero card's width on a narrow phone: the label gives way
        // (ellipsis) rather than overflowing.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.heading(size: 14, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The filled primary button at the bottom of a sheet or form.
class SquadPrimaryButton extends StatelessWidget {
  const SquadPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color = AppColors.accent700,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          shape: const StadiumBorder(),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.neutral100),
              )
            : Text(label, style: AppTextStyles.heading(size: 16, color: AppColors.neutral100)),
      ),
    );
  }
}

/// A chip that's dark when [selected] — category filters, currencies.
class SquadChoiceChip extends StatelessWidget {
  const SquadChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.neutral100 : AppColors.text;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.neutral900 : AppColors.neutral100,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.neutral900 : AppColors.text.withValues(alpha: 0.14),
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                Text(
                  label,
                  style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One expense in a list: its category tile, title, who paid, and what it
/// means for [me] — "you owe ฿300", "you lent ฿600", "not in it".
class ExpenseRow extends StatelessWidget {
  const ExpenseRow({
    super.key,
    required this.expense,
    required this.ledger,
    required this.me,
    required this.onTap,
  });

  final Expense expense;
  final SquadLedger ledger;
  final String me;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final payer = ledger.nameOf(expense.payerId, me: me);
    final net = expense.netFor(me);
    final (label, amount, color) = switch (expense) {
      _ when expense.splitMode == ExpenseSplitMode.treat => (
        'treat',
        formatMoney(expense.amountCents, currency),
        squadMuted,
      ),
      _ when net < 0 => ('you owe', formatMoney(-net, currency), oweColor),
      _ when net > 0 => ('you lent', formatMoney(net, currency), owedColor),
      _ when !expense.includes(me) && expense.payerId != me => ('not in it', '—', squadMuted),
      _ => ('your share', formatMoney(expense.shareOf(me), currency), squadMuted),
    };
    return SquadCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(categoryIcon(expense.category), size: 20, color: oweColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading(size: 15, height: 1.3),
                ),
                Text(
                  '$payer paid ${formatMoney(expense.amountCents, currency)} · '
                  '${formatShortDate(expense.spentAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label, style: AppTextStyles.body(size: 11, color: squadMuted, height: 1.3)),
              Text(
                amount,
                style: AppTextStyles.body(
                  size: 14,
                  weight: FontWeight.w800,
                  color: color,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
