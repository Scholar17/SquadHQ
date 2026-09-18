import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/complete_onboarding.dart';
import '../../features/auth/domain/usecases/sign_in_with_facebook.dart';
import '../../features/auth/domain/usecases/sign_in_with_google.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/watch_auth_state.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/match/data/datasources/match_remote_data_source.dart';
import '../../features/match/data/repositories/match_repository_impl.dart';
import '../../features/match/domain/repositories/match_repository.dart';
import '../../features/match/domain/usecases/create_match.dart';
import '../../features/match/domain/usecases/get_upcoming_matches.dart';
import '../../features/match/presentation/bloc/match_bloc.dart';
import '../../features/team/data/repositories/mock_team_repository.dart';
import '../../features/team/domain/repositories/team_repository.dart';
import '../../features/team/presentation/bloc/team_bloc.dart';
import '../../features/team_membership/data/datasources/team_membership_remote_data_source.dart';
import '../../features/team_membership/data/repositories/team_membership_repository_impl.dart';
import '../../features/team_membership/domain/repositories/team_membership_repository.dart';
import '../../features/team_membership/domain/usecases/create_team.dart';
import '../../features/team_membership/domain/usecases/delete_team.dart';
import '../../features/team_membership/domain/usecases/get_my_teams.dart';
import '../../features/team_membership/domain/usecases/get_team_members.dart';
import '../../features/team_membership/domain/usecases/join_team.dart';
import '../../features/team_membership/domain/usecases/set_member_role.dart';
import '../../features/team_membership/domain/usecases/switch_active_team.dart';
import '../../features/team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../features/team_membership/presentation/bloc/team_roster_bloc.dart';

final sl = GetIt.instance;

/// Registers every dependency for the app. Call once, before [runApp].
Future<void> initDependencies() async {
  // Features - Auth
  sl
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(supabaseClient: Supabase.instance.client),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => SignInWithFacebook(sl()))
    ..registerLazySingleton(() => SignInWithGoogle(sl()))
    ..registerLazySingleton(() => CompleteOnboarding(sl()))
    ..registerLazySingleton(() => SignOut(sl()))
    ..registerLazySingleton(() => WatchAuthState(sl()))
    ..registerFactory(
      () => AuthBloc(
        signInWithFacebook: sl(),
        signInWithGoogle: sl(),
        completeOnboarding: sl(),
        signOut: sl(),
        watchAuthState: sl(),
      ),
    );

  // Features - Team (Home / Match / Wallet / Squad)
  sl
    ..registerLazySingleton<TeamRepository>(
      () => const MockTeamRepository(),
    )
    ..registerFactory(() => TeamBloc(sl()));

  // Features - Team membership (create/join a real Supabase-backed team)
  sl
    ..registerLazySingleton<TeamMembershipRemoteDataSource>(
      () => TeamMembershipRemoteDataSourceImpl(
        supabaseClient: Supabase.instance.client,
      ),
    )
    ..registerLazySingleton<TeamMembershipRepository>(
      () => TeamMembershipRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => CreateTeam(sl()))
    ..registerLazySingleton(() => JoinTeam(sl()))
    ..registerLazySingleton(() => GetMyTeams(sl()))
    ..registerLazySingleton(() => SwitchActiveTeam(sl()))
    ..registerLazySingleton(() => GetTeamMembers(sl()))
    ..registerLazySingleton(() => SetMemberRole(sl()))
    ..registerLazySingleton(() => DeleteTeam(sl()))
    // Singleton (not a factory, unlike AuthBloc/TeamBloc): provided once at
    // the app root (see app.dart) so every screen — including ones pushed
    // via Navigator, which sit outside AppShellPage's local providers —
    // shares the same team list and active-team state.
    ..registerLazySingleton(
      () => TeamMembershipBloc(
        createTeam: sl(),
        joinTeam: sl(),
        getMyTeams: sl(),
        switchActiveTeam: sl(),
      ),
    )
    // Factory with a param (the team id) — one fresh instance per
    // TeamRosterPage visit, unlike TeamMembershipBloc above.
    ..registerFactoryParam<TeamRosterBloc, String, void>(
      (teamId, _) => TeamRosterBloc(
        teamId: teamId,
        getTeamMembers: sl(),
        setMemberRole: sl(),
        deleteTeam: sl(),
      ),
    );

  // Features - Match (create/view a team's next match)
  sl
    ..registerLazySingleton<MatchRemoteDataSource>(
      () => MatchRemoteDataSourceImpl(supabaseClient: Supabase.instance.client),
    )
    ..registerLazySingleton<MatchRepository>(
      () => MatchRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetUpcomingMatches(sl()))
    ..registerLazySingleton(() => CreateMatch(sl()))
    // Singleton, same reasoning as TeamMembershipBloc: provided once at the
    // app root so Home and the create-match sheet share it.
    ..registerLazySingleton(
      () => MatchBloc(getUpcomingMatches: sl(), createMatch: sl()),
    );
}
