import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/team_wallet.dart';
import '../repositories/wallet_repository.dart';

class SetMatchBillParams extends Equatable {
  const SetMatchBillParams({
    required this.matchId,
    required this.totalCost,
    required this.splitMode,
    this.memberIds = const {},
  });

  final String matchId;
  final double totalCost;
  final SplitMode splitMode;

  /// Only used for [SplitMode.custom].
  final Set<String> memberIds;

  @override
  List<Object?> get props => [matchId, totalCost, splitMode, memberIds];
}

class SetMatchBill implements UseCase<Unit, SetMatchBillParams> {
  const SetMatchBill(this._repository);

  final WalletRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SetMatchBillParams params) => _repository.setMatchBill(
        matchId: params.matchId,
        totalCost: params.totalCost,
        splitMode: params.splitMode,
        memberIds: params.memberIds,
      );
}
