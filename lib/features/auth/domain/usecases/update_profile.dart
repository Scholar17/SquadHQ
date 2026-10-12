import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

/// What to change on your profile; null fields stay as they are.
class UpdateProfileParams extends Equatable {
  const UpdateProfileParams({
    required this.userId,
    this.name,
    this.username,
    this.phone,
    this.avatarBytes,
    this.avatarExtension,
  });

  final String userId;
  final String? name;

  /// Onboarding's rules (OnboardingValidators.usernameError); unique
  /// ignoring case. Old @mentions follow it (049_mentions.sql).
  final String? username;

  /// "+66" and the 9 digits, as onboarding saves it.
  final String? phone;

  /// A new profile photo, already shrunk by the picker.
  final Uint8List? avatarBytes;
  final String? avatarExtension;

  @override
  List<Object?> get props => [userId, name, username, phone, avatarBytes, avatarExtension];
}

class UpdateProfile implements UseCase<AppUser, UpdateProfileParams> {
  const UpdateProfile(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, AppUser>> call(UpdateProfileParams params) =>
      _repository.updateProfile(params);
}
