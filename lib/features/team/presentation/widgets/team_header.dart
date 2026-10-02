import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team_snapshot.dart';

class TeamHeader extends StatelessWidget {
  const TeamHeader({
    super.key,
    required this.team,
    this.role,
    required this.profileInitials,
    required this.onTeamTap,
    this.onRoleToggle,
    required this.onBellTap,
    required this.onProfileTap,
  });

  final TeamInfo team;
  /// The Manager/Player view pill — null hides it (squads have no views).
  final SquadRole? role;
  final String profileInitials;
  final VoidCallback onTeamTap;
  final VoidCallback? onRoleToggle;
  final VoidCallback onBellTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTeamTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Row(
                  children: [
                    _TeamMark(initials: team.initials),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  team.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body(
                                    size: 14,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '▾',
                                style: AppTextStyles.body(
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: AppColors.text.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            team.meta,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              size: 11,
                              weight: FontWeight.w500,
                              color: AppColors.text.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (role case final role?) ...[
            _RolePill(role: role, onTap: onRoleToggle ?? () {}),
            const SizedBox(width: 6),
          ],
          _IconButton(onTap: onBellTap, badgeCount: team.alertCount),
          const SizedBox(width: 6),
          _ProfileAvatar(initials: profileInitials, onTap: onProfileTap),
        ],
      ),
    );
  }
}

class _TeamMark extends StatelessWidget {
  const _TeamMark({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: AppColors.teamGold,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTextStyles.heading(size: 14, color: AppColors.neutral800),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role, required this.onTap});

  final SquadRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.neutral900,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          role == SquadRole.manager ? 'Manager' : 'Player',
          style: AppTextStyles.heading(size: 12, color: AppColors.neutral100),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.onTap, required this.badgeCount});

  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.text.withValues(alpha: 0.1),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.notifications_none_rounded,
                size: 18,
                color: AppColors.text.withValues(alpha: 0.8),
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  height: 17,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: AppTextStyles.body(
                      size: 10,
                      weight: FontWeight.w700,
                      color: AppColors.bg,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.initials, required this.onTap});

  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.neutral300,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: AppTextStyles.body(size: 12, weight: FontWeight.w700),
        ),
      ),
    );
  }
}
