import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/venue.dart';
import '../../domain/maps_link.dart';
import '../../domain/usecases/save_venue.dart';

/// Postgres' code for a unique index refusing a row — on team_venues, a
/// name the team already has (any case).
const _uniqueViolation = '23505';

const _bucket = 'venue-photos';

abstract interface class VenueRemoteDataSource {
  Future<List<Venue>> getTeamVenues(String teamId);

  Future<Venue> getVenue(String venueId);

  Future<Venue> saveVenue(SaveVenueParams params);

  Future<void> archiveVenue(String venueId);
}

class VenueRemoteDataSourceImpl implements VenueRemoteDataSource {
  VenueRemoteDataSourceImpl({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  Venue _venue(Map<String, dynamic> row) {
    final photoPath = row['photo_path'] as String?;
    return Venue(
      id: row['id'] as String,
      teamId: row['team_id'] as String,
      name: row['name'] as String,
      mapsUrl: row['maps_url'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      photoPath: photoPath,
      photoUrl: photoPath == null ? null : _supabase.storage.from(_bucket).getPublicUrl(photoPath),
      notes: row['notes'] as String?,
      pricePerHour: (row['price_per_hour'] as num?)?.toDouble(),
      archived: row['archived'] as bool? ?? false,
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) {
        throw const ServerException(
          'Your team already has a venue with that name — edit that one instead '
          '(tap it on a match, then Edit venue).',
        );
      }
      throw ServerException(e.message);
    } on StorageException catch (e) {
      throw ServerException('Could not upload the photo: ${e.message}');
    }
  }

  @override
  Future<List<Venue>> getTeamVenues(String teamId) => _guard(() async {
        final rows = await _supabase
            .from('team_venues')
            .select()
            .eq('team_id', teamId)
            .eq('archived', false)
            .order('last_used_at', ascending: false, nullsFirst: false)
            .order('name', ascending: true);
        return [for (final row in rows) _venue(row)];
      });

  @override
  Future<Venue> getVenue(String venueId) => _guard(() async {
        final row = await _supabase.from('team_venues').select().eq('id', venueId).single();
        return _venue(row);
      });

  @override
  Future<Venue> saveVenue(SaveVenueParams params) => _guard(() async {
        final bucket = _supabase.storage.from(_bucket);
        String? photoPath = params.removePhoto ? null : params.previousPhotoPath;
        // A fresh file each time, so caches never show the old photo.
        if (params.photoBytes case final bytes?) {
          final extension = params.photoExtension ?? 'jpg';
          photoPath = '${params.teamId}/${DateTime.now().millisecondsSinceEpoch}.$extension';
          await bucket.uploadBinary(
            photoPath,
            bytes,
            fileOptions: FileOptions(
              contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );
        }
        final mapsUri = params.mapsUrl == null ? null : MapsLink.parse(params.mapsUrl!);
        final located = params.latitude != null && params.longitude != null;
        final values = {
          'name': params.name.trim(),
          'maps_url': mapsUri?.toString(),
          'latitude': located ? params.latitude : null,
          'longitude': located ? params.longitude : null,
          'photo_path': photoPath,
          'notes': params.notes,
          'price_per_hour': params.pricePerHour,
        };
        final uploaded = params.photoBytes != null ? photoPath : null;
        final Map<String, dynamic> row;
        try {
          row = params.id == null
              ? await _supabase
                  .from('team_venues')
                  .insert({
                    ...values,
                    'team_id': params.teamId,
                    'created_by': _supabase.auth.currentUser?.id,
                  })
                  .select()
                  .single()
              : await _supabase
                  .from('team_venues')
                  .update(values)
                  .eq('id', params.id!)
                  .select()
                  .single();
        } catch (_) {
          if (uploaded != null) {
            try {
              await bucket.remove([uploaded]);
            } on StorageException catch (_) {}
          }
          rethrow;
        }
        // The old file goes once the venue no longer points at it. Best
        // effort: a leftover file is harmless.
        final previous = params.previousPhotoPath;
        if (previous != null && previous != photoPath) {
          try {
            await bucket.remove([previous]);
          } on StorageException catch (_) {}
        }
        return _venue(row);
      });

  @override
  Future<void> archiveVenue(String venueId) => _guard(() async {
        await _supabase.from('team_venues').update({'archived': true}).eq('id', venueId);
      });
}
