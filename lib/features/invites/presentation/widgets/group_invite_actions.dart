import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../notifications/presentation/pages/notifications_page.dart' show formatNotificationTime;
import '../../domain/entities/group_invite.dart';
import '../../domain/usecases/invite_usecases.dart';
import 'invite_people_sheet.dart';

/// For a group's admins: "Invite people", and "Pending invites" with how
/// many are still waiting — tapping it lists them, each with Cancel. The
/// count refreshes after either sheet closes. On a squad's Members tab and
/// a team's Squad tab (and its roster).
class GroupInviteActions extends StatefulWidget {
  const GroupInviteActions({super.key, required this.teamId, required this.groupName});

  final String teamId;
  final String groupName;

  @override
  State<GroupInviteActions> createState() => _GroupInviteActionsState();
}

class _GroupInviteActionsState extends State<GroupInviteActions> {
  /// Null until loaded (or if it couldn't be).
  int? _pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GroupInviteActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId) {
      _pending = null;
      _load();
    }
  }

  Future<void> _load() async {
    final teamId = widget.teamId;
    final result = await sl<GetPendingInvites>()(teamId);
    if (!mounted || teamId != widget.teamId) return;
    setState(() => _pending = result.fold((_) => null, (invites) => invites.length));
  }

  Future<void> _invite() async {
    await showInvitePeopleSheet(context, teamId: widget.teamId, groupName: widget.groupName);
    if (mounted) await _load();
  }

  Future<void> _showPending() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => _PendingInvitesPage(teamId: widget.teamId, groupName: widget.groupName),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _invite,
            icon: Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.text),
            label: Text('Invite people', style: AppTextStyles.title(size: 14)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
              shape: const StadiumBorder(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: AppColors.card,
          borderRadius: AppRadius.lg,
          child: InkWell(
            key: const ValueKey('pending-invites'),
            borderRadius: AppRadius.lg,
            onTap: _showPending,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.schedule_send_outlined, size: 20, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Pending invites', style: AppTextStyles.title(size: 14))),
                  if (pending != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                      decoration: BoxDecoration(
                        color: pending > 0 ? AppColors.accent : AppColors.surface,
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        '$pending',
                        style: AppTextStyles.title(
                          size: 12.5,
                          color: pending > 0 ? AppColors.onDark : AppColors.textMuted,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Everyone invited to the group who hasn't answered yet, with Cancel —
/// full screen, one flat row each.
class _PendingInvitesPage extends StatefulWidget {
  const _PendingInvitesPage({required this.teamId, required this.groupName});

  final String teamId;
  final String groupName;

  @override
  State<_PendingInvitesPage> createState() => _PendingInvitesPageState();
}

class _PendingInvitesPageState extends State<_PendingInvitesPage> {
  List<PendingInvite>? _invites;
  String? _error;

  /// Invites being cancelled, by id.
  final _cancelling = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<GetPendingInvites>()(widget.teamId);
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

  Future<void> _cancel(PendingInvite invite) async {
    setState(() => _cancelling.add(invite.id));
    final messenger = ScaffoldMessenger.of(context);
    final result = await sl<CancelInvite>()(invite.id);
    if (!mounted) return;
    setState(() {
      _cancelling.remove(invite.id);
      if (result.isRight()) _invites = [...?_invites]..remove(invite);
    });
    result.fold(
      (failure) => messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message))),
      (_) {},
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
        title: Text('Pending invites', style: AppTextStyles.title(size: 16)),
      ),
      body: SafeArea(
        child: switch ((invites, _error)) {
          (null, null) => const Center(child: CircularProgressIndicator()),
          (null, final error?) => _Note(error),
          (final invites?, _) when invites.isEmpty => const _Note('No pending invites.'),
          (final invites?, _) => ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: invites.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox.shrink()
                : Divider(height: 1, indent: 68, color: AppColors.divider),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    "Invited to ${widget.groupName}, and haven't answered yet.",
                    style: AppTextStyles.body(size: 12.5, color: AppColors.textMuted),
                  ),
                );
              }
              final invite = invites[index - 1];
              return _PendingRow(
                invite: invite,
                cancelling: _cancelling.contains(invite.id),
                onCancel: () => _cancel(invite),
              );
            },
          ),
        },
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppTextStyles.body(size: 13, color: AppColors.neutral700),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.invite, required this.cancelling, required this.onCancel});

  final PendingInvite invite;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final photo = invite.photoUrl;
    final who = [
      if (invite.username case final username?) '@$username',
      invite.invitedByName == null ? 'Invited' : 'Invited by ${invite.invitedByName}',
      formatNotificationTime(invite.createdAt),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accent300,
            foregroundImage: photo == null ? null : NetworkImage(photo),
            child: Text(invite.initial, style: AppTextStyles.title(size: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(size: 14.5),
                ),
                Text(
                  who,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(size: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: cancelling ? null : onCancel,
            child: Text('Cancel', style: AppTextStyles.title(size: 13, color: AppColors.accent700)),
          ),
        ],
      ),
    );
  }
}
