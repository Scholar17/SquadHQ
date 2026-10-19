import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../notifications/presentation/pages/notifications_page.dart' show formatNotificationTime;
import '../../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../../team_membership/presentation/bloc/team_membership_event.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/usecases/invite_usecases.dart';

/// Your pending invitations to teams and squads — opened from an
/// invitation's notification. Each shows the group, who invited you and
/// how many are in it; Accept joins (as a player, and switches the app to
/// it), Decline drops it.
class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  List<GroupInvite>? _invites;
  String? _error;

  /// The invite being accepted or declined.
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<GetMyInvites>()(const NoParams());
    if (!mounted) return;
    setState(() {
      result.fold(
        (failure) => _error = failure.message,
        (invites) {
          _invites = invites;
          _error = null;
        },
      );
    });
  }

  Future<void> _respond(GroupInvite invite, {required bool accept}) async {
    setState(() => _busy = invite.id);
    final membership = context.read<TeamMembershipBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await sl<RespondToInvite>()((inviteId: invite.id, accept: accept));
    if (!mounted) return;
    setState(() => _busy = null);
    result.fold(
      (failure) => messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message))),
      (_) {
        setState(() => _invites = [...?_invites]..remove(invite));
        // Joined: the group list reloads with it as the active group.
        if (accept) membership.add(const TeamMembershipRefreshRequested());
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(accept ? 'You joined ${invite.teamName}' : 'Invitation declined'),
            ),
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final invites = _invites;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Invitations', style: AppTextStyles.title(size: 16)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (invites == null && _error == null)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (invites == null)
                _Message(_error!)
              else if (invites.isEmpty)
                const _Message('No invitations right now.')
              else
                for (final invite in invites) ...[
                  _InviteCard(
                    invite: invite,
                    busy: _busy == invite.id,
                    onAccept: _busy == null ? () => _respond(invite, accept: true) : null,
                    onDecline: _busy == null ? () => _respond(invite, accept: false) : null,
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.body(size: 13, color: AppColors.neutral700),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final GroupInvite invite;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final members = invite.memberCount == 1 ? '1 member' : '${invite.memberCount} members';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accent100, shape: BoxShape.circle),
                child: Icon(
                  invite.isSquad ? Icons.groups_rounded : Icons.sports_soccer_rounded,
                  color: AppColors.accent700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invite.teamName, style: AppTextStyles.title(size: 16)),
                    const SizedBox(height: 2),
                    Text(
                      '${invite.isSquad ? 'Squad' : 'Football team'} · $members',
                      style: AppTextStyles.body(size: 12.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${invite.invitedByName ?? 'An admin'} invited you · '
            '${formatNotificationTime(invite.createdAt)}',
            style: AppTextStyles.body(size: 13, color: AppColors.textSubtle),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: const StadiumBorder(),
                    side: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
                  ),
                  child: Text('Decline', style: AppTextStyles.title(size: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neutral900,
                    minimumSize: const Size(0, 44),
                    shape: const StadiumBorder(),
                  ),
                  child: busy
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onDark),
                        )
                      : Text('Accept', style: AppTextStyles.title(size: 14, color: AppColors.onDark)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
