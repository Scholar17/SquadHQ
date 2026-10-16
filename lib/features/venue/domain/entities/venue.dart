import 'package:equatable/equatable.dart';

/// One of a team's saved venues (supabase/sql/052_venues.sql), picked on a
/// new match. Only [name] is required.
class Venue extends Equatable {
  const Venue({
    required this.id,
    required this.teamId,
    required this.name,
    this.mapsUrl,
    this.latitude,
    this.longitude,
    this.photoPath,
    this.photoUrl,
    this.notes,
    this.pricePerHour,
    this.archived = false,
  });

  final String id;
  final String teamId;
  final String name;

  /// A Google Maps link, as pasted.
  final String? mapsUrl;

  /// Where the pitch is, for the weather forecast — typed by an admin, or
  /// read from [mapsUrl].
  final double? latitude;
  final double? longitude;

  /// In the venue-photos bucket, and its public link.
  final String? photoPath;
  final String? photoUrl;

  /// E.g. "Pitch 3 — park behind the 7-Eleven".
  final String? notes;

  /// Information only: it never fills in a bill (extra fees change the
  /// real cost).
  final double? pricePerHour;

  /// Removed from the list; matches at it still show it.
  final bool archived;

  @override
  List<Object?> get props => [
        id,
        teamId,
        name,
        mapsUrl,
        latitude,
        longitude,
        photoPath,
        photoUrl,
        notes,
        pricePerHour,
        archived,
      ];
}
