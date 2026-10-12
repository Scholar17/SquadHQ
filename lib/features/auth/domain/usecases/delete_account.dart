import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

/// Deletes the signed-in account (042): personal details and login gone,
/// shared history kept as "Deleted user"; then signs out here.
class DeleteAccount implements UseCase<Unit, NoParams> {
  const DeleteAccount(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) => _repository.deleteAccount();
}
