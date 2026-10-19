import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../team_membership/domain/entities/team.dart';
import '../../domain/entities/group_invite.dart';
import '../../domain/usecases/invite_usecases.dart';

/// Whether [role] may invite people to a group: admins and super admins
/// (056's invite_to_team checks the same).
bool canInvite(TeamRole role) => role != TeamRole.player;

/// "Invite people" for a team's or squad's admins: an outlined button that
/// opens [showInvitePeopleSheet].
class InvitePeopleButton extends StatelessWidget {
  const InvitePeopleButton({super.key, required this.teamId, required this.groupName});

  final String teamId;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => showInvitePeopleSheet(context, teamId: teamId, groupName: groupName),
        icon: Icon(Icons.person_add_alt_1_rounded, size: 18, color: AppColors.text),
        label: Text('Invite people', style: AppTextStyles.title(size: 14)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// Search people you share a group with — by name or @username — and
/// invite them to [teamId]. They get a notification to accept or decline.
Future<void> showInvitePeopleSheet(
  BuildContext context, {
  required String teamId,
  required String groupName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _InvitePeopleSheet(teamId: teamId, groupName: groupName),
  );
}

class _InvitePeopleSheet extends StatefulWidget {
  const _InvitePeopleSheet({required this.teamId, required this.groupName});

  final String teamId;
  final String groupName;

  @override
  State<_InvitePeopleSheet> createState() => _InvitePeopleSheetState();
}

class _InvitePeopleSheetState extends State<_InvitePeopleSheet> {
  static const _debounce = Duration(milliseconds: 300);

  final _query = TextEditingController();
  Timer? _typing;
  List<InviteCandidate>? _people;
  String? _error;

  /// Answers to an older query are dropped.
  int _search = 0;

  /// Invites being sent, by profile id.
  final _sending = <String>{};

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _typing?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _typing?.cancel();
    _typing = Timer(_debounce, () => _run(text));
  }

  Future<void> _run(String text) async {
    final search = ++_search;
    final result = await sl<SearchInviteCandidates>()((teamId: widget.teamId, query: text.trim()));
    if (!mounted || search != _search) return;
    setState(() {
      result.fold(
        (failure) => _error = failure.message,
        (people) {
          _people = people;
          _error = null;
        },
      );
    });
  }

  Future<void> _invite(InviteCandidate person) async {
    setState(() => _sending.add(person.profileId));
    final messenger = ScaffoldMessenger.of(context);
    final result = await sl<InviteToGroup>()((teamId: widget.teamId, profileId: person.profileId));
    if (!mounted) return;
    setState(() {
      _sending.remove(person.profileId);
      if (result.isRight()) {
        _people = [
          for (final p in _people ?? const <InviteCandidate>[])
            p.profileId == person.profileId ? p.asInvited() : p,
        ];
      }
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
    final people = _people;
    final searching = _query.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Invite to ${widget.groupName}', style: AppTextStyles.heading(size: 20)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'People from your other teams and squads. They get a notification to accept.',
                style: AppTextStyles.body(size: 12.5, color: AppColors.textMuted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: TextField(
                key: const ValueKey('invite-search'),
                controller: _query,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by name or @username',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(borderRadius: AppRadius.lg, borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: switch ((people, _error)) {
                (null, null) => const Center(child: CircularProgressIndicator()),
                (null, final error?) => _Note(error),
                (final people?, _) when people.isEmpty => _Note(
                  searching
                      ? 'No one from your groups matches.'
                      : 'Everyone from your groups is already here.',
                ),
                (final people?, _) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: people.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final person = people[index];
                    return _PersonRow(
                      person: person,
                      sending: _sending.contains(person.profileId),
                      onInvite: () => _invite(person),
                    );
                  },
                ),
              },
            ),
          ],
        ),
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

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.sending, required this.onInvite});

  final InviteCandidate person;
  final bool sending;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final photo = person.photoUrl;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: AppRadius.lg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accent300,
            foregroundImage: photo == null ? null : NetworkImage(photo),
            child: Text(person.initial, style: AppTextStyles.title(size: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name, style: AppTextStyles.title(size: 14.5)),
                if (person.username case final username?)
                  Text('@$username', style: AppTextStyles.body(size: 12.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (person.invited)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('Invited', style: AppTextStyles.title(size: 13, color: AppColors.textMuted)),
            )
          else
            FilledButton(
              onPressed: sending ? null : onInvite,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.neutral900,
                minimumSize: const Size(0, 36),
                shape: const StadiumBorder(),
              ),
              child: Text('Invite', style: AppTextStyles.title(size: 13, color: AppColors.onDark)),
            ),
        ],
      ),
    );
  }
}
