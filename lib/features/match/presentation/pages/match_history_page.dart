import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_history.dart';
import '../bloc/match_history_bloc.dart';
import '../match_formatting.dart';
import '../widgets/match_history_widgets.dart';
import 'past_match_page.dart';

/// [MatchHistoryPage]'s arguments, bundled for go_router's `extra:`. It's a
/// full-screen push outside the tab shell, so the Manager/Player view is
/// passed in rather than read from the shell's TeamBloc.
class MatchHistoryArgs {
  const MatchHistoryArgs({
    required this.teamId,
    required this.teamName,
    required this.userId,
    required this.isManager,
  });

  final String teamId;
  final String teamName;
  final String userId;

  /// Whether the viewer is an admin in the Manager view — lets them record
  /// scores.
  final bool isManager;
}

/// Past matches, newest first, grouped by month — opened from the Match
/// tab's history button. Each row shows the score and Man of the Match
/// when they've been filled in; tapping one opens [PastMatchPage]. Reads
/// the app-root [MatchHistoryBloc], refreshing it on open.
class MatchHistoryPage extends StatefulWidget {
  const MatchHistoryPage({super.key, required this.args});

  final MatchHistoryArgs args;

  @override
  State<MatchHistoryPage> createState() => _MatchHistoryPageState();
}

class _MatchHistoryPageState extends State<MatchHistoryPage> {
  MatchHistoryArgs get args => widget.args;

  @override
  void initState() {
    super.initState();
    context.read<MatchHistoryBloc>().add(const MatchHistoryStarted());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Match history', style: AppTextStyles.heading(size: 16)),
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
          if (history == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (history.matches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'No past matches yet. Once a match has kicked off, it shows up here.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    size: 13.5,
                    color: AppColors.text.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () {
              final done = Completer<void>();
              context.read<MatchHistoryBloc>().add(MatchHistoryStarted(done: done));
              return done.future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                for (final (index, pastMatch) in history.matches.indexed) ...[
                  if (_startsMonth(history.matches, index))
                    Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 8 : 18, bottom: 10),
                      child: Text(
                        _monthLabel(pastMatch.match.kickoffAt),
                        style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                      ),
                    )
                  else
                    const SizedBox(height: 10),
                  _HistoryRow(
                    pastMatch: pastMatch,
                    history: history,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PastMatchPage(
                          matchId: pastMatch.match.id,
                          teamName: args.teamName,
                          userId: args.userId,
                          isManager: args.isManager,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String _monthLabel(DateTime kickoffAt) {
    final local = kickoffAt.toLocal();
    return '${monthNames[local.month - 1].toUpperCase()} ${local.year}';
  }

  static bool _startsMonth(List<PastMatch> matches, int index) {
    if (index == 0) return true;
    final current = matches[index].match.kickoffAt.toLocal();
    final previous = matches[index - 1].match.kickoffAt.toLocal();
    return current.month != previous.month || current.year != previous.year;
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.pastMatch, required this.history, required this.onTap});

  final PastMatch pastMatch;
  final MatchHistory history;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final match = pastMatch.match;
    final local = match.kickoffAt.toLocal();
    // Only once decided — it's a secret ballot until then. In team order,
    // so a tie always reads the same way.
    final winnerIds = history.motmDecided(pastMatch, DateTime.now())
        ? pastMatch.motmWinnerIds
        : const <String>{};
    final winners = [
      for (final member in history.members)
        if (winnerIds.contains(member.profileId)) member.name,
    ];
    final details = [?match.venue, '${pastMatch.playedIds.length} played'].join(' · ');
    return Material(
      color: AppColors.neutral100,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.neutral900,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${local.day}',
                      style: AppTextStyles.heading(size: 18, color: AppColors.teamGold),
                    ),
                    Text(
                      monthNames[local.month - 1].toUpperCase(),
                      style: AppTextStyles.body(
                        size: 10,
                        weight: FontWeight.w700,
                        color: AppColors.neutral100.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs ${match.opponent}',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.heading(size: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        size: 12,
                        color: AppColors.text.withValues(alpha: 0.55),
                      ),
                    ),
                    if (winners.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            size: 14,
                            color: AppColors.teamGold,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              winners.join(' & '),
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body(size: 12, weight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (match.result != null)
                ResultScore(match: match)
              else
                Text(
                  'No score',
                  style: AppTextStyles.body(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: AppColors.text.withValues(alpha: 0.4),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: AppColors.text.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A W/D/L badge over the score, e.g. "W" over "3–2".
class ResultScore extends StatelessWidget {
  const ResultScore({super.key, required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    final result = match.result;
    if (result == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ResultBadge(result: result),
        const SizedBox(height: 4),
        Text('${match.ourScore}–${match.theirScore}', style: AppTextStyles.heading(size: 14)),
      ],
    );
  }
}
