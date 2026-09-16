import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team_snapshot.dart';

class LastTimeOutCard extends StatelessWidget {
  const LastTimeOutCard({super.key, required this.result});

  final MatchResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST TIME OUT',
            style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  result.homeTeam,
                  style: AppTextStyles.heading(size: 15),
                ),
              ),
              Text(
                '${result.homeScore} – ${result.awayScore}',
                style: AppTextStyles.heading(size: 26, color: AppColors.accent2_700),
              ),
              Expanded(
                child: Text(
                  result.awayTeam,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.heading(size: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.summary,
            style: AppTextStyles.body(
              size: 12,
              weight: FontWeight.w500,
              color: AppColors.text.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
