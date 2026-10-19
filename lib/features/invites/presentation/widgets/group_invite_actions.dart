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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PendingInvitesSheet(teamId: widget.teamId, groupName: widget.groupName),
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

/// Everyone invited to the group who hasn't answered yet, with Cancel.
class _PendingInvitesSheet extends StatefulWidget {
  const _PendingInvitesSheet({required this.teamId, required this.groupName});

  final String teamId;
  final String groupName;

  @override
  State<_PendingInvitesSheet> createState() => _PendingInvitesSheetState();
}

class _PendingInvitesSheetState extends State<_PendingInvitesSheet> {
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
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('Pending invites', style: AppTextStyles.heading(size: 20)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              "Invited to ${widget.groupName}, and haven't answered yet.",
              style: AppTextStyles.body(size: 12.5, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: switch ((invites, _error)) {
              (null, null) => const Center(child: CircularProgressIndicator()),
              (null, final error?) => _Note(error),
              (final invites?, _) when invites.isEmpty => const _Note('No pending invites.'),
              (final invites?, _) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: invites.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final invite = invites[index];
                  return _PendingRow(
                    invite: invite,
                    cancelling: _cancelling.contains(invite.id),
                    onCancel: () => _cancel(invite),
                  );
                },
              ),
            },
          ),
        ],
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
    final handle = invite.username == null ? '' : '@${invite.username} · ';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.lg),
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
                Text(invite.name, style: AppTextStyles.title(size: 14.5)),
                Text(
                  '$handle${invite.invitedByName == null ? 'Invited' : 'Invited by ${invite.invitedByName}'}'
                  ' · ${formatNotificationTime(invite.createdAt)}',
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
