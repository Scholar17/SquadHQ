import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../../team_membership/presentation/bloc/team_membership_state.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/usecases/invite_usecases.dart';

/// Your pending invitations, for [builder] — loaded on show, and again
/// when a notification arrives, your groups change (one was accepted) or
/// the Invitations screen closes. [builder] gets an empty list until loaded.
class MyInvitations extends StatefulWidget {
  const MyInvitations({super.key, required this.builder});

  final Widget Function(BuildContext context, List<GroupInvite> invites, VoidCallback open) builder;

  @override
  State<MyInvitations> createState() => _MyInvitationsState();
}

class _MyInvitationsState extends State<MyInvitations> {
  List<GroupInvite> _invites = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<GetMyInvites>()(const NoParams());
    if (!mounted) return;
    result.fold((_) {}, (invites) => setState(() => _invites = invites));
  }

  Future<void> _open() async {
    await context.push(AppRoutes.invitations);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<NotificationBloc, NotificationState>(
          listenWhen: (previous, current) => previous.items.length != current.items.length,
          listener: (_, _) => _load(),
        ),
        BlocListener<TeamMembershipBloc, TeamMembershipState>(
          listenWhen: (previous, current) => current is TeamMembershipLoaded,
          listener: (_, _) => _load(),
        ),
      ],
      child: widget.builder(context, _invites, _open),
    );
  }
}

/// On Home while you have invitations: "You're invited to Sunday FC" (or
/// how many), opening the Invitations screen. Nothing when there are none.
class InvitationsBanner extends StatelessWidget {
  const InvitationsBanner({super.key, this.padding = EdgeInsets.zero});

  /// Around the banner, only when it shows.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return MyInvitations(
      builder: (context, invites, open) {
        if (invites.isEmpty) return const SizedBox.shrink();
        final first = invites.first;
        final title = invites.length == 1
            ? "You're invited to ${first.teamName}"
            : 'You have ${invites.length} invitations';
        final body = invites.length == 1
            ? '${first.invitedByName ?? 'An admin'} invited you to join the '
                  '${first.isSquad ? 'squad' : 'team'}.'
            : 'Teams and squads waiting on your answer.';
        return Padding(
          padding: padding,
          child: Material(
            color: AppColors.accent100,
            borderRadius: AppRadius.lg,
            child: InkWell(
              key: const ValueKey('invitations-banner'),
              borderRadius: AppRadius.lg,
              onTap: open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
                      child: Icon(Icons.group_add_rounded, color: AppColors.accent700, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTextStyles.title(size: 14.5)),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style: AppTextStyles.body(size: 12.5, color: AppColors.textSubtle),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('See', style: AppTextStyles.title(size: 13.5, color: AppColors.accent700)),
                    Icon(Icons.chevron_right_rounded, color: AppColors.accent700),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Invitations" with how many are waiting, opening the Invitations screen
/// — in the group switcher and on the Groups page. Nothing when there are
/// none. [beforeOpen]: e.g. closing the switcher sheet first.
class InvitationsRow extends StatelessWidget {
  const InvitationsRow({super.key, this.padding = EdgeInsets.zero, this.beforeOpen});

  final EdgeInsets padding;
  final VoidCallback? beforeOpen;

  @override
  Widget build(BuildContext context) {
    return MyInvitations(
      builder: (context, invites, open) {
        if (invites.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: padding,
          child: Material(
            color: AppColors.card,
            borderRadius: AppRadius.md,
            child: InkWell(
              key: const ValueKey('invitations-row'),
              borderRadius: AppRadius.md,
              onTap: () {
                final router = GoRouter.of(context);
                if (beforeOpen case final close?) {
                  close();
                  router.push(AppRoutes.invitations);
                } else {
                  open();
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Icon(Icons.group_add_outlined, size: 20, color: AppColors.accent700),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Invitations', style: AppTextStyles.title(size: 14))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: AppRadius.pill),
                      child: Text(
                        '${invites.length}',
                        style: AppTextStyles.title(size: 12.5, color: AppColors.onDark),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
