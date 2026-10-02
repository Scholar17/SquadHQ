import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/matchday_player.dart';

/// A small W / D / L pill.
class ResultBadge extends StatelessWidget {
  const ResultBadge({super.key, required this.result, this.large = false});

  final MatchResult result;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (result) {
      MatchResult.win => ('W', AppColors.accent2_700),
      MatchResult.draw => ('D', AppColors.neutral500),
      MatchResult.loss => ('L', AppColors.accent700),
    };
    return Container(
      width: large ? 30 : 22,
      height: large ? 30 : 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        semanticsLabel: switch (result) {
          MatchResult.win => 'Win',
          MatchResult.draw => 'Draw',
          MatchResult.loss => 'Loss',
        },
        style: AppTextStyles.body(
          size: large ? 14 : 11,
          weight: FontWeight.w900,
          color: AppColors.neutral100,
          height: 1,
        ),
      ),
    );
  }
}

/// A teammate's photo, or their initials when they have none.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player, this.radius = 16});

  final MatchdayPlayer player;
  final double radius;

  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    final initials = words.take(2).map((word) => word[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    final url = player.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.neutral400,
      foregroundImage: url == null ? null : NetworkImage(url),
      onForegroundImageError: url == null ? null : (_, _) {},
      child: Text(
        initialsOf(player.name),
        style: AppTextStyles.body(
          size: radius * 0.72,
          weight: FontWeight.w800,
          color: AppColors.neutral100,
          height: 1,
        ),
      ),
    );
  }
}
