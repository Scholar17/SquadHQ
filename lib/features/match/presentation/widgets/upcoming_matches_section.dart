import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/match.dart' as match_entity;
import '../../domain/entities/matchday_player.dart' show RsvpAnswer;
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
    this.myRsvps = const {},
  });

  final List<match_entity.Match> matches;
  final bool canCreateMatch;
  final VoidCallback? onCreateMatch;
  final VoidCallback onSeeAll;
  final ValueChanged<match_entity.Match> onMatchTap;

  /// The viewer's RSVP per match id — a match with an entry shows it (a
  /// null value meaning "not voted yet"); one without shows nothing.
  final Map<String, RsvpAnswer?> myRsvps;

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
                style: AppTextStyles.label(color: AppColors.textMuted),
              ),
            ),
            if (canCreateMatch)
              TextButton(
                onPressed: onCreateMatch,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onDark,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  '+ New match',
                  style: AppTextStyles.title(size: 12, color: AppColors.onDark),
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
              borderRadius: AppRadius.lg,
              child: InkWell(
                borderRadius: AppRadius.lg,
                onTap: () => onMatchTap(match),
                child: MatchRow(
                  match: match,
                  showMyRsvp: myRsvps.containsKey(match.id),
                  myRsvp: myRsvps[match.id],
                ),
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
        color: AppColors.card,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No upcoming match', style: AppTextStyles.title(size: 16)),
          const SizedBox(height: 6),
          Text(
            canCreate
                ? 'Tap "+ New match" to schedule the next one.'
                : "Your team's admin hasn't scheduled one yet.",
            style: AppTextStyles.body(
              size: 12.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
