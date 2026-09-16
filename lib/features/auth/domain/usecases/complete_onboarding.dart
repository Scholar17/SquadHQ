import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class CompleteOnboardingParams extends Equatable {
  const CompleteOnboardingParams({
    required this.userId,
    required this.phone,
    required this.username,
  });

  final String userId;
  final String phone;
  final String username;

  @override
  List<Object?> get props => [userId, phone, username];
}

class CompleteOnboarding
    implements UseCase<AppUser, CompleteOnboardingParams> {
  const CompleteOnboarding(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, AppUser>> call(CompleteOnboardingParams params) =>
      _repository.completeOnboarding(
        userId: params.userId,
        phone: params.phone,
        username: params.username,
      );
}
