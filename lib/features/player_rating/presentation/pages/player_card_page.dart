import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/player_rating.dart';
import '../bloc/team_ratings_bloc.dart';
import '../widgets/player_card.dart';

/// Opens [player]'s card over the tabs, sharing the Squad tab's bloc so a
/// boost shows straight away.
Future<void> showPlayerCard(BuildContext context, {required String profileId, required String me}) {
  final bloc = context.read<TeamRatingsBloc>();
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: PlayerCardPage(profileId: profileId, me: me),
      ),
    ),
  );
}

/// A teammate's card — or yours, with Fill rating / Level up.
class PlayerCardPage extends StatelessWidget {
  const PlayerCardPage({super.key, required this.profileId, required this.me});

  final String profileId;
  final String me;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('Player card', style: AppTextStyles.title(size: 16))),
      body: BlocConsumer<TeamRatingsBloc, TeamRatingsState>(
        listenWhen: (previous, current) =>
            current.improvedTo != null ||
            (current.error != null && current.error != previous.error),
        listener: (context, state) {
          final message = state.improvedTo != null
              ? 'Levelled up — you\'re now ${state.improvedTo} OVR'
              : state.error;
          if (message == null) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          final player = state.players?.where((p) => p.profileId == profileId).firstOrNull;
          if (player == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          final isMe = player.profileId == me;
          final rating = player.rating;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (rating != null)
                PlayerCardView(
                  name: player.name,
                  rating: rating,
                  player: player,
                  caption: ratingCaption(rating),
                )
              else
                _Unrated(name: player.name, username: player.username, isMe: isMe),
              if (isMe && rating != null) ...[
                const SizedBox(height: 16),
                _LevelUp(player: player, improving: state.improving),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Unrated extends StatelessWidget {
  const _Unrated({required this.name, this.username, required this.isMe});

  final String name;
  final String? username;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.xl,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(name, style: AppTextStyles.heading(size: 24)),
          if (username case final username?)
            Text(
              '@$username',
              style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: AppColors.textMuted),
            ),
          const SizedBox(height: 6),
          Text(
            isMe
                ? "You haven't rated yourself yet — tap Fill rating on your row in the Squad tab."
                : "$name hasn't filled in their rating yet.",
            textAlign: TextAlign.center,
            style: AppTextStyles.body(size: 13.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Progress to the next 10-match boost, and the button once it's ready.
class _LevelUp extends StatelessWidget {
  const _LevelUp({required this.player, required this.improving});

  final RatedPlayer player;
  final bool improving;

  @override
  Widget build(BuildContext context) {
    final ready = player.canImprove;
    final progress = player.progress.clamp(0, RatedPlayer.boostEvery);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ready ? AppColors.accent100 : AppColors.card,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: ready
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.text.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT LEVEL-UP', style: AppTextStyles.label(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Text(
            ready
                ? '${RatedPlayer.boostEvery} matches played — level up your card'
                : '$progress of ${RatedPlayer.boostEvery} matches played',
            style: AppTextStyles.title(size: 15),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress / RatedPlayer.boostEvery),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: AppColors.neutral300,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(switch (player.rating?.group) {
            PositionGroup.defender =>
              'Your level-up is based on clean sheets (from the score) and the '
                  'tackles & interceptions you log after each match.',
            PositionGroup.goalkeeper =>
              'Your level-up is based on clean sheets (from the score) and the '
                  'saves you log after each match.',
            PositionGroup.midfielder =>
              'Your level-up is based on the assists, goals and tackles you log '
                  'after each match.',
            _ => 'Your level-up is based on the goals and assists you log after each match.',
          }, style: AppTextStyles.body(size: 12, color: AppColors.textMuted, height: 1.4)),
          if (ready) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: improving
                    ? null
                    : () => context.read<TeamRatingsBloc>().add(const TeamRatingImproveRequested()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onDark,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  improving ? 'Levelling up…' : 'Level up',
                  style: AppTextStyles.title(size: 14, color: AppColors.onDark),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
