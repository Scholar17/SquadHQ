import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/wallet_repository.dart';

class SubmitBillPaymentParams extends Equatable {
  const SubmitBillPaymentParams({
    required this.matchId,
    required this.slipBytes,
    required this.fileExtension,
  });

  final String matchId;
  final Uint8List slipBytes;
  final String fileExtension;

  @override
  List<Object?> get props => [matchId, slipBytes, fileExtension];
}

class SubmitBillPayment implements UseCase<Unit, SubmitBillPaymentParams> {
  const SubmitBillPayment(this._repository);

  final WalletRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(SubmitBillPaymentParams params) =>
      _repository.submitPayment(
        matchId: params.matchId,
        slipBytes: params.slipBytes,
        fileExtension: params.fileExtension,
      );
}
