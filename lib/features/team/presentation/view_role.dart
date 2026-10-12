import '../../team_membership/domain/entities/team.dart' as membership;
import '../domain/entities/team_snapshot.dart' show SquadRole;

/// The role a tab renders as — fixed by the membership: super admins and
/// admins always get the manager view, players the player view. Admins
/// play too, so the RSVP poll and its reminders work in either view.
SquadRole viewRoleFor(membership.TeamRole role) =>
    role == membership.TeamRole.player ? SquadRole.player : SquadRole.manager;
