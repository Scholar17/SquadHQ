import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/team_wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_data_source.dart';

class WalletRepositoryImpl implements WalletRepository {
  const WalletRepositoryImpl(this._remoteDataSource);

  final WalletRemoteDataSource _remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(friendlyErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, TeamWallet>> getTeamWallet(String teamId) =>
      _guard(() => _remoteDataSource.getTeamWallet(teamId));

  @override
  Future<Either<Failure, Unit>> setMatchBill({
    required String matchId,
    required double totalCost,
    required SplitMode splitMode,
    required Set<String> memberIds,
  }) =>
      _guard(() async {
        await _remoteDataSource.setMatchBill(
          matchId: matchId,
          totalCost: totalCost,
          splitMode: splitMode,
          memberIds: memberIds,
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> submitPayment({
    required String matchId,
    required Uint8List slipBytes,
    required String fileExtension,
  }) =>
      _guard(() async {
        await _remoteDataSource.submitPayment(
          matchId: matchId,
          slipBytes: slipBytes,
          fileExtension: fileExtension,
        );
        return unit;
      });

  @override
  Future<Either<Failure, String?>> getMyWalletQr() =>
      _guard(_remoteDataSource.getMyWalletQr);

  @override
  Future<Either<Failure, String>> uploadWalletQr({
    required Uint8List bytes,
    required String fileExtension,
  }) =>
      _guard(() => _remoteDataSource.uploadWalletQr(bytes: bytes, fileExtension: fileExtension));

  @override
  Future<Either<Failure, String>> getImageUrl(WalletImageKind kind, String path) =>
      _guard(() => _remoteDataSource.getImageUrl(kind, path));

  @override
  Future<Either<Failure, Uint8List>> downloadImage(WalletImageKind kind, String path) =>
      _guard(() => _remoteDataSource.downloadImage(kind, path));

  @override
  Future<Either<Failure, Unit>> remindUnpaid(String matchId, {Set<String>? profileIds}) =>
      _guard(() async {
        await _remoteDataSource.remindUnpaid(matchId, profileIds: profileIds);
        return unit;
      });
}
