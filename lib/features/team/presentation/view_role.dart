import '../../team_membership/domain/entities/team.dart' as membership;
import '../domain/entities/team_snapshot.dart' show SquadRole;
import 'bloc/team_state.dart';

/// The role a tab renders as. A real player is always [SquadRole.player];
/// super admins and admins default to manager but can flip to the player
/// view via Home's header pill — that toggle lives on the shell's
/// [TeamBloc] so every tab switches along with Home.
SquadRole viewRoleFor(membership.TeamRole role, TeamState teamState) {
  if (role == membership.TeamRole.player) return SquadRole.player;
  return teamState is TeamLoaded ? teamState.role : SquadRole.manager;
}
