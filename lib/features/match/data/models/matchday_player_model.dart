import '../../domain/entities/matchday_player.dart';

RsvpAnswer? rsvpAnswerFromDb(String? value) => switch (value) {
      'yes' => RsvpAnswer.yes,
      'maybe' => RsvpAnswer.maybe,
      'no' => RsvpAnswer.no,
      _ => null,
    };

class MatchdayPlayerModel extends MatchdayPlayer {
  const MatchdayPlayerModel({
    required super.profileId,
    required super.name,
    super.avatarUrl,
    super.answer,
  });

  /// From a `team_members` row with its profile embedded, e.g.
  /// `.select('profile_id, profiles(name, avatar_url)')`, plus that
  /// profile's `match_rsvps.status` (null if they haven't replied).
  factory MatchdayPlayerModel.fromRow(Map<String, dynamic> row, {String? status}) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return MatchdayPlayerModel(
      profileId: row['profile_id'] as String,
      name: (profile?['name'] as String?) ?? 'Unknown player',
      avatarUrl: profile?['avatar_url'] as String?,
      answer: rsvpAnswerFromDb(status),
    );
  }
}
