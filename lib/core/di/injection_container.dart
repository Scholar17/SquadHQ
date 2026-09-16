import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import '../../features/team/data/repositories/mock_team_repository.dart';
import '../../features/team/domain/repositories/team_repository.dart';
import '../../features/team/presentation/bloc/team_bloc.dart';

final sl = GetIt.instance;

/// Registers every dependency for the app. Call once, before [runApp].
Future<void> initDependencies() async {
  // Features - Auth
  sl
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(
        supabaseClient: Supabase.instance.client,
        googleWebClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID']!,
        googleIosClientId: dotenv.env['GOOGLE_IOS_CLIENT_ID']!,
      ),
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
}
