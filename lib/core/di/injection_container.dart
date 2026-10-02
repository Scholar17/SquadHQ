import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../realtime/team_changes.dart';
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
import '../../features/match/domain/entities/match.dart';
import '../../features/match/domain/repositories/match_repository.dart';
import '../../features/match/domain/usecases/create_match.dart';
import '../../features/match/domain/usecases/delete_match.dart';
import '../../features/match/domain/usecases/get_match_history.dart';
import '../../features/match/domain/usecases/get_matchday_roster.dart';
import '../../features/match/domain/usecases/get_upcoming_matches.dart';
import '../../features/match/domain/usecases/nudge_match_rsvp.dart';
import '../../features/match/domain/usecases/set_match_rsvp.dart';
import '../../features/match/domain/usecases/set_match_score.dart';
import '../../features/match/domain/usecases/update_match.dart';
import '../../features/match/domain/usecases/vote_motm.dart';
import '../../features/match/presentation/bloc/match_bloc.dart';
import '../../features/match/presentation/bloc/match_history_bloc.dart';
import '../../features/match/presentation/bloc/matchday_bloc.dart';
import '../../features/wallet/data/datasources/wallet_remote_data_source.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../features/wallet/domain/usecases/download_wallet_image.dart';
import '../../features/wallet/domain/usecases/get_my_wallet_qr.dart';
import '../../features/wallet/domain/usecases/get_team_wallet.dart';
import '../../features/wallet/domain/usecases/get_wallet_image_url.dart';
import '../../features/wallet/domain/usecases/remind_unpaid.dart';
import '../../features/wallet/domain/usecases/set_match_bill.dart';
import '../../features/wallet/domain/usecases/submit_bill_payment.dart';
import '../../features/wallet/domain/usecases/upload_wallet_qr.dart';
import '../../features/wallet/presentation/bloc/wallet_bloc.dart';
import '../../features/wallet/presentation/bloc/wallet_qr_bloc.dart';
import '../../features/notifications/data/datasources/notification_remote_data_source.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/domain/usecases/get_notifications.dart';
import '../../features/notifications/domain/usecases/mark_notifications_read.dart';
import '../../features/notifications/domain/usecases/watch_notifications.dart';
import '../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../../features/squad/data/datasources/squad_remote_data_source.dart';
import '../../features/squad/data/repositories/squad_repository_impl.dart';
import '../../features/squad/domain/repositories/squad_repository.dart';
import '../../features/squad/domain/usecases/squad_usecases.dart';
import '../../features/squad/presentation/bloc/expense_comments_bloc.dart';
import '../../features/squad/presentation/bloc/squad_ledger_bloc.dart';
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
import '../../features/team_membership/domain/usecases/set_team_timezone.dart';
import '../../features/team_membership/domain/usecases/switch_active_team.dart';
import '../../features/team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../features/team_membership/presentation/bloc/team_roster_bloc.dart';

final sl = GetIt.instance;

/// Registers every dependency for the app. Call once, before [runApp].
Future<void> initDependencies() async {
  // Core - live updates, one Realtime channel per team shared by the
  // Match, Home and Wallet blocs.
  sl.registerLazySingleton<TeamChanges>(() => SupabaseTeamChanges(Supabase.instance.client));

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
    ..registerLazySingleton(() => SetTeamTimezone(sl()))
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
        setTeamTimezone: sl(),
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
    ..registerLazySingleton(() => UpdateMatch(sl()))
    ..registerLazySingleton(() => DeleteMatch(sl()))
    ..registerLazySingleton(() => NudgeMatchRsvp(sl()))
    ..registerLazySingleton(() => GetMatchdayRoster(sl()))
    ..registerLazySingleton(() => SetMatchRsvp(sl()))
    ..registerLazySingleton(() => GetMatchHistory(sl()))
    ..registerLazySingleton(() => SetMatchScore(sl()))
    ..registerLazySingleton(() => VoteMotm(sl()))
    // Singleton, same reasoning as TeamMembershipBloc: provided once at the
    // app root so Home and the create-match sheet share it.
    ..registerLazySingleton(
      () => MatchBloc(
        getUpcomingMatches: sl(),
        createMatch: sl(),
        updateMatch: sl(),
        deleteMatch: sl(),
        nudgeMatchRsvp: sl(),
        teamChanges: sl(),
      ),
    )
    // Factory with a param (the match) — one fresh instance per match the
    // Match tab shows, like TeamRosterBloc above.
    ..registerFactoryParam<MatchdayBloc, Match, void>(
      (match, _) => MatchdayBloc(
        match: match,
        getMatchdayRoster: sl(),
        setMatchRsvp: sl(),
        teamChanges: sl(),
      ),
    )
    // Singleton, same reasoning as MatchBloc: provided once at the app root
    // so Home's recaps, the tab badges and the history pages share it.
    ..registerLazySingleton(
      () => MatchHistoryBloc(
        getMatchHistory: sl(),
        setMatchScore: sl(),
        voteMotm: sl(),
        teamChanges: sl(),
      ),
    );

  // Features - Squad (friends groups: shared expenses and settling up)
  sl
    ..registerLazySingleton<SquadRemoteDataSource>(
      () => SquadRemoteDataSourceImpl(supabaseClient: Supabase.instance.client),
    )
    ..registerLazySingleton<SquadRepository>(() => SquadRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetSquadLedger(sl()))
    ..registerLazySingleton(() => SaveExpense(sl()))
    ..registerLazySingleton(() => DeleteExpense(sl()))
    ..registerLazySingleton(() => SendSettlement(sl()))
    ..registerLazySingleton(() => RespondSettlement(sl()))
    ..registerLazySingleton(() => GetExpenseComments(sl()))
    ..registerLazySingleton(() => AddExpenseComment(sl()))
    ..registerLazySingleton(() => DeleteExpenseComment(sl()))
    // Factory with params (expense id, squad id) — one per expense screen.
    ..registerFactoryParam<ExpenseCommentsBloc, String, String>(
      (expenseId, teamId) => ExpenseCommentsBloc(
        expenseId: expenseId,
        teamId: teamId,
        getComments: sl(),
        addComment: sl(),
        deleteComment: sl(),
        teamChanges: sl(),
      ),
    )
    ..registerLazySingleton(() => GetMyBankDetails(sl()))
    ..registerLazySingleton(() => SaveMyBankDetails(sl()))
    // Singleton, provided at the app root like WalletBloc: the four squad
    // tabs and the expense, pay and confirm sheets share it.
    ..registerLazySingleton(
      () => SquadLedgerBloc(
        getSquadLedger: sl(),
        saveExpense: sl(),
        deleteExpense: sl(),
        sendSettlement: sl(),
        respondSettlement: sl(),
        teamChanges: sl(),
      ),
    );

  // Features - Notifications (the bell's list of sent pushes)
  sl
    ..registerLazySingleton<NotificationRemoteDataSource>(
      () => NotificationRemoteDataSourceImpl(supabaseClient: Supabase.instance.client),
    )
    ..registerLazySingleton<NotificationRepository>(
      () => NotificationRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetNotifications(sl()))
    ..registerLazySingleton(() => MarkNotificationsRead(sl()))
    ..registerLazySingleton(() => WatchNotifications(sl()))
    // Singleton, provided at the app root: Home's bell and the list share it.
    ..registerLazySingleton(
      () => NotificationBloc(
        getNotifications: sl(),
        markNotificationsRead: sl(),
        watchNotifications: sl(),
      ),
    );

  // Features - Wallet (match bills, split payments, wallet QR codes)
  sl
    ..registerLazySingleton<WalletRemoteDataSource>(
      () => WalletRemoteDataSourceImpl(supabaseClient: Supabase.instance.client),
    )
    ..registerLazySingleton<WalletRepository>(
      () => WalletRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetTeamWallet(sl()))
    ..registerLazySingleton(() => SetMatchBill(sl()))
    ..registerLazySingleton(() => SubmitBillPayment(sl()))
    ..registerLazySingleton(() => GetMyWalletQr(sl()))
    ..registerLazySingleton(() => UploadWalletQr(sl()))
    ..registerLazySingleton(() => GetWalletImageUrl(sl()))
    ..registerLazySingleton(() => DownloadWalletImage(sl()))
    ..registerLazySingleton(() => RemindUnpaid(sl()))
    // Singleton, same reasoning as MatchBloc: provided once at the app root
    // so the Wallet tab, the Match tab and the bill sheets share it.
    ..registerLazySingleton(
      () => WalletBloc(
        getTeamWallet: sl(),
        setMatchBill: sl(),
        submitBillPayment: sl(),
        remindUnpaid: sl(),
        teamChanges: sl(),
      ),
    )
    // Factory — one per ProfilePage visit.
    ..registerFactory(
      () => WalletQrBloc(getMyWalletQr: sl(), uploadWalletQr: sl()),
    );
}
