import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/mention.dart';
import '../repositories/mention_members_repository.dart';

/// A team's members ([String] is the team id), for @mentions.
class GetMentionMembers implements UseCase<List<MentionMember>, String> {
  const GetMentionMembers(this._repository);

  final MentionMembersRepository _repository;

  @override
  Future<Either<Failure, List<MentionMember>>> call(String teamId) =>
      _repository.getMembers(teamId);
}
