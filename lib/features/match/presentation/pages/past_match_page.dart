import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_state.dart';
import '../../../wallet/presentation/widgets/bill_card.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_history.dart';
import '../../domain/entities/matchday_player.dart';
import '../bloc/match_history_bloc.dart';
import '../match_formatting.dart';
import '../widgets/match_history_widgets.dart';

/// One past match: its score (admins in the Manager view can record it),
/// the Man of the Match vote, who played, and its bill. Reads the
/// [MatchHistoryBloc] the history page hands down.
class PastMatchPage extends StatelessWidget {
  const PastMatchPage({
    super.key,
    required this.matchId,
    required this.teamName,
    required this.userId,
    required this.isManager,
  });

  final String matchId;
  final String teamName;
  final String userId;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Match details', style: AppTextStyles.heading(size: 16)),
      ),
      body: BlocConsumer<MatchHistoryBloc, MatchHistoryState>(
        listenWhen: (previous, current) => current is MatchHistoryFailure,
        listener: (context, state) {
          if (state case MatchHistoryFailure(:final message)) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (context, state) {
          final history = state.history;
          final pastMatch = history?.forMatch(matchId);
          if (history == null || pastMatch == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          final played = [
            for (final member in history.members)
              if (pastMatch.playedIds.contains(member.profileId)) member,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _ScoreHeader(
                pastMatch: pastMatch,
                teamName: teamName,
                canEdit: isManager,
              ),
              const SizedBox(height: 16),
              _MotmCard(
                // Keyed by match so its edit state never leaks between matches.
                key: ValueKey('motm-$matchId'),
                pastMatch: pastMatch,
                history: history,
                userId: userId,
                isSubmitting: state is MatchHistorySubmitting,
              ),
              const SizedBox(height: 20),
              Text(
                'WHO PLAYED · ${played.length}',
                style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 10),
              if (played.isEmpty)
                Text(
                  'No one RSVP\'d "In" for this match.',
                  style: AppTextStyles.body(
                    size: 12.5,
                    color: AppColors.text.withValues(alpha: 0.55),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final player in played)
                      Chip(
                        avatar: PlayerAvatar(player: player, radius: 11),
                        label: Text(
                          player.profileId == userId ? '${player.name} (you)' : player.name,
                        ),
                        labelStyle: AppTextStyles.body(size: 12.5, weight: FontWeight.w700),
                        backgroundColor: AppColors.neutral100,
                        side: BorderSide(color: AppColors.text.withValues(alpha: 0.1)),
                        shape: const StadiumBorder(),
                      ),
                  ],
                ),
              _PastMatchBill(matchId: matchId, userId: userId, isManager: isManager),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.pastMatch,
    required this.teamName,
    required this.canEdit,
  });

  final PastMatch pastMatch;
  final String teamName;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final match = pastMatch.match;
    final result = match.result;
    final muted = AppColors.neutral100.withValues(alpha: 0.62);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            [formatMatchDateTime(match.kickoffAt), ?match.venue].join(' · '),
            textAlign: TextAlign.center,
            style: AppTextStyles.body(size: 12, weight: FontWeight.w500, color: muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  teamName,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(size: 15, color: AppColors.neutral100),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: result == null
                    ? Text('vs', style: AppTextStyles.heading(size: 22, color: muted))
                    : Text(
                        '${match.ourScore} – ${match.theirScore}',
                        style: AppTextStyles.heading(size: 34, color: AppColors.teamGold),
                      ),
              ),
              Expanded(
                child: Text(
                  match.opponent,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(size: 15, color: AppColors.neutral100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (result != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ResultBadge(result: result, large: true),
                const SizedBox(width: 8),
                Text(
                  switch (result) {
                    MatchResult.win => 'Win',
                    MatchResult.draw => 'Draw',
                    MatchResult.loss => 'Loss',
                  },
                  style: AppTextStyles.heading(size: 14, color: AppColors.neutral100),
                ),
              ],
            )
          else
            Text(
              canEdit ? 'No score yet — add it below.' : 'No score recorded yet.',
              style: AppTextStyles.body(size: 12.5, weight: FontWeight.w600, color: muted),
            ),
          if (canEdit) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => _showScoreSheet(context, pastMatch, teamName),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.neutral100,
                side: const BorderSide(color: Color(0x47F9F4ED)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                minimumSize: const Size(0, 34),
              ),
              child: Text(
                result == null ? 'Add score' : 'Edit score',
                style: AppTextStyles.heading(size: 12.5, color: AppColors.neutral100),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showScoreSheet(BuildContext context, PastMatch pastMatch, String teamName) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocProvider.value(
      value: context.read<MatchHistoryBloc>(),
      child: _ScoreSheet(pastMatch: pastMatch, teamName: teamName),
    ),
  );
}

class _ScoreSheet extends StatefulWidget {
  const _ScoreSheet({required this.pastMatch, required this.teamName});

  final PastMatch pastMatch;
  final String teamName;

  @override
  State<_ScoreSheet> createState() => _ScoreSheetState();
}

class _ScoreSheetState extends State<_ScoreSheet> {
  late int _ours = widget.pastMatch.match.ourScore ?? 0;
  late int _theirs = widget.pastMatch.match.theirScore ?? 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<MatchHistoryBloc, MatchHistoryState>(
      listenWhen: (previous, current) =>
          current is MatchHistoryFailure ||
          (previous is MatchHistorySubmitting && current is MatchHistoryLoaded),
      listener: (context, state) {
        if (state case MatchHistoryFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        Navigator.of(context).pop();
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Final score', style: AppTextStyles.heading(size: 18)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ScoreStepper(
                      label: widget.teamName,
                      value: _ours,
                      onChanged: (value) => setState(() => _ours = value),
                    ),
                  ),
                  Text('–', style: AppTextStyles.heading(size: 26)),
                  Expanded(
                    child: _ScoreStepper(
                      label: widget.pastMatch.match.opponent,
                      value: _theirs,
                      onChanged: (value) => setState(() => _theirs = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              BlocBuilder<MatchHistoryBloc, MatchHistoryState>(
                builder: (context, state) {
                  final isSubmitting = state is MatchHistorySubmitting;
                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () => context.read<MatchHistoryBloc>().add(
                                MatchScoreSubmitted(
                                  matchId: widget.pastMatch.match.id,
                                  ourScore: _ours,
                                  theirScore: _theirs,
                                ),
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.bg,
                        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(
                        isSubmitting ? 'Saving…' : 'Save score',
                        style: AppTextStyles.heading(size: 14, color: AppColors.bg),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreStepper extends StatelessWidget {
  const _ScoreStepper({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(size: 12.5, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_rounded),
              tooltip: 'Minus one for $label',
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(size: 30),
              ),
            ),
            IconButton.filledTonal(
              onPressed: value < 99 ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Plus one for $label',
            ),
          ],
        ),
      ],
    );
  }
}

/// Man of the Match, poll-style like the Match tab's RSVP. Players who
/// played vote once the match finishes (pick → "Submit vote", then
/// "Change vote"); it's a secret ballot until the result is decided —
/// when everyone who played has voted, or at midnight after the match —
/// then it shows the winner and each nominee's share. With no votes by
/// then, nobody gets it.
class _MotmCard extends StatefulWidget {
  const _MotmCard({
    super.key,
    required this.pastMatch,
    required this.history,
    required this.userId,
    required this.isSubmitting,
  });

  final PastMatch pastMatch;
  final MatchHistory history;
  final String userId;
  final bool isSubmitting;

  @override
  State<_MotmCard> createState() => _MotmCardState();
}

class _MotmCardState extends State<_MotmCard> {
  bool _editing = false;
  String? _pending;

  @override
  void didUpdateWidget(_MotmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final vote = widget.pastMatch.motmVotes[widget.userId];
    if (oldWidget.pastMatch.motmVotes[widget.userId] != vote) {
      _editing = false;
      _pending = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pastMatch = widget.pastMatch;
    final history = widget.history;
    final now = DateTime.now();
    final myVote = pastMatch.motmVotes[widget.userId];
    final voters = history.motmVoters(pastMatch);
    final votesCast = voters.where((v) => pastMatch.motmVotes.containsKey(v.profileId)).length;
    final started = !now.isBefore(pastMatch.match.endsAt);
    final decided = history.motmDecided(pastMatch, now);
    final canVote = history.canVoteMotm(pastMatch, widget.userId, now);
    final voting = canVote && (myVote == null || _editing);
    final muted = AppTextStyles.body(
      size: 12,
      weight: FontWeight.w600,
      color: AppColors.text.withValues(alpha: 0.55),
    );

    final Widget body;
    if (!started) {
      body = _Note(
        icon: Icons.lock_clock_rounded,
        text: 'Voting opens when the match ends at '
            '${formatMatchTime(pastMatch.match.endsAt)}.',
      );
    } else if (decided) {
      body = _MotmResults(pastMatch: pastMatch, history: history, myVote: myVote);
    } else if (voting) {
      final candidates = history.motmCandidates(pastMatch, widget.userId);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Who was the best player?', style: AppTextStyles.heading(size: 16)),
          const SizedBox(height: 10),
          for (final (index, candidate) in candidates.indexed) ...[
            if (index > 0) const SizedBox(height: 6),
            _MotmOption(
              player: candidate,
              selected: (_pending ?? myVote) == candidate.profileId,
              enabled: !widget.isSubmitting,
              onTap: () => setState(() => _pending = candidate.profileId),
            ),
          ],
          const SizedBox(height: 12),
          _MotmButton(
            label: widget.isSubmitting ? 'Submitting…' : 'Submit vote',
            primary: true,
            onPressed: _pending != null && _pending != myVote && !widget.isSubmitting
                ? () => context.read<MatchHistoryBloc>().add(
                      MotmVoteSubmitted(matchId: pastMatch.match.id, nomineeId: _pending!),
                    )
                : null,
          ),
          if (myVote != null) ...[
            const SizedBox(height: 6),
            _MotmButton(
              label: 'Cancel',
              onPressed: widget.isSubmitting
                  ? null
                  : () => setState(() {
                      _editing = false;
                      _pending = null;
                    }),
            ),
          ],
        ],
      );
    } else {
      // Voting open, but this viewer has voted (secret until decided) or
      // didn't play.
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Note(
            icon: Icons.how_to_vote_rounded,
            text: myVote != null
                ? 'You voted ${history.member(myVote)?.name ?? 'a former teammate'}. '
                    'Votes stay secret until the result.'
                : 'Only players who played can vote. The result shows once voting closes.',
          ),
          if (myVote != null && canVote) ...[
            const SizedBox(height: 10),
            _MotmButton(label: 'Change vote', onPressed: () => setState(() => _editing = true)),
          ],
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, size: 18, color: AppColors.teamGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'MAN OF THE MATCH',
                  style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.5)),
                ),
              ),
              if (started)
                Text(
                  '$votesCast of ${voters.length} voted',
                  style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.text.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          body,
          if (started && !decided) ...[
            const SizedBox(height: 10),
            Text(
              'Result when everyone who played has voted, or at '
              '${formatMatchTime(history.motmVotingClosesAt(pastMatch))} '
              '${formatMatchDate(history.motmVotingClosesAt(pastMatch))}.',
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}

/// The decided result: the winner(s) with a trophy and each nominee's
/// share — or, with no votes, nobody.
class _MotmResults extends StatelessWidget {
  const _MotmResults({required this.pastMatch, required this.history, required this.myVote});

  final PastMatch pastMatch;
  final MatchHistory history;
  final String? myVote;

  @override
  Widget build(BuildContext context) {
    final tally = pastMatch.motmTally;
    final totalVotes = pastMatch.motmVotes.length;
    if (totalVotes == 0) {
      return const _Note(
        icon: Icons.do_not_disturb_on_rounded,
        text: 'No Man of the Match — nobody voted.',
      );
    }
    // In team order, so a tie always reads the same way.
    final winnerIds = pastMatch.motmWinnerIds;
    final winners = [
      for (final member in history.members)
        if (winnerIds.contains(member.profileId)) member,
    ];
    final nominees = [
      for (final member in history.members)
        if ((tally[member.profileId] ?? 0) > 0) member,
    ]..sort((a, b) => tally[b.profileId]!.compareTo(tally[a.profileId]!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (final (index, winner) in winners.take(2).indexed) ...[
                if (index > 0) const SizedBox(width: 4),
                PlayerAvatar(player: winner, radius: 20),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      winners.map((winner) => winner.name).join(' & '),
                      style: AppTextStyles.heading(size: 16),
                    ),
                    Text(
                      winners.length > 1
                          ? 'Tied on ${tally[winners.first.profileId]} votes each'
                          : '${tally[winners.first.profileId]} of $totalVotes votes',
                      style: AppTextStyles.body(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.text.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.emoji_events_rounded, size: 28, color: AppColors.teamGold),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final (index, nominee) in nominees.indexed) ...[
          if (index > 0) const SizedBox(height: 10),
          _MotmResultRow(
            player: nominee,
            votes: tally[nominee.profileId]!,
            totalVotes: totalVotes,
            isMyVote: myVote == nominee.profileId,
          ),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.text.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body(
              size: 12.5,
              weight: FontWeight.w600,
              color: AppColors.text.withValues(alpha: 0.65),
            ),
          ),
        ),
      ],
    );
  }
}

class _MotmOption extends StatelessWidget {
  const _MotmOption({
    required this.player,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final MatchdayPlayer player;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neutral100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected ? const BorderSide(color: AppColors.accent, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 12),
              PlayerAvatar(player: player, radius: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w600),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.accent : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.text.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 13, color: AppColors.neutral100)
                    : null,
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _MotmResultRow extends StatelessWidget {
  const _MotmResultRow({
    required this.player,
    required this.votes,
    required this.totalVotes,
    required this.isMyVote,
  });

  final MatchdayPlayer player;
  final int votes;
  final int totalVotes;
  final bool isMyVote;

  @override
  Widget build(BuildContext context) {
    final share = totalVotes == 0 ? 0.0 : votes / totalVotes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PlayerAvatar(player: player, radius: 11),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                player.name,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(
                  size: 14,
                  weight: isMyVote ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (isMyVote) ...[
              const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
            ],
            Text(
              '$votes · ${(share * 100).round()}%',
              style: AppTextStyles.body(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.text.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: ColoredBox(
              color: AppColors.neutral300,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: share),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    heightFactor: 1,
                    child: const ColoredBox(color: AppColors.teamGold),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MotmButton extends StatelessWidget {
  const _MotmButton({required this.label, required this.onPressed, this.primary = false});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final background = primary ? AppColors.accent : AppColors.neutral100;
    final foreground = primary ? AppColors.neutral100 : AppColors.text;
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          disabledBackgroundColor: background.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            size: 14,
            weight: FontWeight.w700,
            color: onPressed == null ? foreground.withValues(alpha: 0.7) : foreground,
          ),
        ),
      ),
    );
  }
}

/// The match's bill, if the wallet has one for it.
class _PastMatchBill extends StatelessWidget {
  const _PastMatchBill({required this.matchId, required this.userId, required this.isManager});

  final String matchId;
  final String userId;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        final wallet = state.wallet;
        final walletMatch = wallet?.forMatch(matchId);
        final split = walletMatch == null ? null : wallet?.splitFor(walletMatch);
        if (walletMatch == null || split == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: BillCard(
            walletMatch: walletMatch,
            split: split,
            userId: userId,
            isManager: isManager,
          ),
        );
      },
    );
  }
}
