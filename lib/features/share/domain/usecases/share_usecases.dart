import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/share_link.dart';
import '../repositories/share_repository.dart';

typedef ShareLinkParams = ({String matchId, ShareKind kind});

/// The link (a full URL) to share a match or its bill.
class GetShareLink implements UseCase<String, ShareLinkParams> {
  const GetShareLink(this._repository);

  final ShareRepository _repository;

  @override
  Future<Either<Failure, String>> call(ShareLinkParams params) =>
      _repository.getShareLink(params.matchId, params.kind);
}

/// Pushes the team that a match or its bill was shared.
class RecordShare implements UseCase<Unit, ShareLinkParams> {
  const RecordShare(this._repository);

  final ShareRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(ShareLinkParams params) =>
      _repository.recordShare(params.matchId, params.kind);
}

/// What an opened link is about ([String] is its token).
class OpenShareLink implements UseCase<OpenedShare?, String> {
  const OpenShareLink(this._repository);

  final ShareRepository _repository;

  @override
  Future<Either<Failure, OpenedShare?>> call(String token) => _repository.openShareLink(token);
}
