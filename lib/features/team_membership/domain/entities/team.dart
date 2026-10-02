import 'package:equatable/equatable.dart';

/// - [superAdmin]: the team's creator. Can promote/demote between [admin]
///   and [player], and is the only one who can delete the team. Fixed at
///   creation — never reassigned.
/// - [admin]: promoted by the super admin. Can access team management, but
///   can't change anyone's role and can't delete the team.
/// - [player]: regular member.
enum TeamRole { superAdmin, admin, player }

/// A group's type, chosen once at creation: a football [team] (matches,
/// RSVPs, match bills) or a friends [squad] (shared expenses and settling
/// up). Values match teams.kind in supabase/sql/024_squads.sql.
enum GroupKind { team, squad }

/// A squad's money. Values match teams.currency.
enum GroupCurrency {
  thb('฿', 'Thai baht'),
  mmk('K', 'Myanmar kyat');

  const GroupCurrency(this.symbol, this.label);

  final String symbol;
  final String label;
}

class Team extends Equatable {
  const Team({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.role,
    required this.isActive,
    this.timezone = defaultTimezone,
    this.kind = GroupKind.team,
    this.currency = GroupCurrency.thb,
  });

  final String id;
  final String name;
  final String inviteCode;
  final TeamRole role;

  /// Whether this is the profile's currently active team — the one that
  /// drives the dashboard. Exactly one of a profile's teams is active.
  final bool isActive;

  /// The team's IANA time zone, e.g. "Asia/Bangkok" — decides when "end of
  /// match day" is (Man of the Match voting). Times on screen still show in
  /// each viewer's own phone time.
  final String timezone;

  final GroupKind kind;
  final GroupCurrency currency;

  bool get isSquad => kind == GroupKind.squad;

  static const defaultTimezone = 'Asia/Bangkok';

  @override
  List<Object?> get props => [id, name, inviteCode, role, isActive, timezone, kind, currency];
}
