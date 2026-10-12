import 'package:dartz/dartz.dart';
import 'package:squad_hq/core/error/failures.dart';
import 'package:squad_hq/features/comments/domain/entities/mention.dart';
import 'package:squad_hq/features/comments/domain/repositories/mention_members_repository.dart';

/// Every team has the same three members, with the fake comment
/// repositories' names. Teammates' ids are UUIDs, as a mention marker
/// needs ('<@uuid>').
class FakeMentionMembersRepository implements MentionMembersRepository {
  var members = defaults;

  static const aungKo = '00000000-0000-0000-0000-000000000002';

  static const defaults = [
    MentionMember(id: 'test-1', name: 'Test Player', username: 'tester'),
    MentionMember(id: aungKo, name: 'Aung Ko', username: 'aungko'),
    MentionMember(id: '00000000-0000-0000-0000-000000000003', name: 'Min Thu', username: 'minthu'),
  ];

  void reset() => members = defaults;

  @override
  Future<Either<Failure, List<MentionMember>>> getMembers(String teamId) async => Right(members);
}
