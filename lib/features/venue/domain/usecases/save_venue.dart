import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/venue.dart';
import '../repositories/venue_repository.dart';

class SaveVenueParams extends Equatable {
  const SaveVenueParams({
    this.id,
    required this.teamId,
    required this.name,
    this.mapsUrl,
    this.latitude,
    this.longitude,
    this.notes,
    this.pricePerHour,
    this.photoBytes,
    this.photoExtension,
    this.previousPhotoPath,
    this.removePhoto = false,
  });

  /// Null to add a new venue.
  final String? id;
  final String teamId;
  final String name;
  final String? mapsUrl;

  /// Where the pitch is, for the weather forecast — both or neither.
  final double? latitude;
  final double? longitude;
  final String? notes;
  final double? pricePerHour;

  /// A new photo, replacing [previousPhotoPath] if there was one.
  final Uint8List? photoBytes;
  final String? photoExtension;
  final String? previousPhotoPath;

  /// Drop the current photo without a new one.
  final bool removePhoto;

  @override
  List<Object?> get props => [
        id,
        teamId,
        name,
        mapsUrl,
        latitude,
        longitude,
        notes,
        pricePerHour,
        photoBytes,
        photoExtension,
        previousPhotoPath,
        removePhoto,
      ];
}

class SaveVenue implements UseCase<Venue, SaveVenueParams> {
  const SaveVenue(this._repository);

  final VenueRepository _repository;

  @override
  Future<Either<Failure, Venue>> call(SaveVenueParams params) => _repository.saveVenue(params);
}
