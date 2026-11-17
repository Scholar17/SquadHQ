import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/bounce_tap.dart';
import '../../../../core/theme/widgets/skeletons.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/squad_ledger.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';

/// Caption grey on the cream background.
Color get squadMuted => AppColors.textMuted;

/// "You owe" / "is owed" colours, as the design uses them.
Color get oweColor => AppColors.accent700;
Color get owedColor => AppColors.accent2_700;

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

/// The first [previewCount] of [children], spaced by [spacing], with
/// "See more (n)" expanding the rest in place and "Show less" folding them
/// back — so a long section doesn't push everything below it off screen.
class SeeMoreList extends StatefulWidget {
  const SeeMoreList({
    super.key,
    required this.children,
    this.previewCount = 3,
    this.spacing = 8,
    this.color,
  });

  final List<Widget> children;
  final int previewCount;
  final double spacing;
  final Color? color;

  @override
  State<SeeMoreList> createState() => _SeeMoreListState();
}

class _SeeMoreListState extends State<SeeMoreList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final children = widget.children;
    final hidden = children.length - widget.previewCount;
    final shown = _expanded || hidden <= 0 ? children : children.take(widget.previewCount);
    final actionColor = widget.color ?? oweColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Grows and folds smoothly instead of jumping, anchored at the top
        // so the rows above stay put.
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in shown) ...[child, SizedBox(height: widget.spacing)],
            ],
          ),
        ),
        if (hidden > 0)
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              iconAlignment: IconAlignment.end,
              icon: Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18,
                color: actionColor,
              ),
              label: Text(
                _expanded ? 'Show less' : 'See more ($hidden)',
                style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: actionColor),
              ),
              style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ),
      ],
    );
  }
}

/// A round initial, gold for whoever's being paid or highlighted — or
/// their profile photo, when they have one ([photoUrl]); the initial shows
/// while it loads and if it can't (e.g. an expired Facebook link).
class SquadAvatar extends StatelessWidget {
  const SquadAvatar({super.key, required this.initial, this.size = 40, this.color, this.photoUrl});

  final String initial;
  final double size;
  final Color? color;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final letter = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color ?? AppColors.neutral300, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.body(size: size * 0.32, weight: FontWeight.w800, height: 1),
      ),
    );
    final url = photoUrl;
    if (url == null || url.isEmpty) return letter;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          letter,
          ClipOval(
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Scaled for the avatar, not the full photo.
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
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
      side: BorderSide(color: AppColors.divider),
    );
    final card = Material(
      color: AppColors.card,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return card;
    return BounceTap(onTap: onTap, child: card);
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
      decoration: AppDecorations.darkHero(),
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
    final fg = light ? AppColors.onLight : AppColors.onDark;
    return BounceTap(
      onTap: onPressed,
      child: SizedBox(
        height: 44,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: light ? AppColors.onDark : Colors.transparent,
            foregroundColor: fg,
            shape: StadiumBorder(
              side: light
                  ? BorderSide.none
                  : BorderSide(color: AppColors.onDark.withValues(alpha: 0.35)),
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
                  style: AppTextStyles.title(size: 14, color: fg),
                ),
              ),
            ],
          ),
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
    this.color = AppColors.accentFill,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BounceTap(
      onTap: isLoading ? null : onPressed,
      child: SizedBox(
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
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onDark),
                )
              : Text(label, style: AppTextStyles.title(size: 16, color: AppColors.onDark)),
        ),
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
    final fg = selected ? AppColors.onDark : AppColors.text;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.neutral900 : AppColors.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.neutral900 : AppColors.divider,
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
    this.showTrip = true,
  });

  final Expense expense;
  final SquadLedger ledger;
  final String me;
  final VoidCallback onTap;

  /// A trip expense says which trip — not needed on the trip's own page.
  final bool showTrip;

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final payer = ledger.paidByLabel(expense, me: me);
    final net = expense.netFor(me);
    final (label, amount, color) = switch (expense) {
      _ when expense.splitMode == ExpenseSplitMode.treat => (
        'treat',
        formatMoney(expense.amountCents, currency),
        squadMuted,
      ),
      _ when net < 0 => ('you owe', formatMoney(-net, currency), oweColor),
      _ when net > 0 => ('you lent', formatMoney(net, currency), owedColor),
      _ when !expense.includes(me) && !expense.payers.containsKey(me) => (
        'not in it',
        '—',
        squadMuted,
      ),
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
              color: categoryTone(expense.category).background,
              borderRadius: AppRadius.sm,
            ),
            child: Icon(
              categoryIcon(expense.category),
              size: 20,
              color: categoryTone(expense.category).foreground,
            ),
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
                  style: AppTextStyles.title(size: 15, height: 1.3),
                ),
                Text(
                  [
                    if (showTrip)
                      if (expense.tripId case final tripId?)
                        if (ledger.trip(tripId) case final trip?) '${trip.name} trip',
                    if (expense.recurringId != null) '🔁 Monthly',
                    expense.categoryName,
                    '$payer paid ${formatMoney(expense.amountCents, currency)}',
                    formatShortDate(expense.spentAt),
                  ].join(' · '),
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

/// What a squad screen shows before its ledger is in: a spinner while
/// loading, or — if the load failed — the reason and a Retry button,
/// rather than an empty squad that looks real.
class SquadLoadingView extends StatelessWidget {
  const SquadLoadingView({super.key, required this.state});

  final SquadLedgerState state;

  @override
  Widget build(BuildContext context) {
    final failure = state;
    if (failure is! SquadLedgerFailure) {
      return const SkeletonList(item: ExpenseRowSkeleton(), count: 6, spacing: 8);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: squadMuted),
            const SizedBox(height: 12),
            Text(
              "Couldn't load this squad",
              textAlign: TextAlign.center,
              style: AppTextStyles.title(size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              failure.message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(size: 13, color: squadMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.read<SquadLedgerBloc>().add(const SquadRefreshRequested()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                minimumSize: const Size(0, 44),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where paying someone back stands: still to pay, sent and waiting for
/// them to confirm, or done.
enum PayStatus { pay, pending, paid }

/// "Pay" while there's something to pay; a "Pending" or "Paid" tag after.
class PayStatusButton extends StatelessWidget {
  const PayStatusButton({super.key, required this.status, this.onPay});

  final PayStatus status;

  /// Opens the pay sheet; only used while [status] is [PayStatus.pay].
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      PayStatus.pay => ('Pay', AppColors.onDark, AppColors.accentFill),
      PayStatus.pending => ('Pending', oweColor, oweColor.withValues(alpha: 0.12)),
      PayStatus.paid => ('Paid', AppColors.accent2_900, AppColors.accent2_100),
    };
    final text = Text(
      label,
      style: AppTextStyles.body(size: 12.5, weight: FontWeight.w800, height: 1.2, color: fg),
    );
    if (status != PayStatus.pay) {
      return Container(
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == PayStatus.paid ? Icons.check_rounded : Icons.schedule_rounded,
              size: 14,
              color: fg,
            ),
            const SizedBox(width: 4),
            text,
          ],
        ),
      );
    }
    return TextButton(
      onPressed: onPay,
      style: TextButton.styleFrom(
        foregroundColor: fg,
        backgroundColor: bg,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(),
      ),
      child: text,
    );
  }
}

/// A payment waiting for you to check and confirm — made to stand out: a
/// red dot like an unread notification, a warm highlight, and a red Check
/// button. On Home, Settle and a trip's page.
class CheckPaymentCard extends StatelessWidget {
  const CheckPaymentCard({super.key, required this.title, this.detail, required this.onTap});

  final String title;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Needs your check',
      child: Material(
        color: AppColors.accent100,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lg,
          side: const BorderSide(color: AppColors.accent400, width: 1.5),
        ),
        child: InkWell(
          borderRadius: AppRadius.lg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_outlined, size: 20, color: oweColor),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        key: const ValueKey('check-dot'),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.unread,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accent100, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEEDS YOUR CHECK',
                        style: AppTextStyles.label(color: AppColors.unread),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: AppTextStyles.body(size: 14, weight: FontWeight.w700, height: 1.3),
                      ),
                      if (detail case final detail? when detail.isNotEmpty)
                        Text(
                          detail,
                          style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.unread,
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    'Check',
                    style: AppTextStyles.body(
                      size: 13,
                      weight: FontWeight.w800,
                      color: AppColors.onDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
