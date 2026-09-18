import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_member.dart';
import '../../domain/repositories/team_membership_repository.dart';
import '../datasources/team_membership_remote_data_source.dart';

class TeamMembershipRepositoryImpl implements TeamMembershipRepository {
  const TeamMembershipRepositoryImpl(this._remoteDataSource);

  final TeamMembershipRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, Team>> createTeam(String name) async {
    try {
      return Right(await _remoteDataSource.createTeam(name));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Team>> joinTeam(String inviteCode) async {
    try {
      return Right(await _remoteDataSource.joinTeam(inviteCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Team>>> getMyTeams() async {
    try {
      return Right(await _remoteDataSource.getMyTeams());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> switchActiveTeam(String teamId) async {
    try {
      await _remoteDataSource.switchActiveTeam(teamId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TeamMember>>> getTeamMembers(String teamId) async {
    try {
      return Right(await _remoteDataSource.getTeamMembers(teamId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setMemberRole({
    required String teamId,
    required String profileId,
    required TeamRole role,
  }) async {
    try {
      await _remoteDataSource.setMemberRole(
        teamId: teamId,
        profileId: profileId,
        role: role,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteTeam(String teamId) async {
    try {
      await _remoteDataSource.deleteTeam(teamId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
