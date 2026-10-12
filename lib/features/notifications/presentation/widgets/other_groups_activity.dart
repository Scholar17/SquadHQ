import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../squad/presentation/active_group.dart' show groupInitials;
import '../../../team_membership/domain/entities/team.dart';
import '../../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../../team_membership/presentation/bloc/team_membership_event.dart';
import '../../../team_membership/presentation/bloc/team_membership_state.dart';
import '../../domain/entities/app_notification.dart';
import '../bloc/notification_bloc.dart';
import '../pages/notifications_page.dart' show formatNotificationTime;

/// On Home: a card for each of your other groups with unread
/// notifications — how many, and the latest — so nothing in a team or
/// squad you're not looking at goes unseen. Tapping one switches to it.
/// Nothing shows when the other groups are all caught up.
class OtherGroupsActivity extends StatelessWidget {
  const OtherGroupsActivity({super.key, this.padding = EdgeInsets.zero});

  /// Around the section, only when it shows.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final membership = switch (context.watch<TeamMembershipBloc>().state) {
      TeamMembershipSubmitting(:final previous) ||
      TeamMembershipFailure(:final previous) => previous,
      final state => state,
    };
    if (membership is! TeamMembershipLoaded) return const SizedBox.shrink();
    final unread = [
      for (final item in context.watch<NotificationBloc>().state.items)
        if (!item.isRead) item,
    ];
    // Newest first, so the group with the latest news leads.
    final groups =
        <({Team team, List<AppNotification> unread})>[
            for (final team in membership.teams)
              if (!team.isActive)
                (
                  team: team,
                  unread: [
                    for (final item in unread)
                      if (item.teamId == team.id) item,
                  ],
                ),
          ].where((group) => group.unread.isNotEmpty).toList()
          ..sort((a, b) => b.unread.first.createdAt.compareTo(a.unread.first.createdAt));
    if (groups.isEmpty) return const SizedBox.shrink();

    void open(Team team) => context.read<TeamMembershipBloc>().add(TeamSwitchRequested(team.id));

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('IN YOUR OTHER GROUPS', style: AppTextStyles.label(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          if (groups case [final only])
            _GroupCard(team: only.team, unread: only.unread, onTap: () => open(only.team))
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => SizedBox(
                  width: 260,
                  child: _GroupCard(
                    team: groups[index].team,
                    unread: groups[index].unread,
                    onTap: () => open(groups[index].team),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.team, required this.unread, required this.onTap});

  final Team team;

  /// Newest first; never empty.
  final List<AppNotification> unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = unread.first;
    final muted = AppColors.textMuted;
    final shape = RoundedRectangleBorder(
      borderRadius: AppRadius.lg,
      side: BorderSide(color: AppColors.text.withValues(alpha: 0.1)),
    );
    return Semantics(
      button: true,
      label: 'Open ${team.name}, ${unread.length} new',
      child: Material(
        color: AppColors.card,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.neutral900,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        groupInitials(team.name),
                        style: AppTextStyles.body(
                          size: 12,
                          weight: FontWeight.w800,
                          color: AppColors.teamGold,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              size: 14,
                              weight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          Text(
                            team.isSquad ? 'Squad' : 'Football team',
                            style: AppTextStyles.body(size: 11.5, color: muted, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentFill,
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        '${unread.length} new',
                        style: AppTextStyles.body(
                          size: 11.5,
                          weight: FontWeight.w800,
                          color: AppColors.onDark,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        latest.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(size: 13, weight: FontWeight.w600, height: 1.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatNotificationTime(latest.createdAt),
                      style: AppTextStyles.body(size: 11.5, color: muted, height: 1.3),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: muted),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
