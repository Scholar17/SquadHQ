import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/team_snapshot.dart';

abstract interface class TeamRepository {
  Future<Either<Failure, TeamSnapshot>> getTeamSnapshot();
}
