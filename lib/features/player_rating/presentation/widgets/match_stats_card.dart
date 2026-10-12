import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/player_rating.dart';
import '../../domain/usecases/player_rating_usecases.dart';

/// "Your stats" on a finished match you played: goals, assists and saves,
/// optional — they feed the level-up every 10 matches.
class MatchStatsCard extends StatefulWidget {
  const MatchStatsCard({super.key, required this.matchId});

  final String matchId;

  @override
  State<MatchStatsCard> createState() => _MatchStatsCardState();
}

class _MatchStatsCardState extends State<MatchStatsCard> {
  MatchStats? _saved;
  MatchStats _draft = const MatchStats();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<GetMyMatchStats>()(widget.matchId);
    if (!mounted) return;
    result.fold((_) => setState(() => _saved = const MatchStats()), (stats) {
      setState(() {
        _saved = stats;
        _draft = stats;
      });
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await sl<LogMatchStats>()((matchId: widget.matchId, stats: _draft));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    result.fold(
      (failure) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) {
        HapticFeedback.lightImpact();
        setState(() {
          _saving = false;
          _saved = _draft.copyWith(logged: true);
          _draft = _saved!;
        });
        messenger.showSnackBar(const SnackBar(content: Text('Stats saved')));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    final changed = saved != null && LoggedStat.values.any((s) => _draft.of(s) != saved.of(s));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
              Expanded(
                child: Text('YOUR STATS', style: AppTextStyles.label(color: AppColors.textMuted)),
              ),
              if (saved?.logged ?? false)
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: AppColors.accent2_700),
                    const SizedBox(width: 4),
                    Text(
                      'Logged',
                      style: AppTextStyles.body(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: AppColors.accent2_700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Optional — counts towards levelling up your card every ${RatedPlayer.boostEvery} matches. '
            'Clean sheets come from the score.',
            style: AppTextStyles.body(size: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          if (saved == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
                ),
              ),
            )
          else ...[
            if (saved.cleanSheet == true) ...[const _CleanSheet(), const SizedBox(height: 4)],
            // Only what fits their position: tackles for a defender, saves
            // for a keeper.
            for (final stat in LoggedStat.forGroup(saved.group))
              _Stepper(
                label: stat.label,
                value: _draft.of(stat),
                max: stat.max,
                onStep: (delta) => setState(() => _draft = _draft.step(stat, delta)),
              ),
            if (changed || !saved.logged) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onDark,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    _saving ? 'Saving…' : 'Save my stats',
                    style: AppTextStyles.title(size: 13.5, color: AppColors.onDark),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// "Clean sheet ✓" — from the recorded score, nothing to log.
class _CleanSheet extends StatelessWidget {
  const _CleanSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: AppColors.accent2_100, borderRadius: AppRadius.sm),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, size: 16, color: AppColors.accent2_700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Clean sheet — counted for you automatically',
              style: AppTextStyles.body(
                size: 12.5,
                weight: FontWeight.w700,
                color: AppColors.accent2_900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.max,
    required this.onStep,
  });

  final String label;
  final int value;
  final int max;

  /// +1 or −1, applied to the current value — two quick taps both count.
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppTextStyles.body(size: 14, weight: FontWeight.w600)),
        ),
        IconButton(
          onPressed: value > 0 ? () => onStep(-1) : null,
          icon: const Icon(Icons.remove_rounded),
          tooltip: 'One fewer ${label.toLowerCase()}',
        ),
        SizedBox(
          width: 30,
          child: Text('$value', textAlign: TextAlign.center, style: AppTextStyles.title(size: 17)),
        ),
        IconButton(
          onPressed: value < max
              ? () {
                  HapticFeedback.selectionClick();
                  onStep(1);
                }
              : null,
          icon: const Icon(Icons.add_rounded),
          tooltip: 'One more ${label.toLowerCase()}',
        ),
      ],
    );
  }
}
