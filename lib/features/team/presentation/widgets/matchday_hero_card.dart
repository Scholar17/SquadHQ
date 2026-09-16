import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team_snapshot.dart';

class MatchdayHeroCard extends StatelessWidget {
  const MatchdayHeroCard({
    super.key,
    required this.match,
    required this.isManager,
    required this.myRsvp,
    required this.onOpenMatchday,
    required this.onRemind,
    required this.onRsvpIn,
    required this.onRsvpOut,
  });

  final UpcomingMatch match;
  final bool isManager;
  final RsvpStatus myRsvp;
  final VoidCallback onOpenMatchday;
  final VoidCallback onRemind;
  final VoidCallback onRsvpIn;
  final VoidCallback onRsvpOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x292E2B25), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  match.kickoffLabel,
                  style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.teamGold,
                  ).copyWith(letterSpacing: 1.4),
                ),
              ),
              Text(
                match.countdownLabel,
                style: AppTextStyles.body(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppColors.neutral100.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'vs ${match.opponent}',
            style: AppTextStyles.heading(size: 29, color: AppColors.neutral100),
          ),
          const SizedBox(height: 4),
          Text(
            match.venueLine,
            style: AppTextStyles.body(
              size: 13,
              color: AppColors.neutral100.withValues(alpha: 0.62),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 20, bottom: 18),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0x24F9F4ED)),
                bottom: BorderSide(color: Color(0x24F9F4ED)),
              ),
            ),
            child: Row(
              children: [
                _Stat(value: match.confirmedOf, label: 'confirmed'),
                _Stat(value: match.feePerPlayer, label: 'per player'),
                _Stat(
                  value: '${match.temperatureC}°',
                  label: '${match.rainChancePercent}% rain · low risk',
                ),
                _Stat(value: match.kit, label: 'kit'),
              ],
            ),
          ),
          if (isManager)
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: 'Open matchday',
                    onTap: onOpenMatchday,
                    filled: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PillButton(
                    label: 'Remind squad',
                    onTap: onRemind,
                    filled: false,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: myRsvp == RsvpStatus.yes ? "You're in ✓" : "I'm in",
                    onTap: onRsvpIn,
                    filled: myRsvp == RsvpStatus.yes || myRsvp == RsvpStatus.pending,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PillButton(
                    label: "Can't make it",
                    onTap: onRsvpOut,
                    filled: myRsvp == RsvpStatus.no,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.heading(size: 22, color: AppColors.teamGold),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTextStyles.body(
              size: 11,
              weight: FontWeight.w500,
              color: AppColors.neutral100.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single pill button that can render either filled (gold, selected) or
/// outlined (unselected) — used for both the manager's static CTAs and the
/// player's toggleable RSVP choices.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teamGold,
                foregroundColor: AppColors.neutral800,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text(
                label,
                style: AppTextStyles.heading(size: 14, color: AppColors.neutral800),
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.neutral100,
                side: const BorderSide(color: Color(0x47F9F4ED)),
                shape: const StadiumBorder(),
              ),
              child: Text(
                label,
                style: AppTextStyles.heading(size: 14, color: AppColors.neutral100),
              ),
            ),
    );
  }
}
