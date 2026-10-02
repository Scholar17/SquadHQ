import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/wallet_repository.dart';

class WalletImageParams extends Equatable {
  const WalletImageParams(this.kind, this.path);

  final WalletImageKind kind;
  final String path;

  @override
  List<Object?> get props => [kind, path];
}

class GetWalletImageUrl implements UseCase<String, WalletImageParams> {
  const GetWalletImageUrl(this._repository);

  final WalletRepository _repository;

  @override
  Future<Either<Failure, String>> call(WalletImageParams params) =>
      _repository.getImageUrl(params.kind, params.path);
}
