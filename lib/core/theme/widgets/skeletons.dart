import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_shadows.dart';
import 'shimmer_effect.dart';

/// Loading placeholders shaped like the cards they stand in for, so the
/// layout doesn't jump when the data lands.
///
/// Each card keeps its own surface and shimmers only its boxes — a
/// [Shimmer] over the card would tint the card itself.

/// The card every skeleton sits on: the cream surface with a hairline.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: radius,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
        boxShadow: AppShadows.subtle,
      ),
      child: Shimmer(child: child),
    );
  }
}

/// Stands in for the next-match hero card: kickoff line, opponent,
/// venue, the four stats and the two pill buttons.
class MatchCardSkeleton extends StatelessWidget {
  const MatchCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SkeletonCard(
      padding: EdgeInsets.all(22),
      radius: AppRadius.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 120, height: 10),
              Spacer(),
              SkeletonBox(width: 56, height: 10),
            ],
          ),
          SizedBox(height: 16),
          SkeletonBox(width: 190, height: 28),
          SizedBox(height: 8),
          SkeletonBox(width: 150, height: 12),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _StatSkeleton()),
              Expanded(child: _StatSkeleton()),
              Expanded(child: _StatSkeleton()),
              Expanded(child: _StatSkeleton()),
            ],
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 46, radius: AppRadius.pill)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(height: 46, radius: AppRadius.pill)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 36, height: 20),
        SizedBox(height: 6),
        SkeletonBox(width: 48, height: 9),
      ],
    );
  }
}

/// Stands in for a match bill: heading, total and payer on the left,
/// the share on the right, then the paid-back bar.
class BillCardSkeleton extends StatelessWidget {
  const BillCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 150, height: 12),
          SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 100, height: 12),
                    SizedBox(height: 6),
                    SkeletonBox(width: 80, height: 10),
                    SizedBox(height: 6),
                    SkeletonBox(width: 64, height: 10),
                  ],
                ),
              ),
              SkeletonBox(width: 72, height: 26),
            ],
          ),
          SizedBox(height: 16),
          SkeletonBox(height: 6, radius: AppRadius.pill),
          SizedBox(height: 8),
          SkeletonBox(width: 90, height: 10),
        ],
      ),
    );
  }
}

/// Stands in for a squad expense row: category tile, title and meta,
/// the amount on the right.
class ExpenseRowSkeleton extends StatelessWidget {
  const ExpenseRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SkeletonCard(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      radius: AppRadius.md,
      child: Row(
        children: [
          SkeletonBox(width: 40, height: 40, radius: AppRadius.sm),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 130, height: 13),
                SizedBox(height: 7),
                SkeletonBox(width: 90, height: 10),
              ],
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBox(width: 44, height: 9),
              SizedBox(height: 7),
              SkeletonBox(width: 60, height: 13),
            ],
          ),
        ],
      ),
    );
  }
}

/// [count] copies of a skeleton, spaced like the real list — the whole
/// body of a screen that's still loading.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    required this.item,
    this.count = 4,
    this.spacing = 12,
    this.leading,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 32),
  });

  final Widget item;
  final int count;
  final double spacing;

  /// A bigger card shown first, e.g. the hero.
  final Widget? leading;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      // The boxes are decoration; the label says it all.
      excludeSemantics: true,
      child: ListView(
        padding: padding,
        // Nothing to scroll to yet.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          if (leading != null) ...[leading!, SizedBox(height: spacing * 2)],
          for (var i = 0; i < count; i++) ...[if (i > 0) SizedBox(height: spacing), item],
        ],
      ),
    );
  }
}
