import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/wallet_repository.dart';

class RemindUnpaidParams extends Equatable {
  const RemindUnpaidParams({required this.matchId, this.profileIds});

  final String matchId;

  /// Null = everyone still owing.
  final Set<String>? profileIds;

  @override
  List<Object?> get props => [matchId, profileIds];
}

class RemindUnpaid implements UseCase<Unit, RemindUnpaidParams> {
  const RemindUnpaid(this._repository);

  final WalletRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(RemindUnpaidParams params) =>
      _repository.remindUnpaid(params.matchId, profileIds: params.profileIds);
}
