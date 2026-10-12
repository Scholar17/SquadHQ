import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/mention.dart';

abstract interface class MentionMembersRepository {
  /// Everyone in [teamId] — who a comment there can @mention.
  Future<Either<Failure, List<MentionMember>>> getMembers(String teamId);
}
