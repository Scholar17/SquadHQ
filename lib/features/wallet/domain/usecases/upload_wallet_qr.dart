import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/wallet_repository.dart';

class UploadWalletQrParams extends Equatable {
  const UploadWalletQrParams({required this.bytes, required this.fileExtension});

  final Uint8List bytes;
  final String fileExtension;

  @override
  List<Object?> get props => [bytes, fileExtension];
}

class UploadWalletQr implements UseCase<String, UploadWalletQrParams> {
  const UploadWalletQr(this._repository);

  final WalletRepository _repository;

  @override
  Future<Either<Failure, String>> call(UploadWalletQrParams params) =>
      _repository.uploadWalletQr(bytes: params.bytes, fileExtension: params.fileExtension);
}
