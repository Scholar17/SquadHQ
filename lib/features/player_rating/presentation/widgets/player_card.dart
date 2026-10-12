import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/player_rating.dart';

/// The dark player card: positions, name, OVR, the six stat bars, and
/// (when given) apps / goals / assists. The numbers count up and the bars
/// fill on first show — the reveal after rating, and opening a card.
class PlayerCardView extends StatelessWidget {
  const PlayerCardView({
    super.key,
    required this.name,
    required this.rating,
    this.player,
    this.caption,
  });

  final String name;
  final PlayerRating rating;

  /// For the footer's apps / goals / assists (saves for a keeper).
  final RatedPlayer? player;

  /// A line under the name, e.g. "Self-rated · levelled up twice".
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final player = this.player;
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppDecorations.darkHero(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating.positions.join(' · '),
                      style: AppTextStyles.label(color: AppColors.teamGold)
                          .copyWith(letterSpacing: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Text(name, style: AppTextStyles.heading(size: 28, color: AppColors.onDark)),
                    if (caption case final caption?) ...[
                      const SizedBox(height: 6),
                      Text(
                        caption,
                        style: AppTextStyles.body(size: 12, color: AppColors.onDarkMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  _CountUp(
                    value: rating.ovr,
                    animate: animate,
                    style: AppTextStyles.heading(size: 44, color: AppColors.teamGold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'OVR',
                    style: AppTextStyles.label(
                      size: 10,
                      color: AppColors.onDarkMuted,
                    ).copyWith(letterSpacing: 1.4),
                  ),
                ],
              ),
            ],
          ),
          Container(
            margin: EdgeInsets.only(top: 20, bottom: player == null ? 0 : 18),
            padding: const EdgeInsets.only(top: 18),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.onDark.withValues(alpha: 0.14))),
            ),
            child: Column(
              children: [
                for (final (index, key) in StatKey.values.indexed) ...[
                  if (index > 0) const SizedBox(height: 11),
                  StatBar(stat: key, value: rating.stat(key), delay: index, animate: animate),
                ],
              ],
            ),
          ),
          if (player != null)
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.onDark.withValues(alpha: 0.14))),
              ),
              child: Row(
                children: [
                  _FooterStat(value: player.apps, label: 'Apps'),
                  // What their position is judged on — a defender's clean
                  // sheets, not their (few) goals.
                  ...switch (rating.group) {
                    PositionGroup.goalkeeper => [
                      _FooterStat(value: player.cleanSheets, label: 'Clean sheets'),
                      _FooterStat(value: player.saves, label: 'Saves'),
                    ],
                    PositionGroup.defender => [
                      _FooterStat(value: player.cleanSheets, label: 'Clean sheets'),
                      _FooterStat(value: player.tackles, label: 'Tackles'),
                    ],
                    _ => [
                      _FooterStat(value: player.goals, label: 'Goals'),
                      _FooterStat(value: player.assists, label: 'Assists'),
                    ],
                  },
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "PAC  ███████░░░  78" on the dark card.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.stat,
    required this.value,
    this.delay = 0,
    this.animate = true,
  });

  final StatKey stat;
  final int value;

  /// Staggers the fill, so the bars land one after another.
  final int delay;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${stat.label} $value',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              stat.short,
              style: AppTextStyles.label(size: 11, color: AppColors.onDarkMuted),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.pill,
              child: SizedBox(
                height: 7,
                child: ColoredBox(
                  color: AppColors.onDark.withValues(alpha: 0.1),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: animate ? 0 : value / 99, end: value / 99),
                    duration: Duration(milliseconds: animate ? 700 + delay * 90 : 0),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: t.clamp(0, 1),
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: value >= 75 ? AppColors.teamGold : AppColors.accent400,
                            borderRadius: AppRadius.pill,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: AppTextStyles.title(size: 14, color: AppColors.onDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style, required this.animate});

  final int value;
  final TextStyle style;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (!animate) return Text('$value', style: style);
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => Text('$shown', style: style),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: AppTextStyles.heading(size: 22, color: AppColors.onDark)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.body(size: 11.5, color: AppColors.onDarkMuted)),
        ],
      ),
    );
  }
}

/// "Self-rated" or "Self-rated · levelled up 2×".
String ratingCaption(PlayerRating rating) => switch (rating.improvements) {
  0 => 'Self-rated',
  1 => 'Self-rated · levelled up once',
  final n => 'Self-rated · levelled up $n×',
};
