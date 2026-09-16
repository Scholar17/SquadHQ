import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team_snapshot.dart';
import '../bloc/team_bloc.dart';
import '../bloc/team_event.dart';
import '../bloc/team_state.dart';

/// The matchday hub — RSVP, squad list, nudges. Reached from Home's
/// "Open matchday" / "vs {opponent}" card, not parked behind its own tab
/// icon in the design, but given a tab here for direct access.
class MatchPage extends StatelessWidget {
  const MatchPage({super.key});

  void _snack(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label is coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: BlocBuilder<TeamBloc, TeamState>(
          builder: (context, state) {
            if (state is! TeamLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }
            final snapshot = state.snapshot;
            final match = snapshot.match;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _HubHeader(
                  opponent: match.opponent,
                  hubLine1: match.hubLine1,
                  hubLine2: match.hubLine2,
                  isManager: state.isManager,
                  onEdit: () => _snack(context, 'Edit match'),
                ),
                const SizedBox(height: 16),
                _RsvpCard(
                  closesLabel: match.rsvpClosesLabel,
                  isManager: state.isManager,
                  myRsvp: state.myRsvp,
                  snapshot: snapshot,
                  onRsvp: (status) =>
                      context.read<TeamBloc>().add(TeamMyRsvpChanged(status)),
                  onRemind: () => _snack(context, 'Reminder'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SQUAD',
                        style: AppTextStyles.label(
                          color: AppColors.text.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    Text(
                      '${snapshot.roster.length} players',
                      style: AppTextStyles.label(
                        color: AppColors.text.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < snapshot.roster.length; i++)
                        _RosterRow(
                          member: snapshot.roster[i],
                          isManager: state.isManager,
                          showTopBorder: i > 0,
                          onNudge: () => _snack(context, 'Nudge'),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.opponent,
    required this.hubLine1,
    required this.hubLine2,
    required this.isManager,
    required this.onEdit,
  });

  final String opponent;
  final String hubLine1;
  final String hubLine2;
  final bool isManager;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MATCHDAY HUB',
                  style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.teamGold,
                  ).copyWith(letterSpacing: 1.4),
                ),
              ),
              if (isManager)
                OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neutral100,
                    side: const BorderSide(color: Color(0x47F9F4ED)),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    minimumSize: const Size(0, 28),
                  ),
                  child: Text(
                    'Edit details',
                    style: AppTextStyles.heading(size: 11.5, color: AppColors.neutral100),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: AppTextStyles.heading(size: 24, color: AppColors.neutral100),
              children: [
                const TextSpan(text: 'Golden Goal '),
                TextSpan(
                  text: 'vs',
                  style: TextStyle(color: AppColors.neutral100.withValues(alpha: 0.45)),
                ),
                TextSpan(text: ' $opponent'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$hubLine1\n$hubLine2',
            style: AppTextStyles.body(
              size: 12.5,
              weight: FontWeight.w500,
              color: AppColors.neutral100.withValues(alpha: 0.62),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _RsvpCard extends StatelessWidget {
  const _RsvpCard({
    required this.closesLabel,
    required this.isManager,
    required this.myRsvp,
    required this.snapshot,
    required this.onRsvp,
    required this.onRemind,
  });

  final String closesLabel;
  final bool isManager;
  final RsvpStatus myRsvp;
  final TeamSnapshot snapshot;
  final ValueChanged<RsvpStatus> onRsvp;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.roster.length;
    final confirmed = snapshot.confirmedCount;
    final maybe = snapshot.maybeCount;
    final silent = snapshot.noReplyCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RSVP STATUS',
                  style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                ),
              ),
              Text(
                closesLabel,
                style: AppTextStyles.body(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppColors.accent700,
                ),
              ),
            ],
          ),
          if (!isManager) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RsvpChoiceButton(
                    label: 'In',
                    selected: myRsvp == RsvpStatus.yes,
                    color: AppColors.accent2_700,
                    onTap: () => onRsvp(RsvpStatus.yes),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RsvpChoiceButton(
                    label: 'Maybe',
                    selected: myRsvp == RsvpStatus.maybe,
                    color: AppColors.neutral700,
                    onTap: () => onRsvp(RsvpStatus.maybe),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RsvpChoiceButton(
                    label: 'Out',
                    selected: myRsvp == RsvpStatus.no,
                    color: AppColors.accent700,
                    onTap: () => onRsvp(RsvpStatus.no),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              switch (myRsvp) {
                RsvpStatus.yes => "You're confirmed — see you Sunday!",
                RsvpStatus.maybe => "We'll pencil you in as a maybe.",
                RsvpStatus.no => 'Thanks for letting the squad know.',
                RsvpStatus.pending => 'Let the squad know if you can make it.',
              },
              style: AppTextStyles.body(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.text.withValues(alpha: 0.55),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$confirmed',
                  style: AppTextStyles.heading(size: 34),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'confirmed of $total · $maybe maybe · $silent silent',
                    style: AppTextStyles.body(
                      size: 12,
                      weight: FontWeight.w500,
                      color: AppColors.text.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: confirmed,
                      child: Container(color: AppColors.accent2_700),
                    ),
                    Expanded(
                      flex: maybe,
                      child: Container(color: AppColors.neutral500),
                    ),
                    Expanded(
                      flex: (total - confirmed - maybe).clamp(0, total),
                      child: Container(color: AppColors.neutral300),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: onRemind,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                  shape: const StadiumBorder(),
                ),
                child: Text('Remind everyone', style: AppTextStyles.heading(size: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RsvpChoiceButton extends StatelessWidget {
  const _RsvpChoiceButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? color : AppColors.neutral200,
          foregroundColor: selected ? AppColors.bg : AppColors.text,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Text(
          label,
          style: AppTextStyles.heading(
            size: 13.5,
            color: selected ? AppColors.bg : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.member,
    required this.isManager,
    required this.showTopBorder,
    required this.onNudge,
  });

  final SquadMember member;
  final bool isManager;
  final bool showTopBorder;
  final VoidCallback onNudge;

  Color get _dotColor => switch (member.rsvpStatus) {
        RsvpStatus.yes => AppColors.accent2_700,
        RsvpStatus.maybe => AppColors.teamGold,
        RsvpStatus.no => AppColors.text.withValues(alpha: 0.25),
        RsvpStatus.pending => AppColors.neutral400,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: showTopBorder
            ? Border(top: BorderSide(color: AppColors.text.withValues(alpha: 0.07)))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: AppTextStyles.body(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${member.position} · ${member.statusLabel}',
                  style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.text.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (isManager && member.needsNudge)
            OutlinedButton(
              onPressed: onNudge,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 30),
              ),
              child: Text('Nudge', style: AppTextStyles.heading(size: 12)),
            ),
        ],
      ),
    );
  }
}
