import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/match.dart' as match_entity;
import '../match_formatting.dart';

/// One compact row for a single match — used both in Home's preview and
/// the full [MatchListPage] list.
class MatchRow extends StatelessWidget {
  const MatchRow({super.key, required this.match});

  final match_entity.Match match;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
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
                  style: AppTextStyles.heading(size: 16),
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
                    color: AppColors.text.withValues(alpha: 0.55),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${local.day}',
            style: AppTextStyles.heading(size: 16, color: AppColors.teamGold),
          ),
          Text(
            monthNames[local.month - 1].toUpperCase(),
            style: AppTextStyles.label(
              size: 9,
              color: AppColors.neutral100.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
