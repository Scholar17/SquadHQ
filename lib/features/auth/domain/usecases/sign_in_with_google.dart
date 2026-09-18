import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle implements UseCase<Unit, NoParams> {
  const SignInWithGoogle(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) =>
      _repository.signInWithGoogle();
}
