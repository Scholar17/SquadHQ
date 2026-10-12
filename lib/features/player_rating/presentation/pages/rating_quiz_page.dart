import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/sticky_action_sheet.dart';
import '../../domain/entities/player_rating.dart';
import '../bloc/rating_quiz_bloc.dart';
import '../rating_changes.dart';
import '../widgets/player_card.dart';

/// Opens Fill rating full-screen — from the Fill rating button on the
/// player's own Squad tab row. Resolves to the new rating, or null if they
/// backed out.
Future<PlayerRating?> showRatingQuiz(BuildContext context, {required String playerName}) =>
    Navigator.of(context, rootNavigator: true).push<PlayerRating>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BlocProvider(
          create: (_) => sl<RatingQuizBloc>()..add(const RatingQuizStarted()),
          child: RatingQuizPage(playerName: playerName),
        ),
      ),
    );

class RatingQuizPage extends StatefulWidget {
  const RatingQuizPage({super.key, required this.playerName});

  final String playerName;

  @override
  State<RatingQuizPage> createState() => _RatingQuizPageState();
}

class _RatingQuizPageState extends State<RatingQuizPage> {
  /// Which question is on screen.
  int _index = 0;

  void _pick(RatingQuizState state, RatingQuestion question, String answerId) {
    HapticFeedback.selectionClick();
    context.read<RatingQuizBloc>().add(
      RatingAnswerPicked(questionId: question.id, answerId: answerId),
    );
    // Moves on by itself, after a beat to see the pick land.
    if (_index < state.questions.length - 1) {
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _index++);
      });
    }
  }

  void _back(RatingQuizState state) {
    if (state.step == RatingQuizStep.questions) {
      if (_index > 0) {
        setState(() => _index--);
      } else {
        context.read<RatingQuizBloc>().add(const RatingBackToPositions());
      }
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RatingQuizBloc, RatingQuizState>(
      listenWhen: (previous, current) =>
          current.error != null && current.error != previous.error || previous.step != current.step,
      listener: (context, state) {
        if (state.error case final error?) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error)));
        }
        if (state.step == RatingQuizStep.questions) setState(() => _index = 0);
        if (state.step == RatingQuizStep.result) {
          HapticFeedback.mediumImpact();
          ratingChanges.bump();
        }
      },
      builder: (context, state) {
        final canGoBack =
            state.step == RatingQuizStep.questions || state.step == RatingQuizStep.positions;
        return PopScope(
          canPop: state.step != RatingQuizStep.questions,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && state.step == RatingQuizStep.questions) _back(state);
          },
          child: Scaffold(
            backgroundColor: AppColors.bg,
            appBar: state.step == RatingQuizStep.result
                ? null
                : AppBar(
                    automaticallyImplyLeading: false,
                    leading: canGoBack
                        ? IconButton(
                            onPressed: () => _back(state),
                            icon: Icon(
                              state.step == RatingQuizStep.positions
                                  ? Icons.close_rounded
                                  : Icons.arrow_back_rounded,
                            ),
                            tooltip: state.step == RatingQuizStep.positions ? 'Close' : 'Back',
                          )
                        : null,
                    title: Text('Your player card', style: AppTextStyles.title(size: 16)),
                  ),
            body: SafeArea(
              top: state.step == RatingQuizStep.result,
              child: switch (state.step) {
                RatingQuizStep.positions => _Positions(state: state),
                RatingQuizStep.questions => _Questions(
                  state: state,
                  index: _index.clamp(0, state.questions.length - 1),
                  onPick: (question, answerId) => _pick(state, question, answerId),
                  onJump: (index) => setState(() => _index = index),
                ),
                RatingQuizStep.result => _Reveal(
                  name: widget.playerName,
                  rating: state.result!,
                  onDone: () => Navigator.of(context).pop(state.result),
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

/// Step 1: 1-3 positions, the first tapped is the main one.
class _Positions extends StatelessWidget {
  const _Positions({required this.state});

  final RatingQuizState state;

  @override
  Widget build(BuildContext context) {
    if (state.positions.isEmpty) {
      return Center(
        child: state.loading
            ? const CircularProgressIndicator(color: AppColors.accent)
            : TextButton(
                onPressed: () => context.read<RatingQuizBloc>().add(const RatingQuizStarted()),
                child: const Text('Try again'),
              ),
      );
    }
    return StickyActionSheet(
      expand: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        Text('Where do you play?', style: AppTextStyles.heading(size: 26)),
        const SizedBox(height: 8),
        Text(
          'Pick up to 3 positions — the first one you tap is your main '
          'position, and decides your questions. You can only do this once.',
          style: AppTextStyles.body(size: 13.5, color: AppColors.textMuted),
        ),
        for (final group in PositionGroup.values) ...[
          const SizedBox(height: 18),
          Text(group.label.toUpperCase(), style: AppTextStyles.label(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final position in state.positions)
                if (position.group == group)
                  _PositionChip(position: position, order: state.picked.indexOf(position.code)),
            ],
          ),
        ],
      ],
      summary: state.picked.isEmpty
          ? null
          : Text(
              'Main: ${state.picked.first}'
              '${state.picked.length > 1 ? ' · also ${state.picked.skip(1).join(', ')}' : ''}',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(size: 12.5, weight: FontWeight.w700),
            ),
      action: _PrimaryButton(
        label: 'Next',
        loading: state.loading,
        onPressed: state.picked.isEmpty
            ? null
            : () => context.read<RatingQuizBloc>().add(const RatingPositionsConfirmed()),
      ),
    );
  }
}

class _PositionChip extends StatelessWidget {
  const _PositionChip({required this.position, required this.order});

  final RatingPosition position;

  /// Where it was picked (0 = main), or -1 when it isn't.
  final int order;

  @override
  Widget build(BuildContext context) {
    final picked = order >= 0;
    return Semantics(
      button: true,
      selected: picked,
      label: '${position.name}${order == 0 ? ', main position' : ''}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: picked ? AppColors.neutral900 : AppColors.card,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: picked ? AppColors.neutral900 : AppColors.text.withValues(alpha: 0.12),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.md,
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<RatingQuizBloc>().add(RatingPositionToggled(position.code));
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    position.code,
                    style: AppTextStyles.title(
                      size: 15,
                      color: picked ? AppColors.teamGold : AppColors.accent700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    position.name,
                    style: AppTextStyles.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: picked ? AppColors.onDark : AppColors.text,
                    ),
                  ),
                  if (picked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: AppColors.teamGold,
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        order == 0 ? 'MAIN' : '${order + 1}',
                        style: AppTextStyles.label(size: 9.5, color: AppColors.neutral800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step 2: one question at a time.
class _Questions extends StatelessWidget {
  const _Questions({
    required this.state,
    required this.index,
    required this.onPick,
    required this.onJump,
  });

  final RatingQuizState state;
  final int index;
  final void Function(RatingQuestion question, String answerId) onPick;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final question = state.questions[index];
    final chosen = state.answers[question.id];
    final isLast = index == state.questions.length - 1;
    return StickyActionSheet(
      expand: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        // Tappable progress: jump back to any answered question.
        Row(
          children: [
            for (final (i, q) in state.questions.indexed)
              Expanded(
                child: GestureDetector(
                  onTap: state.answers.containsKey(q.id) || i == index ? () => onJump(i) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == index
                          ? AppColors.accent
                          : state.answers.containsKey(q.id)
                          ? AppColors.accent300
                          : AppColors.neutral300,
                      borderRadius: AppRadius.pill,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'QUESTION ${index + 1} OF ${state.questions.length}',
          style: AppTextStyles.label(color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animation),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(question.id),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(question.body, style: AppTextStyles.title(size: 20, height: 1.3)),
              const SizedBox(height: 18),
              for (final answer in question.answers) ...[
                _AnswerCard(
                  answer: answer,
                  selected: chosen == answer.id,
                  onTap: () => onPick(question, answer.id),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
      action: isLast || state.allAnswered
          ? _PrimaryButton(
              label: 'See my rating',
              loading: state.loading,
              onPressed: state.allAnswered
                  ? () => context.read<RatingQuizBloc>().add(const RatingQuizSubmitted())
                  : null,
            )
          : _PrimaryButton(
              label: 'Next question',
              onPressed: chosen == null ? null : () => onJump(index + 1),
            ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer, required this.selected, required this.onTap});

  final RatingAnswer answer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent100 : AppColors.card,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.text.withValues(alpha: 0.1),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? AppShadows.subtle : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.md,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      answer.body,
                      style: AppTextStyles.body(
                        size: 14.5,
                        weight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? AppColors.accent800 : null,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            key: ValueKey('picked'),
                            color: AppColors.accent,
                          )
                        : Icon(
                            Icons.circle_outlined,
                            key: const ValueKey('open'),
                            color: AppColors.text.withValues(alpha: 0.25),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step 3: the card, revealed.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.name, required this.rating, required this.onDone});

  final String name;
  final PlayerRating rating;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return StickyActionSheet(
      expand: true,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text(
          'Your card is in',
          textAlign: TextAlign.center,
          style: AppTextStyles.heading(size: 26),
        ),
        const SizedBox(height: 6),
        Text(
          "Your squad's been told. Log your stats after each match (clean sheets "
          'count by themselves) — every ${RatedPlayer.boostEvery} matches you can level it up.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        PlayerCardView(name: name, rating: rating, caption: ratingCaption(rating)),
      ],
      action: _PrimaryButton(label: 'Done', onPressed: onDone),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onDark,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
          shape: const StadiumBorder(),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onDark),
              )
            : Text(label, style: AppTextStyles.title(size: 16, color: AppColors.onDark)),
      ),
    );
  }
}
