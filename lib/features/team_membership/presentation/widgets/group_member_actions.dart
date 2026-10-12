import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_member.dart';
import '../bloc/team_membership_bloc.dart';
import '../bloc/team_membership_event.dart';
import '../bloc/team_roster_bloc.dart';
import '../bloc/team_roster_event.dart';
import '../bloc/team_roster_state.dart';

/// "team" or "squad", for [team]'s wording.
String groupWord(Team team) => team.isSquad ? 'squad' : 'team';

/// Asks before a leave/remove; true once confirmed.
Future<bool> confirmGroupAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
      title: Text(title, style: AppTextStyles.heading(size: 20)),
      content: Text(message, style: AppTextStyles.body(size: 13.5, color: AppColors.textSubtle)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Cancel',
            style: AppTextStyles.body(size: 14, weight: FontWeight.w700, color: AppColors.text),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            action,
            style: AppTextStyles.body(
              size: 14,
              weight: FontWeight.w700,
              color: AppColors.accent700,
            ),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

void _say(ScaffoldMessengerState messenger, String message) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// Leaves [team] after asking. Its super admin first picks who takes over.
/// Money still to settle stops it, with the server's reason shown.
Future<void> leaveGroup(BuildContext context, Team team) async {
  final messenger = ScaffoldMessenger.of(context);
  final bloc = context.read<TeamMembershipBloc>();
  final word = groupWord(team);
  String? newOwnerId;
  String message = "You can rejoin later with the invite code.";
  if (team.role == TeamRole.superAdmin) {
    final heir = await _pickNewOwner(context, team);
    if (heir == null || !context.mounted) return;
    newOwnerId = heir.profileId;
    message =
        '${heir.name} becomes the ${team.isSquad ? 'owner' : 'super admin'}. '
        'You can rejoin later with the invite code.';
  }
  final confirmed = await confirmGroupAction(
    context,
    title: 'Leave ${team.name}?',
    message: message,
    action: 'Leave $word',
  );
  if (!confirmed) return;
  bloc.add(
    TeamLeaveRequested(
      team.id,
      newOwnerId: newOwnerId,
      done: (error) => _say(messenger, error ?? 'You left ${team.name}'),
    ),
  );
}

/// Removes [member] from [team] after asking — for screens without their
/// own [TeamRosterBloc] (the squad's Members tab). [onRemoved] runs once
/// they're out.
Future<void> removeFromGroup(
  BuildContext context, {
  required Team team,
  required String profileId,
  required String name,
  VoidCallback? onRemoved,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final bloc = context.read<TeamMembershipBloc>();
  final confirmed = await confirmRemove(context, team: team, name: name);
  if (!confirmed) return;
  bloc.add(
    TeamMemberRemoveRequested(
      teamId: team.id,
      profileId: profileId,
      done: (error) {
        _say(messenger, error ?? '$name was removed');
        if (error == null) onRemoved?.call();
      },
    ),
  );
}

Future<bool> confirmRemove(BuildContext context, {required Team team, required String name}) =>
    confirmGroupAction(
      context,
      title: 'Remove $name?',
      message:
          "They'll be told they were removed from ${team.name}. "
          'They can rejoin later with the invite code.',
      action: 'Remove',
    );

/// Whether someone with [myRole] may remove someone with [theirRole]: the
/// super admin removes admins and players, an admin removes players.
bool canRemoveMember(TeamRole myRole, TeamRole theirRole) => switch (myRole) {
  TeamRole.superAdmin => theirRole != TeamRole.superAdmin,
  TeamRole.admin => theirRole == TeamRole.player,
  TeamRole.player => false,
};

/// The super admin leaving: who takes over. Null if dismissed, or if
/// there's nobody else (they're told to delete the group instead).
Future<TeamMember?> _pickNewOwner(BuildContext context, Team team) {
  return showModalBottomSheet<TeamMember>(
    context: context,
    backgroundColor: AppColors.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => BlocProvider(
      create: (_) => sl<TeamRosterBloc>(param1: team.id)..add(const TeamRosterStarted()),
      child: _NewOwnerSheet(team: team),
    ),
  );
}

class _NewOwnerSheet extends StatelessWidget {
  const _NewOwnerSheet({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final title = team.isSquad ? 'Who becomes the owner?' : 'Who becomes the super admin?';
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.title(size: 18)),
              const SizedBox(height: 4),
              Text(
                'Before you leave, hand ${team.name} over to someone.',
                style: AppTextStyles.body(size: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: BlocBuilder<TeamRosterBloc, TeamRosterState>(
                  builder: (context, state) {
                    final settled = switch (state) {
                      TeamRosterFailure(:final previous) => previous,
                      _ => state,
                    };
                    if (settled is! TeamRosterLoaded) {
                      if (state case TeamRosterFailure(:final message)) {
                        return Text(message, style: AppTextStyles.body(size: 13.5));
                      }
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final others =
                        [
                          for (final member in settled.members)
                            if (member.role != TeamRole.superAdmin) member,
                        ]..sort((a, b) {
                          // Admins first: the likeliest pick.
                          final byRole = (b.role == TeamRole.admin ? 1 : 0).compareTo(
                            a.role == TeamRole.admin ? 1 : 0,
                          );
                          return byRole != 0 ? byRole : a.name.compareTo(b.name);
                        });
                    if (others.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          "You're the only member, so there's nobody to hand over to. "
                          'Delete the ${groupWord(team)} from Manage team instead.',
                          style: AppTextStyles.body(size: 13.5, color: AppColors.textSubtle),
                        ),
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final member in others)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.teamGold,
                              foregroundImage: member.avatarUrl != null
                                  ? NetworkImage(member.avatarUrl!)
                                  : null,
                              onForegroundImageError: member.avatarUrl != null ? (_, _) {} : null,
                              child: Text(
                                member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                                style: AppTextStyles.title(size: 14, color: AppColors.neutral800),
                              ),
                            ),
                            title: Text(
                              member.name,
                              style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                            ),
                            subtitle: member.role == TeamRole.admin
                                ? Text(
                                    'ADMIN',
                                    style: AppTextStyles.label(color: AppColors.textMuted),
                                  )
                                : null,
                            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                            onTap: () => Navigator.of(context).pop(member),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
