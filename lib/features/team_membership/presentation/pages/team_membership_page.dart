import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team.dart';
import '../bloc/team_membership_bloc.dart';
import '../bloc/team_membership_event.dart';
import '../bloc/team_membership_state.dart';
import 'team_roster_page.dart';

/// Reached from Profile, and from the Home team switcher's "create or join"
/// action. Lists the profile's teams (up to 3) and, while under that cap,
/// a form to create one or join one by invite code.
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
          title: Text('Team', style: AppTextStyles.heading(size: 16)),
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
    final isAtLimit = teams.length >= TeamMembershipLoaded.maxTeams;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (teams.isNotEmpty) ...[
          Text(
            'YOUR TEAMS (${teams.length}/${TeamMembershipLoaded.maxTeams})',
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
          Text("You're not on a team yet", style: AppTextStyles.heading(size: 22)),
          const SizedBox(height: 6),
          Text(
            'Start a squad of your own, or join one with an invite code.',
            style: AppTextStyles.body(
              size: 13.5,
              color: AppColors.text.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (isAtLimit)
          Text(
            "You're on the max of ${TeamMembershipLoaded.maxTeams} teams. "
            'Leave one to create or join another.',
            style: AppTextStyles.body(
              size: 12.5,
              color: AppColors.text.withValues(alpha: 0.55),
            ),
          )
        else ...[
          _Section(
            title: 'CREATE A TEAM',
            children: [
              _RoundedField(controller: nameController, hintText: 'Team name'),
              const SizedBox(height: 14),
              _PrimaryButton(
                label: 'Create team',
                isLoading: isSubmitting,
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  context.read<TeamMembershipBloc>().add(TeamCreateRequested(name));
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'JOIN A TEAM',
            children: [
              _RoundedField(
                controller: inviteCodeController,
                hintText: 'Invite code',
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 14),
              _PrimaryButton(
                label: 'Join team',
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

  static String _roleLabel(TeamRole role) => switch (role) {
        TeamRole.superAdmin => 'SUPER ADMIN',
        TeamRole.admin => 'ADMIN',
        TeamRole.player => 'PLAYER',
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
                  _roleLabel(team.role),
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
          if (team.role != TeamRole.player) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TeamRosterPage(team: team),
                  ),
                ),
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
