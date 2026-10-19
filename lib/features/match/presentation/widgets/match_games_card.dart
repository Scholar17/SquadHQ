import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/clock/clock_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/match_history.dart';
import '../../domain/entities/match_questions.dart';
import '../bloc/match_history_bloc.dart';

/// GAMES: a match's short games, one row each ("Game 2 · 3–1"). Anyone in
/// the match fills in the scores from kickoff until the questions close;
/// Game 1 shows before anyone saves it. Tap a row to change it; "+ Add
/// game" adds the next. Each row says who changed it last.
class MatchGamesCard extends StatelessWidget {
  const MatchGamesCard({
    super.key,
    required this.pastMatch,
    required this.history,
    required this.teamName,
    required this.userId,
  });

  final PastMatch pastMatch;
  final MatchHistory history;
  final String teamName;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final now = ClockScope.now(context);
    final canEdit = history.canEditGames(pastMatch, userId, now);
    final games = pastMatch.games;
    // Game 1 is there from the start, even before anyone saves it.
    final rows = games.isEmpty && canEdit ? const [MatchGame(gameNo: 1)] : games;
    final saved = {for (final game in games) game.gameNo};
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('GAMES', style: AppTextStyles.label(color: AppColors.textMuted))),
              if (games.isNotEmpty) Text(_tally(games), style: AppTextStyles.label(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No game scores.',
                style: AppTextStyles.body(size: 12.5, color: AppColors.textMuted),
              ),
            )
          else
            for (final game in rows)
              _GameRow(
                game: game,
                saved: saved.contains(game.gameNo),
                changedBy: switch (game.updatedBy) {
                  null => null,
                  final id when id == userId => 'you',
                  final id => history.member(id)?.name.split(' ').first,
                },
                onTap: canEdit
                    ? () => _showGameSheet(
                        context,
                        matchId: pastMatch.match.id,
                        game: game,
                        teamName: teamName,
                        opponent: pastMatch.match.opponent,
                        // Only the last saved game can go, so numbers stay in order.
                        canRemove: games.isNotEmpty && game.gameNo == games.last.gameNo,
                      )
                    : null,
              ),
          if (canEdit) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: games.isEmpty || games.length >= 20
                  ? null
                  : () => _showGameSheet(
                      context,
                      matchId: pastMatch.match.id,
                      game: MatchGame(gameNo: games.last.gameNo + 1),
                      teamName: teamName,
                      opponent: pastMatch.match.opponent,
                      canRemove: false,
                    ),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent700),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Add game', style: AppTextStyles.title(size: 13, color: AppColors.accent700)),
            ),
          ] else if (games.isNotEmpty || rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                now.isBefore(history.questionsCloseAt(pastMatch))
                    ? 'Players in this match fill in the scores.'
                    : 'Scores closed 2 days after the match.',
                style: AppTextStyles.body(size: 11.5, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  /// "2W 1D 1L" over the scored games.
  static String _tally(List<MatchGame> games) {
    var won = 0, drawn = 0, lost = 0;
    for (final game in games) {
      if (game.isNotSure) continue;
      final (ours, theirs) = (game.ourScore!, game.theirScore!);
      if (ours > theirs) {
        won++;
      } else if (ours == theirs) {
        drawn++;
      } else {
        lost++;
      }
    }
    return [if (won > 0) '${won}W', if (drawn > 0) '${drawn}D', if (lost > 0) '${lost}L'].join(' ');
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.saved, this.changedBy, this.onTap});

  final MatchGame game;

  /// False for the Game 1 placeholder nobody has filled in.
  final bool saved;
  final String? changedBy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppTextStyles.body(size: 11.5, color: AppColors.textMuted);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text('Game ${game.gameNo}', style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700)),
            ),
            Expanded(
              child: !saved
                  ? Text('Tap to add the score', style: muted)
                  : game.isNotSure
                  ? Text('Not sure', style: AppTextStyles.body(size: 13.5, color: AppColors.textMuted))
                  : Text(game.scoreLabel, style: AppTextStyles.title(size: 16)),
            ),
            if (saved && changedBy != null) Text('by $changedBy', style: muted),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit_rounded, size: 16, color: AppColors.text.withValues(alpha: 0.35)),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showGameSheet(
  BuildContext context, {
  required String matchId,
  required MatchGame game,
  required String teamName,
  required String opponent,
  required bool canRemove,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => BlocProvider.value(
      value: context.read<MatchHistoryBloc>(),
      child: _GameSheet(
        matchId: matchId,
        game: game,
        teamName: teamName,
        opponent: opponent,
        canRemove: canRemove,
      ),
    ),
  );
}

/// One game's score: two steppers, or "Not sure".
class _GameSheet extends StatefulWidget {
  const _GameSheet({
    required this.matchId,
    required this.game,
    required this.teamName,
    required this.opponent,
    required this.canRemove,
  });

  final String matchId;
  final MatchGame game;
  final String teamName;
  final String opponent;
  final bool canRemove;

  @override
  State<_GameSheet> createState() => _GameSheetState();
}

class _GameSheetState extends State<_GameSheet> {
  late int _ours = widget.game.ourScore ?? 0;
  late int _theirs = widget.game.theirScore ?? 0;

  void _save({required bool notSure}) {
    context.read<MatchHistoryBloc>().add(
      MatchGameSaved(
        matchId: widget.matchId,
        gameNo: widget.game.gameNo,
        ourScore: notSure ? null : _ours,
        theirScore: notSure ? null : _theirs,
      ),
    );
  }

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
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
      },
      child: BlocBuilder<MatchHistoryBloc, MatchHistoryState>(
        builder: (context, state) {
          final busy = state is MatchHistorySubmitting;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Game ${widget.game.gameNo}', style: AppTextStyles.title(size: 18)),
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
                          label: widget.opponent,
                          value: _theirs,
                          onChanged: (value) => setState(() => _theirs = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: busy ? null : () => _save(notSure: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onDark,
                        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: Text(
                        busy ? 'Saving…' : 'Save score',
                        style: AppTextStyles.title(size: 14, color: AppColors.onDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: busy ? null : () => _save(notSure: true),
                        child: Text('Not sure', style: AppTextStyles.title(size: 13)),
                      ),
                      if (widget.canRemove)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => context.read<MatchHistoryBloc>().add(
                                  MatchGameRemoved(matchId: widget.matchId, gameNo: widget.game.gameNo),
                                ),
                          style: TextButton.styleFrom(foregroundColor: AppColors.accent700),
                          child: Text(
                            'Remove game',
                            style: AppTextStyles.title(size: 13, color: AppColors.accent700),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    'Not sure still counts the game as played, but not for wins or clean sheets.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(size: 11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        },
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
              child: Text('$value', textAlign: TextAlign.center, style: AppTextStyles.heading(size: 30)),
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
