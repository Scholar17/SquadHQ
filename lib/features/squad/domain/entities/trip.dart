import 'package:equatable/equatable.dart';

/// A trip inside a squad (supabase/sql/032_trips.sql): while it's open,
/// the people on it add what they paid; once an admin closes it, they
/// settle up for it — apart from the squad's own balances.
class Trip extends Equatable {
  const Trip({
    required this.id,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.memberIds,
    required this.createdBy,
    this.closedAt,
  });

  final String id;
  final String name;

  /// Calendar days, no time.
  final DateTime startsOn;
  final DateTime endsOn;

  /// Who's going.
  final List<String> memberIds;
  final String createdBy;

  /// When an admin closed it for settling up; null while open.
  final DateTime? closedAt;

  bool get isClosed => closedAt != null;

  bool includes(String profileId) => memberIds.contains(profileId);

  /// Day 1 for [startsOn]; days before and after count on from it.
  int dayOf(DateTime at) {
    final local = at.toLocal();
    return DateTime(local.year, local.month, local.day).difference(startsOn).inDays + 1;
  }

  int get dayCount => endsOn.difference(startsOn).inDays + 1;

  @override
  List<Object?> get props => [id, name, startsOn, endsOn, memberIds, createdBy, closedAt];
}
