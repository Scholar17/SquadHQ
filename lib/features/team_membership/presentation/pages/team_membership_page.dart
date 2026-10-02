import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team.dart';
import '../bloc/team_membership_bloc.dart';
import '../widgets/timezone_picker_sheet.dart';
import '../bloc/team_membership_event.dart';
import '../bloc/team_membership_state.dart';

/// Reached from Profile, and from the Home team switcher's "create or join"
/// action. Lists the profile's groups — up to 3 football teams and 3
/// squads — and forms to create one (Team or Squad?) or join one by invite
/// code (the code decides which kind).
class TeamMembershipPage extends StatefulWidget {
  const TeamMembershipPage({super.key});

  @override
  State<TeamMembershipPage> createState() => _TeamMembershipPageState();
}

class _TeamMembershipPageState extends State<TeamMembershipPage> {
  final _nameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<TeamMembershipBloc>().add(const TeamMembershipStarted());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  /// Unwraps [TeamMembershipSubmitting]/[TeamMembershipFailure] down to the
  /// settled [TeamMembershipLoaded] underneath — those two never nest, so
  /// one pass is enough.
  TeamMembershipState _settle(TeamMembershipState state) => switch (state) {
        TeamMembershipSubmitting(:final previous) => previous,
        TeamMembershipFailure(:final previous) => previous,
        _ => state,
      };

  @override
  Widget build(BuildContext context) {
    return BlocListener<TeamMembershipBloc, TeamMembershipState>(
      listenWhen: (previous, current) => current is TeamMembershipFailure,
      listener: (context, state) {
        if (state case TeamMembershipFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: AppColors.text,
          title: Text('Groups', style: AppTextStyles.heading(size: 16)),
        ),
        body: SafeArea(
          child: BlocBuilder<TeamMembershipBloc, TeamMembershipState>(
            builder: (context, state) {
              final isSubmitting = state is TeamMembershipSubmitting;
              final settled = _settle(state);
              return switch (settled) {
                TeamMembershipLoaded(:final teams) => _TeamsView(
                    teams: teams,
                    isSubmitting: isSubmitting,
                    nameController: _nameController,
                    inviteCodeController: _inviteCodeController,
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _TeamsView extends StatelessWidget {
  const _TeamsView({
    required this.teams,
    required this.isSubmitting,
    required this.nameController,
    required this.inviteCodeController,
  });

  final List<Team> teams;
  final bool isSubmitting;
  final TextEditingController nameController;
  final TextEditingController inviteCodeController;

  @override
  Widget build(BuildContext context) {
    final loaded = TeamMembershipLoaded(teams);
    final isAtLimit =
        loaded.isAtLimit(GroupKind.team) && loaded.isAtLimit(GroupKind.squad);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (teams.isNotEmpty) ...[
          Text(
            'YOUR GROUPS (${teams.length})',
            style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 10),
          for (final team in teams) ...[
            _TeamCard(
              team: team,
              onSetActive: team.isActive
                  ? null
                  : () => context
                      .read<TeamMembershipBloc>()
                      .add(TeamSwitchRequested(team.id)),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
        ] else ...[
          Text("You're not in a group yet", style: AppTextStyles.heading(size: 22)),
          const SizedBox(height: 6),
          Text(
            'Start a football team or a friends squad, or join one with an invite code.',
            style: AppTextStyles.body(
              size: 13.5,
              color: AppColors.text.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (isAtLimit)
          Text(
            "You're in the max of ${TeamMembershipLoaded.maxTeams} teams and "
            '${TeamMembershipLoaded.maxTeams} squads. Leave one to create or join another.',
            style: AppTextStyles.body(
              size: 12.5,
              color: AppColors.text.withValues(alpha: 0.55),
            ),
          )
        else ...[
          _Section(
            title: 'CREATE A GROUP',
            children: [
              _CreateGroupForm(
                nameController: nameController,
                isSubmitting: isSubmitting,
                teamFull: loaded.isAtLimit(GroupKind.team),
                squadFull: loaded.isAtLimit(GroupKind.squad),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'JOIN A GROUP',
            children: [
              _RoundedField(
                controller: inviteCodeController,
                hintText: 'Invite code',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 14),
              _PrimaryButton(
                label: 'Join group',
                isLoading: isSubmitting,
                onPressed: () {
                  final code = inviteCodeController.text.trim();
                  if (code.isEmpty) return;
                  context.read<TeamMembershipBloc>().add(TeamJoinRequested(code));
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.onSetActive});

  final Team team;
  final VoidCallback? onSetActive;

  static String _roleLabel(Team team) => switch ((team.kind, team.role)) {
        (GroupKind.team, TeamRole.superAdmin) => 'TEAM · SUPER ADMIN',
        (GroupKind.team, TeamRole.admin) => 'TEAM · ADMIN',
        (GroupKind.team, TeamRole.player) => 'TEAM · PLAYER',
        (GroupKind.squad, TeamRole.superAdmin) => 'SQUAD · OWNER',
        (GroupKind.squad, TeamRole.admin) => 'SQUAD · ADMIN',
        (GroupKind.squad, TeamRole.player) => 'SQUAD · MEMBER',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: team.isActive ? AppColors.accent : AppColors.text.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _roleLabel(team),
                  style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                ),
              ),
              if (team.isActive)
                Text('ACTIVE', style: AppTextStyles.label(color: AppColors.accent700))
              else
                TextButton(
                  onPressed: onSetActive,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Set active',
                    style: AppTextStyles.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.accent700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(team.name, style: AppTextStyles.heading(size: 20)),
          const SizedBox(height: 16),
          Text(
            'INVITE CODE',
            style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.text.withValues(alpha: 0.16)),
                  ),
                  child: Text(
                    team.inviteCode,
                    style: AppTextStyles.body(size: 16, weight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: team.inviteCode));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Invite code copied')));
                },
                icon: const Icon(Icons.copy_rounded),
                color: AppColors.accent700,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TimezoneRow(team: team),
          if (team.role != TeamRole.player) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: () => context.push(AppRoutes.teamRoster, extra: team),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Manage team',
                  style: AppTextStyles.heading(size: 13, color: AppColors.text),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _RoundedField extends StatelessWidget {
  const _RoundedField({
    required this.controller,
    required this.hintText,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hintText;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: AppColors.bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.bg,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.bg,
                ),
              )
            : Text(label, style: AppTextStyles.heading(size: 14, color: AppColors.bg)),
      ),
    );
  }
}

/// The team's time zone — changeable by the super admin only.
class _TimezoneRow extends StatelessWidget {
  const _TimezoneRow({required this.team});

  final Team team;

  Future<void> _change(BuildContext context) async {
    final picked = await showTimezonePickerSheet(context, current: team.timezone);
    if (picked == null || picked == team.timezone || !context.mounted) return;
    context.read<TeamMembershipBloc>().add(
          TeamTimezoneChangeRequested(teamId: team.id, timezone: picked),
        );
  }

  @override
  Widget build(BuildContext context) {
    final offset = utcOffsetLabel(team.timezone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIME ZONE',
          style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                [team.timezone.replaceAll('_', ' '), ?offset].join(' · '),
                style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
              ),
            ),
            if (team.role == TeamRole.superAdmin)
              TextButton(
                onPressed: () => _change(context),
                child: Text(
                  'Change',
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.accent700,
                  ),
                ),
              ),
          ],
        ),
        Text(
          "When match day ends for Man of the Match voting. Times show in your phone's time.",
          style: AppTextStyles.body(size: 11.5, color: AppColors.text.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

/// Team or Squad? — two cards — then the name, plus the currency for a
/// squad.
class _CreateGroupForm extends StatefulWidget {
  const _CreateGroupForm({
    required this.nameController,
    required this.isSubmitting,
    required this.teamFull,
    required this.squadFull,
  });

  final TextEditingController nameController;
  final bool isSubmitting;
  final bool teamFull;
  final bool squadFull;

  @override
  State<_CreateGroupForm> createState() => _CreateGroupFormState();
}

class _CreateGroupFormState extends State<_CreateGroupForm> {
  late GroupKind _kind = widget.teamFull ? GroupKind.squad : GroupKind.team;
  GroupCurrency _currency = GroupCurrency.thb;

  bool get _full => _kind == GroupKind.team ? widget.teamFull : widget.squadFull;

  @override
  Widget build(BuildContext context) {
    final isSquad = _kind == GroupKind.squad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (kind, title, body, icon, tile) in [
          (
            GroupKind.team,
            'Football team',
            'Matches, RSVPs, match bills and Man of the Match.',
            Icons.sports_soccer_rounded,
            AppColors.neutral800,
          ),
          (
            GroupKind.squad,
            'Friends squad',
            'Shared expenses for meals, drinks, shopping and trips. Split, track and settle up.',
            Icons.receipt_long_rounded,
            AppColors.accent700,
          ),
        ]) ...[
          _KindCard(
            title: title,
            body: body,
            icon: icon,
            tile: tile,
            selected: _kind == kind,
            onTap: () => setState(() => _kind = kind),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        _RoundedField(
          controller: widget.nameController,
          hintText: isSquad ? 'Squad name, e.g. Friday Crew' : 'Team name',
        ),
        if (isSquad) ...[
          const SizedBox(height: 14),
          Text(
            'CURRENCY',
            style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final currency in GroupCurrency.values) ...[
                if (currency != GroupCurrency.values.first) const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        '${currency.symbol} ${currency.label}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    selected: _currency == currency,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _currency = currency),
                    selectedColor: AppColors.neutral900,
                    backgroundColor: AppColors.neutral100,
                    labelStyle: AppTextStyles.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: _currency == currency ? AppColors.neutral100 : AppColors.text,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(color: AppColors.text.withValues(alpha: 0.14)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 14),
        if (_full)
          Text(
            "You're in the max of ${TeamMembershipLoaded.maxTeams} "
            '${isSquad ? 'squads' : 'teams'}. Leave one to create another.',
            style: AppTextStyles.body(size: 12.5, color: AppColors.text.withValues(alpha: 0.55)),
          )
        else
          _PrimaryButton(
            label: isSquad ? 'Create squad' : 'Create team',
            isLoading: widget.isSubmitting,
            onPressed: () {
              final name = widget.nameController.text.trim();
              if (name.isEmpty) return;
              context.read<TeamMembershipBloc>().add(
                    TeamCreateRequested(name, kind: _kind, currency: _currency),
                  );
            },
          ),
      ],
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.tile,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color tile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.accent100 : AppColors.neutral100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? AppColors.accent700 : AppColors.text.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: AppColors.neutral100),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.heading(size: 17, height: 1.3)),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: AppTextStyles.body(
                          size: 13,
                          color: AppColors.text.withValues(alpha: 0.62),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.accent700 : AppColors.neutral500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
