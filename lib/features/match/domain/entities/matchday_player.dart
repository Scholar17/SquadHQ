import 'package:equatable/equatable.dart';

/// Values match the `rsvp_status` enum in
/// supabase/sql/007_match_rsvps_and_actions.sql.
enum RsvpAnswer { yes, maybe, no }

/// One teammate on a match's squad list — who they are plus their RSVP,
/// or a null [answer] if they haven't replied yet.
class MatchdayPlayer extends Equatable {
  const MatchdayPlayer({
    required this.profileId,
    required this.name,
    this.avatarUrl,
    this.answer,
  });

  final String profileId;
  final String name;
  final String? avatarUrl;
  final RsvpAnswer? answer;

  @override
  List<Object?> get props => [profileId, name, avatarUrl, answer];
}
