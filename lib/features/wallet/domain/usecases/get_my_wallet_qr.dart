import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/wallet_repository.dart';

class GetMyWalletQr implements UseCase<String?, NoParams> {
  const GetMyWalletQr(this._repository);

  final WalletRepository _repository;

  @override
  Future<Either<Failure, String?>> call(NoParams params) => _repository.getMyWalletQr();
}
