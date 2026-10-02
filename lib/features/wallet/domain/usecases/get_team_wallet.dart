import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/team_wallet.dart';
import '../repositories/wallet_repository.dart';

class GetTeamWallet implements UseCase<TeamWallet, String> {
  const GetTeamWallet(this._repository);

  final WalletRepository _repository;

  @override
  Future<Either<Failure, TeamWallet>> call(String teamId) => _repository.getTeamWallet(teamId);
}
