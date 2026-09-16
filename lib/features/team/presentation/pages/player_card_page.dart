import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team_snapshot.dart';

/// The player card — reached in context from the Squad list, not parked
/// in a nav. Broadcast-dark variant, matching the login screen's ink
/// surface treatment.
class PlayerCardPage extends StatelessWidget {
  const PlayerCardPage({super.key, required this.member});

  final SquadMember member;

  @override
  Widget build(BuildContext context) {
    final card = member.card;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Player card', style: AppTextStyles.heading(size: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.neutral900,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(color: Color(0x402E2B25), blurRadius: 20, offset: Offset(0, 10)),
                ],
              ),
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
                              member.position.toUpperCase(),
                              style: AppTextStyles.body(
                                size: 11,
                                weight: FontWeight.w700,
                                color: AppColors.teamGold,
                              ).copyWith(letterSpacing: 1.4),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              member.name,
                              style: AppTextStyles.heading(size: 30, color: AppColors.neutral100),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '#${member.number} · joined ${member.joinedYear}',
                              style: AppTextStyles.body(
                                size: 12,
                                weight: FontWeight.w500,
                                color: AppColors.neutral100.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${member.ovr}',
                            style: AppTextStyles.heading(size: 42, color: AppColors.teamGold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'OVR',
                            style: AppTextStyles.body(
                              size: 10,
                              weight: FontWeight.w700,
                              color: AppColors.neutral100.withValues(alpha: 0.55),
                            ).copyWith(letterSpacing: 1.4),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 20, bottom: 18),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0x24F9F4ED)),
                        bottom: BorderSide(color: Color(0x24F9F4ED)),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final stat in card.stats) ...[
                          _StatBar(stat: stat),
                          if (stat != card.stats.last) const SizedBox(height: 11),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _FooterStat(value: '${card.apps}', label: 'Apps'),
                      _FooterStat(value: '${card.goals}', label: 'Goals'),
                      _FooterStat(value: '${card.assists}', label: 'Assists'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '${member.name} has played ${card.apps} matches this season '
                'for Golden Goal FC · ${member.seasonLine}.',
                style: AppTextStyles.body(
                  size: 12.5,
                  weight: FontWeight.w500,
                  color: AppColors.text.withValues(alpha: 0.65),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.stat});

  final PlayerStat stat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            stat.label.toUpperCase(),
            style: AppTextStyles.body(
              size: 11.5,
              weight: FontWeight.w600,
              color: AppColors.neutral100.withValues(alpha: 0.62),
            ).copyWith(letterSpacing: 0.6),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: const Color(0x24F9F4ED)),
                  FractionallySizedBox(
                    widthFactor: (stat.value / 99).clamp(0, 1),
                    child: Container(color: AppColors.teamGold),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '${stat.value}',
            textAlign: TextAlign.right,
            style: AppTextStyles.body(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.neutral100,
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.heading(size: 20, color: AppColors.neutral100)),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTextStyles.body(
              size: 10.5,
              weight: FontWeight.w500,
              color: AppColors.neutral100.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}
