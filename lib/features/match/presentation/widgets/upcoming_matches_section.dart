import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/match.dart' as match_entity;
import 'match_row.dart';

/// Home's "NEXT MATCHES" block — up to [previewCount] matches, with a
/// "See all" button once there are more than that. Tapping a match opens
/// its detail screen.
class UpcomingMatchesSection extends StatelessWidget {
  const UpcomingMatchesSection({
    super.key,
    required this.matches,
    required this.canCreateMatch,
    required this.onCreateMatch,
    required this.onSeeAll,
    required this.onMatchTap,
  });

  final List<match_entity.Match> matches;
  final bool canCreateMatch;
  final VoidCallback? onCreateMatch;
  final VoidCallback onSeeAll;
  final ValueChanged<match_entity.Match> onMatchTap;

  static const previewCount = 3;

  @override
  Widget build(BuildContext context) {
    final preview = matches.take(previewCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'NEXT MATCHES',
                style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
              ),
            ),
            if (canCreateMatch)
              TextButton(
                onPressed: onCreateMatch,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.bg,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  '+ New match',
                  style: AppTextStyles.heading(size: 12, color: AppColors.bg),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (preview.isEmpty)
          _EmptyState(canCreate: canCreateMatch)
        else ...[
          for (final match in preview) ...[
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onMatchTap(match),
                child: MatchRow(match: match),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (matches.length > previewCount)
            Center(
              child: TextButton(
                onPressed: onSeeAll,
                child: Text(
                  'See all matches (${matches.length})',
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.accent700,
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canCreate});

  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No upcoming match', style: AppTextStyles.heading(size: 16)),
          const SizedBox(height: 6),
          Text(
            canCreate
                ? 'Tap "+ New match" to schedule the next one.'
                : "Your team's admin hasn't scheduled one yet.",
            style: AppTextStyles.body(
              size: 12.5,
              color: AppColors.text.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
