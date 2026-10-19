import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../player_rating/domain/usecases/player_rating_usecases.dart';
import '../../domain/entities/match_history.dart';
import '../../domain/entities/match_questions.dart';
import '../../domain/entities/matchday_player.dart';
import '../../domain/usecases/match_after_game.dart';
import '../bloc/match_history_bloc.dart';
import '../match_formatting.dart';
import '../widgets/match_history_widgets.dart';

/// Opens "Rate your game" for [matchId] over the tabs.
Future<void> showMatchQuestions(BuildContext context, {required String matchId, required String userId}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => MatchQuestionsPage(matchId: matchId, userId: userId),
    ),
  );
}

enum _Step { played, position, question, pick, motm, done }

/// The after-match flow, one screen per question, tap to answer:
///   - a Maybe player first says whether they played (No ends it);
///   - where they played most (prefilled with their main position);
///   - 3 questions for that position, then a teammate pick;
///   - last, the Man of the Match vote, if it's still open for them.
/// Every question has Not sure. Answers save before the MOTM step, and can
/// be changed until the questions close.
class MatchQuestionsPage extends StatefulWidget {
  const MatchQuestionsPage({super.key, required this.matchId, required this.userId});

  final String matchId;
  final String userId;

  @override
  State<MatchQuestionsPage> createState() => _MatchQuestionsPageState();
}

class _MatchQuestionsPageState extends State<MatchQuestionsPage> {
  _Step? _step;
  int _question = 0;
  PlayedPosition _position = PlayedPosition.midfielder;
  final _answers = <int?>[null, null, null];
  String? _pick;
  bool _busy = false;
  bool _notPlayed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  PastMatch? get _pastMatch => context.read<MatchHistoryBloc>().state.history?.forMatch(widget.matchId);

  /// Starts on "Did you play?" for an unconfirmed Maybe, else the
  /// position — prefilled with their saved answers, or their main position.
  Future<void> _load() async {
    final (saved, rating) = await (
      sl<GetMyMatchAnswers>()(widget.matchId),
      sl<GetMyRating>()(const NoParams()),
    ).wait;
    if (!mounted) return;
    final answers = saved.fold((_) => null, (answers) => answers);
    final group = rating.fold((_) => null, (rating) => rating?.group);
    setState(() {
      if (answers != null) {
        _position = answers.position;
        _answers.setAll(0, answers.answers);
        _pick = answers.pickId;
      } else if (group != null) {
        _position = PlayedPosition.fromDb(group.name) ?? _position;
      }
      _step = (_pastMatch?.needsPlayedCheck(widget.userId) ?? false) ? _Step.played : _Step.position;
    });
  }

  void _fail(String message) {
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _answerPlayed(bool played) async {
    if (played) {
      // Saving the answers says they played — nothing to send yet.
      setState(() => _step = _Step.position);
      return;
    }
    setState(() => _busy = true);
    final result = await sl<SetMatchPlayed>()((matchId: widget.matchId, played: false));
    if (!mounted) return;
    result.fold((failure) => _fail(failure.message), (_) {
      context.read<MatchHistoryBloc>().add(const MatchHistoryStarted());
      setState(() {
        _busy = false;
        _notPlayed = true;
        _step = _Step.done;
      });
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final result = await sl<SubmitMatchAnswers>()((
      matchId: widget.matchId,
      answers: MatchAnswers(position: _position, answers: [..._answers], pickId: _pick),
    ));
    if (!mounted) return;
    result.fold((failure) => _fail(failure.message), (_) {
      HapticFeedback.lightImpact();
      final bloc = context.read<MatchHistoryBloc>()..add(const MatchHistoryStarted());
      final history = bloc.state.history;
      final pastMatch = _pastMatch;
      final canVote =
          history != null &&
          pastMatch != null &&
          !pastMatch.motmVotes.containsKey(widget.userId) &&
          history.canVoteMotm(pastMatch, widget.userId, DateTime.now());
      setState(() {
        _busy = false;
        _step = canVote ? _Step.motm : _Step.done;
      });
    });
  }

  void _back() {
    setState(() {
      switch (_step) {
        case _Step.question when _question > 0:
          _question--;
        case _Step.question:
          _step = _Step.position;
        case _Step.pick:
          _step = _Step.question;
          _question = 2;
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<MatchHistoryBloc>().state.history;
    final pastMatch = history?.forMatch(widget.matchId);
    final step = _step;
    final canGoBack = step == _Step.question || step == _Step.pick;
    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: AppColors.text,
          title: Text(
            pastMatch == null ? 'Rate your game' : 'vs ${pastMatch.match.opponent}',
            style: AppTextStyles.title(size: 16),
          ),
        ),
        body: SafeArea(
          child: history == null || pastMatch == null || step == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: _body(context, history, pastMatch, step),
                ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, MatchHistory history, PastMatch pastMatch, _Step step) {
    final questions = matchQuestions[_position]!;
    switch (step) {
      case _Step.played:
        return _Question(
          progress: null,
          title: 'Did you play today?',
          subtitle: 'You said Maybe for ${formatMatchDate(pastMatch.match.kickoffAt)}.',
          choices: const ['Yes, I played', "No, I didn't"],
          selected: null,
          showNotSure: false,
          enabled: !_busy,
          onPick: (index) => _answerPlayed(index == 0),
        );
      case _Step.position:
        return _Question(
          progress: 0,
          title: 'Where did you play most today?',
          subtitle: 'Just for this match.',
          choices: [for (final position in PlayedPosition.values) position.label],
          selected: _position.index,
          showNotSure: false,
          onPick: (index) => setState(() {
            final position = PlayedPosition.values[index ?? _position.index];
            if (position != _position) {
              // Different questions: start them fresh.
              _answers.setAll(0, [null, null, null]);
            }
            _position = position;
            _question = 0;
            _step = _Step.question;
          }),
        );
      case _Step.question:
        final question = questions[_question];
        return _Question(
          progress: _question + 1,
          title: question.text,
          choices: question.choices,
          selected: _answers[_question],
          onPick: (index) => setState(() {
            _answers[_question] = index;
            if (_question < questions.length - 1) {
              _question++;
            } else {
              _step = _Step.pick;
            }
          }),
        );
      case _Step.pick:
        final mates = [
          for (final member in history.members)
            if (member.profileId != widget.userId && pastMatch.takingPartIds.contains(member.profileId))
              member,
        ];
        return _PlayerPick(
          progress: 4,
          title: matchPickQuestions[_position]!,
          subtitle: "You can't pick yourself.",
          players: mates,
          selected: _pick,
          enabled: !_busy,
          busyLabel: _busy ? 'Saving…' : null,
          onPick: (profileId) {
            setState(() => _pick = profileId);
            _submit();
          },
        );
      case _Step.motm:
        final candidates = history.motmCandidates(pastMatch, widget.userId);
        final isSubmitting = context.watch<MatchHistoryBloc>().state is MatchHistorySubmitting;
        return BlocListener<MatchHistoryBloc, MatchHistoryState>(
          listenWhen: (previous, current) =>
              current is MatchHistoryFailure ||
              (previous is MatchHistorySubmitting && current is MatchHistoryLoaded),
          listener: (context, state) {
            if (state case MatchHistoryFailure(:final message)) {
              _fail(message);
              return;
            }
            setState(() => _step = _Step.done);
          },
          child: _PlayerPick(
            progress: null,
            title: 'Who was Man of the Match?',
            subtitle: 'Votes stay secret until the result.',
            players: candidates,
            selected: null,
            enabled: !isSubmitting,
            busyLabel: isSubmitting ? 'Voting…' : null,
            notSureLabel: 'Skip for now',
            onPick: (profileId) {
              if (profileId == null) {
                setState(() => _step = _Step.done);
                return;
              }
              context.read<MatchHistoryBloc>().add(
                MotmVoteSubmitted(matchId: widget.matchId, nomineeId: profileId),
              );
            },
          ),
        );
      case _Step.done:
        return _Done(notPlayed: _notPlayed, onClose: () => Navigator.of(context).pop());
    }
  }
}

/// "Question 2 of 4" dots — null hides them.
class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  /// 0: the setup question; 1–4: the questions.
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i <= 4; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= step ? AppColors.accent : AppColors.neutral300,
                borderRadius: AppRadius.pill,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({
    required this.progress,
    required this.title,
    required this.choices,
    required this.selected,
    required this.onPick,
    this.subtitle,
    this.showNotSure = true,
    this.enabled = true,
  });

  final int? progress;
  final String title;
  final String? subtitle;
  final List<String> choices;
  final int? selected;
  final bool showNotSure;
  final bool enabled;

  /// The choice's index, or null for Not sure.
  final ValueChanged<int?> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (progress case final step?) ...[_Progress(step: step), const SizedBox(height: 20)],
        Text(title, style: AppTextStyles.heading(size: 22)),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.body(size: 13, color: AppColors.textMuted)),
        ],
        const SizedBox(height: 18),
        for (final (index, choice) in choices.indexed) ...[
          _Choice(label: choice, selected: selected == index, onTap: enabled ? () => onPick(index) : null),
          const SizedBox(height: 8),
        ],
        if (showNotSure)
          _Choice(label: 'Not sure', muted: true, onTap: enabled ? () => onPick(null) : null),
      ],
    );
  }
}

class _PlayerPick extends StatelessWidget {
  const _PlayerPick({
    required this.progress,
    required this.title,
    required this.players,
    required this.selected,
    required this.onPick,
    this.subtitle,
    this.enabled = true,
    this.busyLabel,
    this.notSureLabel = 'Not sure',
  });

  final int? progress;
  final String title;
  final String? subtitle;
  final List<MatchdayPlayer> players;
  final String? selected;
  final bool enabled;
  final String? busyLabel;
  final String notSureLabel;

  /// Their profile id, or null for Not sure / Skip.
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (progress case final step?) ...[_Progress(step: step), const SizedBox(height: 20)],
        Text(title, style: AppTextStyles.heading(size: 22)),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.body(size: 13, color: AppColors.textMuted)),
        ],
        const SizedBox(height: 18),
        if (busyLabel case final label?) ...[
          Text(label, style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: AppColors.accent700)),
          const SizedBox(height: 8),
        ],
        for (final player in players) ...[
          _Choice(
            label: player.name,
            leading: PlayerAvatar(player: player, radius: 14),
            selected: selected == player.profileId,
            onTap: enabled ? () => onPick(player.profileId) : null,
          ),
          const SizedBox(height: 8),
        ],
        _Choice(label: notSureLabel, muted: true, onTap: enabled ? () => onPick(null) : null),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, this.onTap, this.selected = false, this.muted = false, this.leading});

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool muted;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: muted ? AppColors.neutral200 : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: selected
            ? const BorderSide(color: AppColors.accent, width: 2)
            : BorderSide(color: AppColors.text.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 14),
              if (leading case final leading?) ...[leading, const SizedBox(width: 10)],
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    size: 15,
                    weight: FontWeight.w600,
                    color: muted ? AppColors.textMuted : AppColors.text,
                  ),
                ),
              ),
              if (selected) const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.accent),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.notPlayed, required this.onClose});

  final bool notPlayed;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          notPlayed ? Icons.event_busy_rounded : Icons.check_circle_rounded,
          size: 56,
          color: notPlayed ? AppColors.textMuted : AppColors.accent2_700,
        ),
        const SizedBox(height: 14),
        Text(notPlayed ? 'Got it' : 'Thanks!', style: AppTextStyles.heading(size: 24)),
        const SizedBox(height: 6),
        Text(
          notPlayed
              ? "This match won't count for you."
              : 'Your answers count toward your next level-up. You can change them until the questions close.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 13.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: onClose,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onDark,
              shape: const StadiumBorder(),
            ),
            child: Text('Done', style: AppTextStyles.title(size: 14, color: AppColors.onDark)),
          ),
        ),
      ],
    );
  }
}
