import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/wallet_repository.dart';
import 'get_wallet_image_url.dart';

class DownloadWalletImage implements UseCase<Uint8List, WalletImageParams> {
  const DownloadWalletImage(this._repository);

  final WalletRepository _repository;

  @override
  Future<Either<Failure, Uint8List>> call(WalletImageParams params) =>
      _repository.downloadImage(params.kind, params.path);
}
