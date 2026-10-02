import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/match.dart' as match_entity;
import '../bloc/match_bloc.dart';
import '../bloc/match_state.dart';
import '../match_formatting.dart';
import '../widgets/create_match_sheet.dart';
import '../widgets/match_row.dart';

/// Every upcoming match, grouped by date — reached from Home's "See all
/// matches" and the Match tab's "See more". Reads the same ambient
/// [MatchBloc] they do — no separate fetch, it's already loaded every
/// upcoming match for the active team. Tapping a match opens its detail
/// screen, where players RSVP.
class MatchListPage extends StatelessWidget {
  const MatchListPage({
    super.key,
    required this.activeTeamId,
    required this.teamName,
    required this.userId,
    required this.canCreateMatch,
  });

  final String activeTeamId;
  final String teamName;
  final String userId;
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
        title: Text('Upcoming matches', style: AppTextStyles.heading(size: 16)),
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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => context.push(
                              AppRoutes.upcomingMatch,
                              extra: UpcomingMatchArgs(
                                matchId: match.id,
                                teamName: teamName,
                                userId: userId,
                                isManager: canCreateMatch,
                              ),
                            ),
                            child: MatchRow(match: match),
                          ),
                        ),
                        if (match.id == matches.first.id)
                          Positioned(
                            top: -7,
                            right: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'NEXT',
                                style: AppTextStyles.body(
                                  size: 10,
                                  weight: FontWeight.w800,
                                  color: AppColors.neutral100,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
