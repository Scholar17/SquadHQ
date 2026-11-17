import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/match.dart' as match_entity;
import '../../domain/entities/matchday_player.dart' show RsvpAnswer;
import '../match_formatting.dart';

/// One compact row for a single match — used both in Home's preview and
/// the full [MatchListPage] list.
class MatchRow extends StatelessWidget {
  const MatchRow({super.key, required this.match, this.showMyRsvp = false, this.myRsvp});

  final match_entity.Match match;

  /// Whether to show the viewer's own RSVP — Home does, once the wallet
  /// (which carries everyone's answers) has loaded.
  final bool showMyRsvp;

  /// The viewer's answer; null with [showMyRsvp] means they haven't voted.
  final RsvpAnswer? myRsvp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _DateBadge(kickoffAt: match.kickoffAt),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs ${match.opponent}',
                  style: AppTextStyles.title(size: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    formatMatchTime(match.kickoffAt),
                    if (match.venue != null) match.venue!,
                  ].join(' · '),
                  style: AppTextStyles.body(
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showMyRsvp) ...[
            const SizedBox(width: 10),
            _MyRsvpChip(answer: myRsvp),
          ],
        ],
      ),
    );
  }
}

/// The viewer's own RSVP at a glance — "Vote needed" until they answer.
class _MyRsvpChip extends StatelessWidget {
  const _MyRsvpChip({required this.answer});

  final RsvpAnswer? answer;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (answer) {
      RsvpAnswer.yes => ("You're in ✓", AppColors.accent2_700, AppColors.accent2_100),
      RsvpAnswer.maybe => ('Maybe', AppColors.textMuted, AppColors.surface),
      RsvpAnswer.no => ("You're out", AppColors.textMuted, AppColors.surface),
      null => ('Vote needed', AppColors.accent700, AppColors.accent100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.pill),
      child: Text(
        label,
        style: AppTextStyles.body(size: 11, weight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.kickoffAt});

  final DateTime kickoffAt;

  @override
  Widget build(BuildContext context) {
    final local = kickoffAt.toLocal();
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: AppRadius.md,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${local.day}',
            style: AppTextStyles.title(size: 16, color: AppColors.teamGold),
          ),
          Text(
            monthNames[local.month - 1].toUpperCase(),
            style: AppTextStyles.label(
              size: 9,
              color: AppColors.onDark.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
