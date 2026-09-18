import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/match.dart' as match_entity;
import '../bloc/match_bloc.dart';
import '../bloc/match_state.dart';
import '../match_formatting.dart';
import '../widgets/create_match_sheet.dart';
import '../widgets/match_row.dart';

/// Reached from Home's "See all matches" button. Reads the same ambient
/// [MatchBloc] Home does — no separate fetch, it's already loaded every
/// upcoming match for the active team, not just the two-item preview.
class MatchListPage extends StatelessWidget {
  const MatchListPage({
    super.key,
    required this.activeTeamId,
    required this.canCreateMatch,
  });

  final String activeTeamId;
  final bool canCreateMatch;

  /// Same one-pass unwrap used elsewhere for Submitting/Failure.
  static List<match_entity.Match> _settledMatches(MatchState state) => switch (state) {
        MatchLoaded(:final matches) => matches,
        MatchSubmitting(:final previous) => _settledMatches(previous),
        MatchFailure(:final previous) => _settledMatches(previous),
        _ => const [],
      };

  static Map<DateTime, List<match_entity.Match>> _groupByDate(
    List<match_entity.Match> matches,
  ) {
    final groups = <DateTime, List<match_entity.Match>>{};
    for (final match in matches) {
      final local = match.kickoffAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      groups.putIfAbsent(day, () => []).add(match);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Matches', style: AppTextStyles.heading(size: 16)),
      ),
      body: SafeArea(
        child: BlocBuilder<MatchBloc, MatchState>(
          builder: (context, state) {
            final matches = _settledMatches(state);
            if (matches.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    canCreateMatch
                        ? 'No upcoming matches. Tap the button below to schedule one.'
                        : "No upcoming matches — your team's admin hasn't scheduled one yet.",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      size: 13.5,
                      color: AppColors.text.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }
            final groups = _groupByDate(matches);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                for (final entry in groups.entries) ...[
                  Text(
                    formatMatchDate(entry.value.first.kickoffAt).toUpperCase(),
                    style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
                  ),
                  const SizedBox(height: 10),
                  for (final match in entry.value) ...[
                    MatchRow(match: match),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: canCreateMatch
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bg,
              onPressed: () => showCreateMatchSheet(context, teamId: activeTeamId),
              icon: const Icon(Icons.add),
              label: Text(
                'New match',
                style: AppTextStyles.heading(size: 13, color: AppColors.bg),
              ),
            )
          : null,
    );
  }
}
