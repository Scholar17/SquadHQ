import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'package:squad_hq/core/di/injection_container.dart';
import 'package:squad_hq/core/notifications/notification_routing.dart';
import 'package:squad_hq/core/realtime/team_changes.dart';
import 'package:squad_hq/core/routing/app_router.dart';
import 'package:squad_hq/core/theme/app_colors.dart';
import 'package:squad_hq/features/auth/domain/entities/app_user.dart';
import 'package:squad_hq/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:squad_hq/features/auth/presentation/pages/profile_page.dart';
import 'package:squad_hq/features/comments/domain/entities/match_topic.dart';
import 'package:squad_hq/features/comments/domain/entities/mention.dart';
import 'package:squad_hq/features/comments/domain/repositories/match_comments_repository.dart';
import 'package:squad_hq/features/comments/domain/repositories/mention_members_repository.dart';
import 'package:squad_hq/features/player_rating/domain/repositories/player_rating_repository.dart';
import 'package:squad_hq/features/venue/domain/repositories/venue_repository.dart';
import 'package:squad_hq/features/weather/domain/entities/kickoff_forecast.dart';
import 'package:squad_hq/features/weather/domain/repositories/air_quality_repository.dart';
import 'package:squad_hq/features/weather/domain/repositories/forecast_repository.dart';
import 'package:squad_hq/features/weather/presentation/temperature_unit_controller.dart';
import 'package:squad_hq/features/match/domain/entities/match.dart';
import 'package:squad_hq/features/match/domain/entities/match_questions.dart';
import 'package:squad_hq/features/match/domain/entities/matchday_player.dart';
import 'package:squad_hq/features/match/domain/entities/match_history.dart';
import 'package:squad_hq/features/team/presentation/pending_actions.dart';
import 'package:squad_hq/features/match/domain/repositories/match_repository.dart';
import 'package:squad_hq/features/match/presentation/pages/match_history_page.dart';
import 'package:squad_hq/features/match/presentation/pages/match_list_page.dart';
import 'package:squad_hq/features/match/presentation/widgets/match_history_widgets.dart';
import 'package:squad_hq/features/match/presentation/bloc/match_bloc.dart';
import 'package:squad_hq/features/match/presentation/bloc/match_event.dart';
import 'package:squad_hq/features/match/presentation/bloc/match_history_bloc.dart';
import 'package:squad_hq/features/notifications/domain/entities/app_notification.dart';
import 'package:squad_hq/features/team_membership/presentation/bloc/team_membership_event.dart';
import 'package:squad_hq/features/notifications/domain/repositories/notification_repository.dart';
import 'package:squad_hq/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:squad_hq/features/notifications/presentation/pages/notifications_page.dart';
import 'package:squad_hq/features/squad/domain/entities/expense.dart';
import 'package:squad_hq/features/squad/domain/entities/payment_promise.dart';
import 'package:squad_hq/features/squad/domain/repositories/squad_repository.dart';
import 'package:squad_hq/features/squad/presentation/bloc/squad_ledger_bloc.dart';
import 'package:squad_hq/features/squad/presentation/pages/expense_detail_page.dart';
import 'package:squad_hq/features/squad/presentation/pages/settle_with_page.dart';
import 'package:squad_hq/features/squad/presentation/pages/trip_page.dart';
import 'package:squad_hq/features/squad/domain/entities/squad_member.dart' as squad_member;
import 'package:squad_hq/features/squad/domain/entities/trip.dart';
import 'package:squad_hq/features/squad/presentation/pages/expenses_page.dart';
import 'package:squad_hq/features/squad/presentation/pages/settle_page.dart';
import 'package:squad_hq/features/squad/presentation/pages/squad_home_page.dart';
import 'package:squad_hq/features/squad/presentation/pages/squad_members_page.dart';
import 'package:squad_hq/features/team/presentation/bloc/team_bloc.dart';
import 'package:squad_hq/features/team/presentation/bloc/team_event.dart';
import 'package:squad_hq/features/team/presentation/pages/app_shell_page.dart';
import 'package:squad_hq/features/team/presentation/pages/dashboard_page.dart';
import 'package:squad_hq/features/team/presentation/pages/match_page.dart';
import 'package:squad_hq/features/team/presentation/pages/squad_page.dart';
import 'package:squad_hq/features/team/presentation/pages/wallet_page.dart';
import 'package:squad_hq/features/team/presentation/widgets/group_tab.dart';
import 'package:squad_hq/features/team_membership/domain/entities/team.dart';
import 'package:squad_hq/features/team_membership/presentation/pages/team_membership_page.dart';
import 'package:squad_hq/features/team_membership/presentation/bloc/team_membership_bloc.dart';
import 'package:squad_hq/features/team_membership/presentation/bloc/team_membership_state.dart';
import 'package:squad_hq/features/wallet/domain/entities/team_wallet.dart';
import 'package:squad_hq/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:squad_hq/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:squad_hq/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:squad_hq/features/wallet/presentation/pages/wallet_bills_page.dart';
import 'package:squad_hq/features/share/domain/repositories/share_repository.dart';
import 'package:squad_hq/features/invites/domain/entities/group_invite.dart';
import 'package:squad_hq/features/invites/domain/repositories/invite_repository.dart';
import 'package:squad_hq/features/invites/presentation/pages/invitations_page.dart';
import 'package:squad_hq/features/share/domain/entities/share_link.dart';

import 'fake_match_comments_repository.dart';
import 'fake_mention_members_repository.dart';
import 'fake_share_repository.dart';
import 'fake_invite_repository.dart';
import 'fake_notification_repository.dart';
import 'fake_player_rating_repository.dart';
import 'fake_squad_repository.dart';
import 'fake_team_changes.dart';
import 'fake_air_quality_repository.dart';
import 'fake_forecast_repository.dart';
import 'fake_venue_repository.dart';
import 'fake_match_repository.dart';
import 'fake_wallet_repository.dart';
import 'test_helpers.dart';

/// A real [TeamMembershipBloc] started at a fixed [TeamMembershipLoaded],
/// so Home renders without hitting Supabase. No events are ever added.
class _SeededTeamMembershipBloc extends TeamMembershipBloc {
  _SeededTeamMembershipBloc(List<Team> teams)
      : super(
          createTeam: sl(),
          joinTeam: sl(),
          getMyTeams: sl(),
          switchActiveTeam: sl(),
          setTeamTimezone: sl(),
          leaveTeam: sl(),
          removeTeamMember: sl(),
          teamChanges: sl(),
        ) {
    emit(TeamMembershipLoaded(teams));
  }

  /// Switching happens in memory — the real one round-trips to Supabase.
  @override
  void add(TeamMembershipEvent event) {
    final current = state;
    if (event is TeamSwitchRequested && current is TeamMembershipLoaded) {
      emit(
        TeamMembershipLoaded([
          for (final team in current.teams)
            Team(
              id: team.id,
              name: team.name,
              inviteCode: team.inviteCode,
              role: team.role,
              isActive: team.id == event.teamId,
              timezone: team.timezone,
              kind: team.kind,
              currency: team.currency,
            ),
        ]),
      );
      return;
    }
    super.add(event);
  }
}

void main() {
  final fakeMatches = FakeMatchRepository(teamId: 'team-1', userId: 'test-1');
  final fakeWallet = FakeWalletRepository(fakeMatches);
  final fakeNotifications = FakeNotificationRepository();
  final fakeSquad = FakeSquadRepository(userId: 'test-1');
  final fakeMatchComments = FakeMatchCommentsRepository(userId: 'test-1');
  final fakeMentionMembers = FakeMentionMembersRepository();
  final fakeRatings = FakePlayerRatingRepository(userId: 'test-1');
  final fakeVenues = FakeVenueRepository();
  final fakeForecasts = FakeForecastRepository();
  final fakeAir = FakeAirQualityRepository();
  final fakeShares = FakeShareRepository();
  final fakeInvites = FakeInviteRepository();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tz_data.initializeTimeZones();
    await initTestSupabase();
    await initDependencies();
    // Swapped in before any match/wallet use case is first resolved, so
    // they all capture the fakes.
    sl
      ..unregister<MatchRepository>()
      ..registerLazySingleton<MatchRepository>(() => fakeMatches)
      ..unregister<WalletRepository>()
      ..registerLazySingleton<WalletRepository>(() => fakeWallet)
      ..unregister<NotificationRepository>()
      ..registerLazySingleton<NotificationRepository>(() => fakeNotifications)
      ..unregister<SquadRepository>()
      ..registerLazySingleton<SquadRepository>(() => fakeSquad)
      ..unregister<MatchCommentsRepository>()
      ..registerLazySingleton<MatchCommentsRepository>(() => fakeMatchComments)
      ..unregister<MentionMembersRepository>()
      ..registerLazySingleton<MentionMembersRepository>(() => fakeMentionMembers)
      ..unregister<PlayerRatingRepository>()
      ..registerLazySingleton<PlayerRatingRepository>(() => fakeRatings)
      ..unregister<VenueRepository>()
      ..registerLazySingleton<VenueRepository>(() => fakeVenues)
      ..unregister<ForecastRepository>()
      ..registerLazySingleton<ForecastRepository>(() => fakeForecasts)
      ..unregister<AirQualityRepository>()
      ..registerLazySingleton<AirQualityRepository>(() => fakeAir)
      ..unregister<ShareRepository>()
      ..registerLazySingleton<ShareRepository>(() => fakeShares)
      ..unregister<InviteRepository>()
      ..registerLazySingleton<InviteRepository>(() => fakeInvites)
      ..unregister<TeamChanges>()
      ..registerLazySingleton<TeamChanges>(FakeTeamChanges.new);
  });

  setUp(() {
    fakeMatches.reset();
    fakeWallet.reset();
    fakeNotifications.reset();
    fakeSquad.reset();
    fakeMatchComments.reset();
    fakeMentionMembers.reset();
    fakeRatings.reset();
    fakeVenues.reset();
    fakeForecasts.reset();
    fakeAir.reset();
    fakeShares.reset();
    fakeInvites.reset();
  });

  const user = AppUser(
    id: 'test-1',
    name: 'Test Player',
    provider: AuthProvider.google,
    phone: '+66812345678',
    username: 'testplayer',
  );

  Widget teamProvided(Widget child) => BlocProvider(
        create: (_) => sl<TeamBloc>()..add(const TeamStarted()),
        child: child,
      );

  Team activeTeam(TeamRole role) => Team(
        id: 'team-1',
        name: 'Golden Goal FC',
        inviteCode: 'GOLD42',
        role: role,
        isActive: true,
      );

  /// The app-root blocs (see app.dart), seeded with one active team. A
  /// fresh [MatchBloc] and [WalletBloc] each time — the DI ones are
  /// singletons, so their state would leak between tests.
  Widget homeProvided(
    Widget child, {
    TeamRole role = TeamRole.superAdmin,
    List<Team>? teams,
  }) =>
      MultiBlocProvider(
        providers: [
          // At the app root, as in app.dart.
          BlocProvider<AuthBloc>(create: (_) => sl<AuthBloc>()),
          BlocProvider<TeamMembershipBloc>(
            create: (_) => _SeededTeamMembershipBloc(teams ?? [activeTeam(role)]),
          ),
          BlocProvider<SquadLedgerBloc>(
            create: (_) => SquadLedgerBloc(
              getSquadLedger: sl(),
              saveExpense: sl(),
              deleteExpense: sl(),
              sendSettlement: sl(),
              respondSettlement: sl(),
              saveTrip: sl(),
              setTripClosed: sl(),
              saveRecurring: sl(),
              setRecurringPaused: sl(),
              deleteRecurring: sl(),
              promisePayment: sl(),
              recordReceived: sl(),
              confirmPartialPayment: sl(),
              setReminderDay: sl(),
              teamChanges: sl(),
            ),
          ),
          BlocProvider<MatchBloc>(
            create: (_) => MatchBloc(
              getUpcomingMatches: sl(),
              createMatch: sl(),
              updateMatch: sl(),
              deleteMatch: sl(),
              nudgeMatchRsvp: sl(),
              teamChanges: sl(),
            )..add(const MatchTeamSelected('team-1')),
          ),
          BlocProvider<WalletBloc>(
            create: (_) => WalletBloc(
              getTeamWallet: sl(),
              setMatchBill: sl(),
              submitBillPayment: sl(),
              remindUnpaid: sl(),
              teamChanges: sl(),
            )..add(const WalletTeamSelected('team-1')),
          ),
          BlocProvider<NotificationBloc>(
            create: (_) => NotificationBloc(
              getNotifications: sl(),
              markNotificationsRead: sl(),
              watchNotifications: sl(),
            ),
          ),
          BlocProvider<MatchHistoryBloc>(
            create: (_) => MatchHistoryBloc(
              getMatchHistory: sl(),
              saveMatchGame: sl(),
              removeMatchGame: sl(),
              deleteMatch: sl(),
              voteMotm: sl(),
              teamChanges: sl(),
            )..add(const MatchHistoryTeamSelected('team-1')),
          ),
        ],
        child: child,
      );

  /// Pumps [child] with the app-root blocs above [MaterialApp] as in
  /// app.dart — so bottom sheets and dialogs, which get their own
  /// routes, can still reach them.
  Future<void> pumpHome(
    WidgetTester tester,
    Widget child, {
    TeamRole role = TeamRole.superAdmin,
  }) async {
    // A tall, phone-like screen, so the Match tab's poll, bill and squad
    // all fit without scrolling a lazy list.
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      homeProvided(
        MaterialApp(home: teamProvided(child)),
        role: role,
      ),
    );
    // Lets the mock TeamBloc's 300ms load finish, so no timer is left
    // pending when a short test ends.
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The four-tab shell as app_router.dart builds it, minus auth.
  GoRouter shellRouter() => GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellPage(user: user, navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const GroupTab(
                  team: DashboardPage(user: user),
                  squad: SquadHomePage(user: user),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.match,
                builder: (context, state) => const GroupTab(
                  team: MatchPage(user: user),
                  squad: ExpensesPage(user: user),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wallet,
                builder: (context, state) => const GroupTab(
                  team: WalletPage(user: user),
                  squad: SettlePage(user: user),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.squad,
                builder: (context, state) => const GroupTab(
                  team: SquadPage(user: user),
                  squad: SquadMembersPage(user: user),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.matches,
        builder: (context, state) {
          final args = state.extra! as MatchListArgs;
          return MatchListPage(
            activeTeamId: args.activeTeamId,
            teamName: args.teamName,
            userId: args.userId,
            canCreateMatch: args.canCreateMatch,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.upcomingMatch,
        builder: (context, state) => UpcomingMatchPage(args: state.extra! as UpcomingMatchArgs),
      ),
      GoRoute(path: AppRoutes.invitations, builder: (context, state) => const InvitationsPage()),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => NotificationsPage(args: state.extra! as NotificationsArgs),
      ),
      GoRoute(
        path: '/expense/:id',
        builder: (context, state) =>
            ExpenseDetailPage(expenseId: state.pathParameters['id']!, user: user),
      ),
      GoRoute(
        path: '/settle-with/:id',
        builder: (context, state) => SettleWithPage(
          otherId: state.pathParameters['id']!,
          user: user,
          tripId: state.uri.queryParameters['trip'],
        ),
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (context, state) => TripPage(tripId: state.pathParameters['id']!, user: user),
      ),
      GoRoute(
        path: AppRoutes.walletBills,
        builder: (context, state) {
          final args = state.extra! as WalletBillsArgs;
          return WalletBillsPage(userId: args.userId, isManager: args.isManager);
        },
      ),
      GoRoute(
        path: AppRoutes.matchHistory,
        builder: (context, state) => MatchHistoryPage(args: state.extra! as MatchHistoryArgs),
      ),
    ],
  );

  testWidgets('Home shows the active team and its upcoming matches', (tester) async {
    await pumpHome(tester, const DashboardPage(user: user));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Golden Goal FC'), findsOneWidget);
    expect(find.text('Invite code · GOLD42'), findsOneWidget);
    expect(find.text('vs Sundown United'), findsOneWidget);
    // Riverside Rovers kicked off 10 minutes ago: on Home for its scores.
    expect(find.text('AFTER THE MATCH'), findsOneWidget);
    expect(find.text('vs Riverside Rovers'), findsOneWidget);
    expect(find.text('Playing now — fill in the game scores'), findsOneWidget);
  });

  testWidgets('Home always shows an admin the Manager view — no role pill', (tester) async {
    await pumpHome(tester, const DashboardPage(user: user));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('+ New match'), findsOneWidget);
    expect(find.text('Manager'), findsNothing);
    expect(find.text('Player'), findsNothing);
  });

  testWidgets("Home's match rows show the viewer's own RSVP", (tester) async {
    await pumpHome(tester, const DashboardPage(user: user));
    await tester.pumpAndSettle();
    expect(find.text('Vote needed'), findsOneWidget);

    await fakeMatches.setRsvp(matchId: 'match-1', answer: RsvpAnswer.yes);
    tester.element(find.byType(DashboardPage)).read<WalletBloc>().add(const WalletRefreshRequested());
    await tester.pumpAndSettle();
    expect(find.text("You're in ✓"), findsOneWidget);
    expect(find.text('Vote needed'), findsNothing);
  });

  testWidgets('Home shows a player the Player view — no role pill', (tester) async {
    await pumpHome(tester, const DashboardPage(user: user), role: TeamRole.player);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('+ New match'), findsNothing);
    expect(find.text('Manager'), findsNothing);
    expect(find.text('Player'), findsNothing);
  });

  testWidgets('Match tab lets a player RSVP to the next match', (tester) async {
    await pumpHome(tester, const MatchPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();

    expect(find.text('MATCHDAY HUB'), findsOneWidget);
    expect(find.textContaining('Lumpini Park Pitch 2'), findsOneWidget);
    expect(find.text('3 players'), findsOneWidget);
    expect(find.text('Test Player (you)'), findsOneWidget);
    expect(find.text('Edit details'), findsNothing);
    expect(find.text('Cancel match'), findsNothing);

    // Not voted yet: the poll (second, under the match header) shows the
    // options to vote on rather than results.
    expect(find.text('POLL · YOUR VOTE NEEDED'), findsOneWidget);
    expect(find.text('Are you playing vs Sundown United?'), findsOneWidget);
    expect(find.textContaining('Pick an option, then submit'), findsOneWidget);
    expect(find.text('Change vote'), findsNothing);
    expect(find.text('1 of 3 voted'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('POLL · YOUR VOTE NEEDED')).dy,
      greaterThan(tester.getTopLeft(find.text('MATCHDAY HUB')).dy),
    );

    // Picking an option doesn't vote yet — Submit vote does.
    await tester.tap(find.text("I'm in"));
    await tester.pumpAndSettle();
    expect(fakeMatches.answersFor('match-1')['test-1'], isNull);
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();

    // Voted: results (my option ticked) and a Change vote button, still
    // under the match header.
    expect(fakeMatches.answersFor('match-1')['test-1'], RsvpAnswer.yes);
    expect(find.text('POLL · YOUR VOTE NEEDED'), findsNothing);
    expect(find.textContaining('Pick an option, then submit'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Change vote'), findsOneWidget);
    expect(find.text('2 of 3 voted'), findsOneWidget);
    expect(find.text("You voted I'm in — see you Sat!"), findsOneWidget);
    // Percentages are of the whole team (3), not of the 2 votes cast.
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('0%'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Are you playing vs Sundown United?')).dy,
      greaterThan(tester.getTopLeft(find.text('MATCHDAY HUB')).dy),
    );

    // Change vote brings the options back; Cancel returns to the results.
    await tester.tap(find.text('Change vote'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pick an option, then submit'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Change vote'), findsOneWidget);

    await tester.tap(find.text('Change vote'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maybe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();

    expect(fakeMatches.answersFor('match-1')['test-1'], RsvpAnswer.maybe);
    expect(find.text('You voted Maybe'), findsOneWidget);
    expect(find.text('33%'), findsNWidgets(2));
    expect(find.text('Change vote'), findsOneWidget);
  });

  testWidgets('Poll results show two voter photos, then +N for the rest', (tester) async {
    // Aung Ko already said In; three more do too — 4 In voters in all.
    fakeMatches.addVoters(['Kyaw Zin', 'Min Thu', 'Soe Paing'], RsvpAnswer.yes);
    await pumpHome(tester, const MatchPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maybe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();

    // In: 2 photos (initials here — no avatar URLs) + "+2". Maybe: just me.
    expect(find.text('AK'), findsOneWidget);
    expect(find.text('KZ'), findsOneWidget);
    expect(find.text('MT'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('TP'), findsOneWidget);
    // 4 of 6 players In; 1 of 6 Maybe.
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('17%'), findsOneWidget);
  });

  testWidgets('Admins get the same urgent vote prompt as players', (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    // Not voted yet: options + Submit vote, flagged as needed.
    expect(find.text('POLL · YOUR VOTE NEEDED'), findsOneWidget);
    expect(find.text('Submit vote'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Are you playing vs Sundown United?')).dy,
      greaterThan(tester.getTopLeft(find.text('MATCHDAY HUB')).dy),
    );

    await tester.tap(find.text("I'm out"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();

    expect(fakeMatches.answersFor('match-1')['test-1'], RsvpAnswer.no);
    expect(find.text("You voted I'm out"), findsOneWidget);
    expect(find.text('Change vote'), findsOneWidget);
  });

  testWidgets('Match tab shows admins the RSVP summary, edit and cancel', (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    expect(find.text('1 of 3 voted'), findsOneWidget);
    expect(find.text('Edit details'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Cancel match'), 200);
    await tester.tap(find.text('Cancel match'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this match?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel match').last);
    await tester.pumpAndSettle();

    expect(find.text('No upcoming match'), findsOneWidget);
    expect(find.text('+ New match'), findsOneWidget);
  });

  testWidgets('Match tab edit sheet saves new match details', (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit match'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Sundown United'), 'Riverside Rovers');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Edit match'), findsNothing);
    // Both the hub header and the RSVP poll's question pick up the new name.
    expect(find.textContaining('Riverside Rovers', findRichText: true), findsNWidgets(2));
    expect(find.text('Are you playing vs Riverside Rovers?'), findsOneWidget);
  });

  testWidgets('Match tab lets the admin who paid add the total cost and split it',
      (tester) async {
    fakeWallet.myQrPath = 'test-1/qr.png';
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Add total cost'), 200);
    await tester.tap(find.text('Add total cost'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Total cost you paid'), '1000');
    await tester.pump();
    // Default split is "Players who said In" — only Aung Ko has so far.
    expect(find.text('1 player · each pays'), findsOneWidget);

    await tester.tap(find.text('Whole team'));
    await tester.pump();
    expect(find.text('3 players · each pays'), findsOneWidget);
    expect(find.text('฿334'), findsOneWidget);
    expect(find.text('exact ฿333.33'), findsOneWidget);

    await tester.tap(find.text('Save bill'));
    await tester.pumpAndSettle();

    expect(find.text('Save bill'), findsNothing);
    expect(find.text('฿1,000.00 total'), findsOneWidget);
    expect(find.text('Paid by you'), findsOneWidget);
    expect(find.text('0 of 2 paid back'), findsOneWidget);
    // ฿1,000 ÷ 3 → the other two owe ฿334 each; the payer covers ฿332.
    expect(find.text('฿0 paid back + ฿668 owed + ฿332 your share = ฿1,000.00'), findsOneWidget);
    expect(fakeWallet.bills['match-1']?.payerId, 'test-1');
  });

  testWidgets('@mention a teammate: picked from a list, shown by their current username', (
    tester,
  ) async {
    await pumpHome(tester, const MatchPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();
    // A bigger group than fits in the @ list at once.
    fakeMentionMembers.members = [
      ...FakeMentionMembersRepository.defaults,
      for (var i = 10; i < 20; i++)
        MentionMember(
          id: '00000000-0000-0000-0000-0000000000$i',
          name: 'Player $i',
          username: 'player$i',
        ),
    ];
    const matchThread = (matchId: 'match-1', topic: MatchTopic.match);
    await tester.scrollUntilVisible(find.text('Match chat'), 200);
    await tester.tap(find.text('Match chat'));
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('comment-field'));
    // @ alone lists the whole group, scrolling.
    await tester.tap(field);
    await tester.enterText(field, '@');
    await tester.pumpAndSettle();
    final suggestions = find.byKey(const ValueKey('mention-suggestions'));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mention-00000000-0000-0000-0000-000000000019')),
      100,
      scrollable: find.descendant(of: suggestions, matching: find.byType(Scrollable)),
    );
    fakeMentionMembers.reset();

    // Typing @au suggests Aung Ko; picking them fills in their username.
    await tester.enterText(field, 'Bibs @au');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mention-suggestions')), findsOneWidget);
    expect(find.byKey(const ValueKey('mention-test-1')), findsNothing); // not yourself
    // A mouse tap: like a touch on web, a tap outside the field takes its
    // focus — the list counts as inside, so the pick still lands. A frame
    // between press and release, as on a phone.
    final press = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('mention-${FakeMentionMembersRepository.aungKo}'))),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await press.up();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'Bibs @aungko ');
    expect(find.byKey(const ValueKey('mention-suggestions')), findsNothing);

    // Saved by id; shown as @aungko.
    await tester.enterText(field, 'Bibs @aungko please, and @nobody');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(
      fakeMatchComments.inThread(matchThread).single.body,
      'Bibs <@${FakeMentionMembersRepository.aungKo}> please, and @nobody',
    );
    expect(find.text('Bibs @aungko please, and @nobody'), findsOneWidget);

    // Aung Ko renames themselves: the old comment follows.
    fakeMentionMembers.members = [
      for (final member in FakeMentionMembersRepository.defaults)
        member.id == FakeMentionMembersRepository.aungKo
            ? const MentionMember(
                id: FakeMentionMembersRepository.aungKo,
                name: 'Aung Ko',
                username: 'ak10',
              )
            : member,
    ];
    (sl<TeamChanges>() as FakeTeamChanges).push('team-1', TeamTable.matchComments);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Bibs @ak10 please, and @nobody'), findsOneWidget);

    // Renamed again, with no new comment to reload the thread: reopening
    // the chat catches up.
    fakeMentionMembers.members = [
      for (final member in FakeMentionMembersRepository.defaults)
        member.id == FakeMentionMembersRepository.aungKo
            ? const MentionMember(
                id: FakeMentionMembersRepository.aungKo,
                name: 'Aung Ko',
                username: 'ak7',
              )
            : member,
    ];
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 comment'));
    await tester.pumpAndSettle();
    expect(find.text('Bibs @ak7 please, and @nobody'), findsOneWidget);
  });

  testWidgets("A player who voted I'm out can still comment on the match", (tester) async {
    await pumpHome(tester, const MatchPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm out"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();
    expect(find.text("You voted I'm out"), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Match chat'), 200);
    await tester.tap(find.text('Match chat'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('comment-field')), "Can't make it, sorry");
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(
      fakeMatchComments.inThread((matchId: 'match-1', topic: MatchTopic.match)).single.body,
      "Can't make it, sorry",
    );
  });

  testWidgets('Share match copies its link where there is no share sheet', (tester) async {
    await pumpHome(tester, const MatchPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.scrollUntilVisible(find.text('Share match'), 200);
    await tester.tap(find.text('Share match'));
    await tester.pumpAndSettle();
    expect(copied, 'https://squad-hq.web.app/s/match-match-1');
    expect(find.text('Link copied — paste it in Messenger or Facebook'), findsOneWidget);
    // The team hears too (055's push).
    expect(fakeShares.recorded, [('match-1', ShareKind.match)]);
  });

  testWidgets('Share bill is in the Wallet tab, not on the match screens', (tester) async {
    fakeWallet.bills['match-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'p-2',
      payerName: 'Aung Ko',
      payerQrPath: 'p-2/qr.png',
      splitMode: SplitMode.team,
    );
    await pumpHome(tester, const MatchPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.scrollUntilVisible(find.text('Paid by Aung Ko'), 200);
    await tester.tap(find.text('Paid by Aung Ko'));
    await tester.pumpAndSettle();
    expect(find.text('Share bill'), findsNothing);
    // Close the breakdown.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await pumpHome(tester, const WalletPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paid by Aung Ko'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Share bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share bill'));
    await tester.pumpAndSettle();
    expect(copied, 'https://squad-hq.web.app/s/bill-match-1');
  });

  testWidgets('Match chat and bill comments, with replies, live', (tester) async {
    fakeWallet.bills['match-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'p-2',
      payerName: 'Aung Ko',
      payerQrPath: 'p-2/qr.png',
      splitMode: SplitMode.team,
    );
    await pumpHome(tester, const MatchPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();
    const matchThread = (matchId: 'match-1', topic: MatchTopic.match);
    const billThread = (matchId: 'match-1', topic: MatchTopic.bill);

    // The match's thread: a comment.
    await tester.scrollUntilVisible(find.text('Match chat'), 200);
    expect(find.text('Talk about the match with the team'), findsOneWidget);
    await tester.tap(find.text('Match chat'));
    await tester.pumpAndSettle();
    expect(find.text('No comments yet. Sort out lifts, bibs, the ball…'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('comment-field')), 'Who has the bibs?');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Who has the bibs?'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);

    // Aung Ko answers on their phone; it arrives over Realtime.
    fakeMatchComments.commentAs(
      'p-2',
      matchThread,
      'I do!',
      parentId: fakeMatchComments.inThread(matchThread).single.id,
    );
    (sl<TeamChanges>() as FakeTeamChanges).push('team-1', TeamTable.matchComments);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('I do!'), findsOneWidget);
    expect(find.text('COMMENTS · 2'), findsOneWidget);

    // Replying to the reply joins the same thread.
    await tester.tap(find.text('Reply').last);
    await tester.pumpAndSettle();
    expect(find.text('Replying to Aung Ko'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('comment-field')), 'Great, thanks');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    final thread = fakeMatchComments.inThread(matchThread);
    expect(thread.last.parentId, thread.first.id);

    // Back on the Match tab: the count and the latest comment.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('3 comments'), findsOneWidget);
    expect(find.text('You: Great, thanks'), findsOneWidget);

    // The bill has its own thread, on its card.
    await tester.scrollUntilVisible(find.text('Comment on this bill'), -200);
    await tester.tap(find.text('Comment on this bill'));
    await tester.pumpAndSettle();
    expect(find.text('Bill comments'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('comment-field')), 'Drinks included?');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(fakeMatchComments.inThread(billThread).single.body, 'Drinks included?');
    expect(fakeMatchComments.inThread(matchThread), hasLength(3));

    // A player can delete their own comment, not Aung Ko's.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('3 comments'), 200);
    await tester.tap(find.text('3 comments'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNWidgets(2));
  });

  testWidgets('Wallet shows what a player owes the payer and marks it paid', (tester) async {
    fakeWallet.bills['match-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'p-2',
      payerName: 'Aung Ko',
      payerQrPath: 'p-2/qr.png',
      splitMode: SplitMode.team,
    );
    await pumpHome(tester, const WalletPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();

    // Three-way split of ฿900; Aung Ko fronted it, so two ฿300 shares are owed.
    // The team balance, and the "Still owed" line in its breakdown.
    expect(find.text('฿600'), findsNWidgets(2));
    expect(find.text('YOU OWE'), findsOneWidget);
    expect(find.text('vs Sundown United · to Aung Ko'), findsOneWidget);
    expect(find.text('Paid by Aung Ko'), findsOneWidget);

    // The "You owe" card's Pay, and the bill card's own (Wallet tab only).
    expect(find.text('Pay ฿300'), findsOneWidget);
    expect(find.text('You owe ฿300'), findsOneWidget);
    expect(find.text('Pay'), findsOneWidget);
    await tester.tap(find.text('Pay ฿300'));
    await tester.pumpAndSettle();

    expect(find.text('Pay Aung Ko'), findsOneWidget);
    expect(find.text('Save QR'), findsOneWidget);
    expect(find.text("I've paid — upload slip"), findsOneWidget);

    // The image picker can't run in a widget test, so submit the slip the
    // way the upload button does once a picture is chosen.
    final sheet = tester.element(find.text('Pay Aung Ko'));
    sheet.read<WalletBloc>().add(
          WalletPaymentSubmitted(
            matchId: 'match-1',
            slipBytes: Uint8List(0),
            fileExtension: 'jpg',
          ),
        );
    await tester.pumpAndSettle();

    expect(find.text('Paid · slip sent Sun, 4 Oct'), findsOneWidget);
    // On the sheet, and on the bill card behind it.
    expect(find.text('Change slip'), findsNWidgets(2));

    Navigator.of(sheet).pop();
    await tester.pumpAndSettle();

    expect(find.text('YOU OWE'), findsNothing);
    expect(find.text('฿300'), findsWidgets);
    expect(find.text("You've paid"), findsOneWidget);
    expect(find.text('Change slip'), findsOneWidget);

    // A wrong slip: the bill card opens the pay sheet again to change it.
    await tester.tap(find.text('Change slip'));
    await tester.pumpAndSettle();
    expect(find.text('Paid · slip sent Sun, 4 Oct'), findsOneWidget);
    expect(find.text('View slip'), findsOneWidget);
    expect(find.text('Change slip'), findsWidgets);
    // The new slip goes in: the sheet closes and says so.
    tester.element(find.text('Pay Aung Ko')).read<WalletBloc>().add(
          WalletPaymentSubmitted(
            matchId: 'match-1',
            slipBytes: Uint8List(0),
            fileExtension: 'png',
          ),
        );
    await tester.pumpAndSettle();
    expect(find.text('Pay Aung Ko'), findsNothing);
    expect(find.text('Payment slip changed'), findsOneWidget);
    expect(fakeWallet.bills['match-1']!.payments['test-1']!.slipPath, 'match-1/test-1/slip.png');

    // And from the bill's breakdown, on your own row.
    await tester.tap(find.text('Paid by Aung Ko'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.text('Pay Aung Ko'), findsOneWidget);
  });

  testWidgets('An admin payer can edit their bill', (tester) async {
    fakeWallet.bills['match-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'test-1',
      payerName: 'Test Player',
      splitMode: SplitMode.team,
    );
    await pumpHome(tester, const WalletPage(user: user));
    await tester.pumpAndSettle();

    expect(find.text('Paid by you'), findsOneWidget);
    expect(find.text('Edit bill'), findsOneWidget);
  });

  testWidgets("A payer who's only a player can't edit their bill", (tester) async {
    fakeWallet.bills['match-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'test-1',
      payerName: 'Test Player',
      splitMode: SplitMode.team,
    );
    await pumpHome(tester, const WalletPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();

    expect(find.text('Paid by you'), findsOneWidget);
    expect(find.text('Edit bill'), findsNothing);
    expect(find.text('NO TOTAL COST YET'), findsNothing);

    await tester.tap(find.text('Paid by you'));
    await tester.pumpAndSettle();
    expect(find.text('Edit bill'), findsNothing);
  });

  testWidgets("Only the admin who paid a bill gets to edit it", (tester) async {
    fakeWallet.bills['match-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'p-2',
      payerName: 'Aung Ko',
      splitMode: SplitMode.team,
    );
    await pumpHome(tester, const WalletPage(user: user));
    await tester.pumpAndSettle();

    expect(find.text('Paid by Aung Ko'), findsOneWidget);
    expect(find.text('Edit bill'), findsNothing);
  });

  testWidgets("Squad tab tells a new account with no team to create or join one", (tester) async {
    await tester.pumpWidget(
      homeProvided(MaterialApp(home: teamProvided(const SquadPage(user: user))), teams: const []),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're not on a team yet"), findsOneWidget);
    expect(find.text('Create or join a team'), findsOneWidget);
  });

  testWidgets('Squad tab: admins get Invite people and Pending invites', (tester) async {
    await pumpHome(tester, const SquadPage(user: user), role: TeamRole.admin);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pending invites'), 200);
    expect(find.text('Invite people'), findsOneWidget);
  });

  testWidgets("Squad tab: players don't get Invite people or Pending invites", (tester) async {
    await pumpHome(tester, const SquadPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();
    expect(find.text('Invite people'), findsNothing);
    expect(find.text('Pending invites'), findsNothing);
  });

  testWidgets('Squad tab shows the team average and real ratings, and opens a card', (tester) async {
    await pumpHome(tester, const SquadPage(user: user));
    await tester.pumpAndSettle();

    // (74 + 80) / 2, from the two who've rated; Min Thu hasn't.
    expect(find.text('TEAM RATING'), findsOneWidget);
    expect(find.text('77'), findsOneWidget);
    expect(find.text('2 of 3 players rated'), findsOneWidget);
    expect(find.text('Test Player (you)'), findsOneWidget);
    expect(find.text('No rating yet'), findsOneWidget);
    // Rated already: no Fill rating button for me.
    expect(find.text('Fill rating'), findsNothing);

    await tester.tap(find.text('Aung Ko'));
    await tester.pumpAndSettle();

    expect(find.text('Player card'), findsOneWidget);
    expect(find.text('OVR'), findsOneWidget);
    expect(find.text('ST · W'), findsOneWidget);
  });

  testWidgets('Fill rating opens only from your own row on the Squad tab', (tester) async {
    fakeRatings.unrate();
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(homeProvided(MaterialApp.router(routerConfig: shellRouter())));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Unrated, but nothing pops up by itself.
    expect(find.text('Where do you play?'), findsNothing);

    await tester.tap(find.text('Squad'));
    await tester.pumpAndSettle();
    // My row is the only way in — one Fill rating button.
    expect(find.text('No rating yet'), findsNWidgets(2));
    expect(find.text('Fill rating'), findsOneWidget);

    await tester.tap(find.text('Fill rating'));
    await tester.pumpAndSettle();
    expect(find.text('Where do you play?'), findsOneWidget);

    await tester.tap(find.text('Striker'));
    await tester.tap(find.text('Central midfield'));
    await tester.pump();
    expect(find.text('Main: ST · also CM'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // The questions are for the main position.
    expect(find.text('Question 1 for ST'), findsOneWidget);
    await tester.tap(find.text('Answer A1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Answer B2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See my rating'));
    await tester.pumpAndSettle();

    expect(fakeRatings.submitted.single.positions, ['ST', 'CM']);
    expect(fakeRatings.submitted.single.answerIds, ['ST-q1-a', 'ST-q2-b']);
    expect(find.text('Your card is in'), findsOneWidget);
    expect(find.text('71'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Your card is in'), findsNothing);
    // Back on the Squad tab, rated: the button's gone.
    expect(find.text('Fill rating'), findsNothing);
    expect(find.text('ST · CM · 3 apps'), findsOneWidget);
  });

  testWidgets('Your profile shows account details and confirms before logging out',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.squad,
      routes: [
        GoRoute(
          path: AppRoutes.squad,
          builder: (context, state) => homeProvided(const SquadPage(user: user)),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => ProfilePage(user: state.extra! as AppUser),
        ),
      ],
    );
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => sl<AuthBloc>(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Your profile'));
    await tester.pumpAndSettle();

    // At the top, and as the Account section's Name row.
    expect(find.text('Test Player'), findsNWidgets(2));
    expect(find.text('+66812345678'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);

    // Name: a pencil opens it, filled in; empty isn't allowed.
    await tester.tap(find.byTooltip('Edit name'));
    await tester.pumpAndSettle();
    expect(find.text('Your name'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('edit-field')), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Mention name: only under Account, said what it's for; the header
    // just shows it.
    expect(find.text('@testplayer'), findsNWidgets(2));
    expect(find.byTooltip('Edit username'), findsNothing);
    expect(find.text('Teammates type it after @ to mention you in comments'), findsOneWidget);
    await tester.tap(find.text('Mention name'));
    await tester.pumpAndSettle();
    expect(find.text('Mention name'), findsNWidgets(2)); // the row, and the dialog's title
    await tester.enterText(find.byKey(const ValueKey('edit-field')), 'ab');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Mention name must be at least 3 characters.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Phone: tap the row; +66 and the 9 digits, as at sign-up.
    await tester.tap(find.text('+66812345678'));
    await tester.pumpAndSettle();
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('812345678'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('edit-field')), '123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a 9-digit mobile number.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Photo: tap it to change (the camera badge on it).
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    expect(find.text('WALLET QR'), findsOneWidget);
    expect(find.text('Upload QR'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Optional · for squad-mates who pay by transfer'),
      200,
    );
    expect(find.text('BANK DETAILS'), findsOneWidget);
    // No Firebase in tests, so push shows as unavailable.
    await tester.ensureVisible(find.text('NOTIFICATIONS', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('Not available here'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Log out'), 200);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Cancelled: still on the profile, still signed in.
    expect(find.text('Log out?'), findsNothing);
    expect(find.text('Log out'), findsOneWidget);

    // Privacy policy, and Delete account as a menu row: an acknowledgement
    // to tick, Continue, then a last dialog.
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Delete account'), 200);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Deleting your account is permanent'), findsOneWidget);
    FilledButton continueButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    await tester.scrollUntilVisible(find.text('Continue'), 200);
    expect(continueButton().onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('delete-acknowledge')));
    await tester.pump();
    expect(continueButton().onPressed, isNotNull);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsNothing);
  });

  testWidgets('An invitation shows on Home until answered, and opens Invitations', (tester) async {
    fakeInvites.invites.add(
      GroupInvite(
        id: 'inv-1',
        teamId: 'team-9',
        teamName: 'Sunday FC',
        kind: GroupKind.team,
        memberCount: 9,
        invitedByName: 'Aung Ko',
        createdAt: DateTime.now(),
      ),
    );
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(homeProvided(MaterialApp.router(routerConfig: shellRouter())));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text("You're invited to Sunday FC"), findsOneWidget);
    expect(find.text('Aung Ko invited you to join the team.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('invitations-banner')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Invitations'), findsOneWidget);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invitations-banner')), findsNothing);
  });

  testWidgets('The Groups page has no Invitations row when there are none', (tester) async {
    await pumpHome(tester, const TeamMembershipPage());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invitations-row')), findsNothing);
  });

  testWidgets('The Groups page shows Invitations with how many are waiting', (tester) async {
    fakeInvites.invites.addAll([
      for (final i in [1, 2])
        GroupInvite(
          id: 'inv-$i',
          teamId: 'team-$i',
          teamName: 'Group $i',
          kind: GroupKind.squad,
          memberCount: 4,
          invitedByName: 'Aung Ko',
          createdAt: DateTime.now(),
        ),
    ]);
    await pumpHome(tester, const TeamMembershipPage());
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(const ValueKey('invitations-row')), matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('App shell switches between all four tabs', (tester) async {
    final router = shellRouter();
    await tester.pumpWidget(homeProvided(MaterialApp.router(routerConfig: router)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Golden Goal FC'), findsOneWidget);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Bill history'), findsOneWidget);
    // Admins play too: not having voted badges the Match tab for them as well.
    expect(find.text('!'), findsOneWidget);

    await tester.tap(find.text('Squad'));
    await tester.pumpAndSettle();
    expect(find.text('SQUAD · 2026 SEASON'), findsOneWidget);
  });

  testWidgets("Match tab shows a badge until a player RSVPs", (tester) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      homeProvided(MaterialApp.router(routerConfig: shellRouter()), role: TeamRole.player),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('!'), findsOneWidget);

    await tester.tap(find.text('Match').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm in"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();

    expect(find.text('!'), findsNothing);
  });

  /// Pumps the four-tab shell on a tall screen and opens the Match tab.
  Future<void> pumpMatchTab(WidgetTester tester, {TeamRole role = TeamRole.superAdmin}) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      homeProvided(MaterialApp.router(routerConfig: shellRouter()), role: role),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match'));
    await tester.pumpAndSettle();
  }

  testWidgets('New match form has a play time defaulting to 1 hr, with − / +',
      (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();
    expect(find.textContaining('· 1 hr'), findsOneWidget);

    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(find.text('Play time'), findsOneWidget);
    expect(find.widgetWithText(TextField, '1'), findsOneWidget);

    await tester.tap(find.byTooltip('Half an hour more'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '1.5'), findsOneWidget);
    await tester.tap(find.byTooltip('Half an hour more'));
    await tester.tap(find.byTooltip('Half an hour less'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '1.5'), findsOneWidget);

    // Typing works too; out-of-range values block saving.
    await tester.enterText(find.widgetWithText(TextField, '1.5'), '20');
    await tester.pump();
    expect(find.text('Enter between 0.25 and 12 hours'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '20'), '2');
    await tester.pump();

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeMatches.matches.first.durationMinutes, 120);
    expect(find.textContaining('· 2 hr'), findsOneWidget);
  });

  testWidgets('A match picks a saved venue, and its details open from the match', (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    // Typed before saved venues: shown as it was (the form's, over the
    // match page's).
    await tester.tap(find.text('Lumpini Park Pitch 2').last);
    await tester.pumpAndSettle();
    expect(find.text('Polo Football Park'), findsOneWidget);
    await tester.tap(find.text('Arena 5 Rama 9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeMatches.matches.first.venueId, 'v-arena');
    expect(fakeMatches.matches.first.venue, 'Arena 5 Rama 9');
    // Its Google Maps link, straight from the match.
    expect(find.text('Directions'), findsOneWidget);

    // On the match: notes, price and Google Maps, a tap away.
    await tester.tap(find.text('Arena 5 Rama 9'));
    await tester.pumpAndSettle();
    expect(find.text('Pitch 3 — park behind the 7-Eleven'), findsOneWidget);
    expect(find.text('฿1,200 per hour'), findsOneWidget);
    expect(find.text('Open in Google Maps'), findsOneWidget);
  });

  testWidgets('A venue is edited from the picker without picking it', (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lumpini Park Pitch 2').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit Polo Football Park'));
    await tester.pumpAndSettle();
    expect(find.text('Edit venue'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Polo Football Park'), 'Polo Park Pitch 1');
    await tester.pump();
    await tester.tap(find.text('Save changes').last);
    await tester.pumpAndSettle();

    // Back in the picker, renamed, and the match keeps its venue.
    expect(find.text('Polo Park Pitch 1'), findsOneWidget);
    expect(find.byTooltip('Edit Polo Park Pitch 1'), findsOneWidget);
    expect(fakeVenues.venues.firstWhere((venue) => venue.id == 'v-polo').name, 'Polo Park Pitch 1');
  });

  testWidgets('A new venue added from the picker is picked for the match', (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lumpini Park Pitch 2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add new venue'));
    await tester.pumpAndSettle();

    // A name the team has already: refused, with why.
    await tester.enterText(find.widgetWithText(TextField, 'e.g. Arena 5 Rama 9'), 'polo football park');
    await tester.pump();
    await tester.tap(find.text('Save venue'));
    await tester.pumpAndSettle();
    expect(find.text('Your team already has a venue with that name.'), findsOneWidget);

    // Not a Maps link: says how to get one.
    await tester.enterText(find.widgetWithText(TextField, 'polo football park'), 'Kickhub Onnut');
    await tester.enterText(find.widgetWithText(TextField, 'Paste the Share link'), 'kickhub onnut');
    await tester.pump();
    expect(find.textContaining('Paste a Google Maps link'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'kickhub onnut'), 'https://maps.app.goo.gl/kick');
    await tester.pump();
    await tester.tap(find.text('Save venue'));
    await tester.pumpAndSettle();

    // Straight back to the match form, with it picked — in the Venue
    // field, and as a selected recent-venue chip.
    expect(find.text('Kickhub Onnut'), findsNWidgets(2));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(fakeMatches.matches.first.venue, 'Kickhub Onnut');
    expect(fakeVenues.venues.last.mapsUrl, 'https://maps.app.goo.gl/kick');
  });

  /// match-1 at Arena 5 Rama 9 (located), kicking off in two days.
  void arenaMatchSoon() {
    final match = fakeMatches.matches.first;
    fakeMatches.matches.first = Match(
      id: match.id,
      teamId: match.teamId,
      opponent: match.opponent,
      kickoffAt: DateTime.now().add(const Duration(days: 2)),
      venue: 'Arena 5 Rama 9',
      venueId: 'v-arena',
      createdBy: match.createdBy,
    );
  }

  testWidgets('The hub shows kickoff conditions as chips, in °C or °F', (tester) async {
    arenaMatchSoon();
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    expect(find.text('31°C'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('AQI 72'), findsOneWidget);
    expect(find.text('CONDITIONS'), findsNothing);
    expect(fakeForecasts.asked.last.latitude, 13.7563);

    // Each person's own unit, from Profile.
    await sl<TemperatureUnitController>().select(TemperatureUnit.fahrenheit);
    await tester.pump();
    expect(find.text('89°F'), findsOneWidget);
    await sl<TemperatureUnitController>().select(TemperatureUnit.celsius);
    await tester.pump();

    // A tap explains it, crediting Open-Meteo.
    await tester.tap(find.text('31°C'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('At kickoff: 31°C, cloudy, 40% chance of rain.'), findsOneWidget);
    expect(find.textContaining('Weather data: Open-Meteo.com.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 12));
  });

  testWidgets('On a narrow phone the hub countdown shows in full, beside "Edit"', (tester) async {
    arenaMatchSoon();
    await pumpHome(tester, const MatchPage(user: user));
    tester.view.physicalSize = const Size(360, 1600);
    await tester.pumpAndSettle();

    final chip = find.text('IN 2 DAYS');
    expect(chip, findsOneWidget);
    final painted = tester.renderObject<RenderParagraph>(chip);
    expect(painted.didExceedMaxLines, isFalse);
    // The button is shortened to make room.
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Edit details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MATCHDAY HUB is never cut short — "Edit details" becomes "Edit" instead',
      (tester) async {
    arenaMatchSoon();
    await pumpHome(tester, const MatchPage(user: user));
    for (final scale in [1.0, 1.15]) {
      for (final width in [360.0, 375.0, 390.0, 412.0, 430.0, 520.0, 700.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.view.physicalSize = Size(width, 1600);
        await tester.pumpAndSettle();
        final title = tester.renderObject<RenderParagraph>(find.text('MATCHDAY HUB'));
        final chip = tester.renderObject<RenderParagraph>(find.text('IN 2 DAYS'));
        expect(chip.didExceedMaxLines, isFalse, reason: 'chip cut at $width × $scale');
        // The long label only when the title has room for all of it. (The
        // test font's square glyphs are far wider than the app's, so here
        // even "Edit" can leave too little room on the narrowest phones.)
        if (find.text('Edit details').evaluate().isNotEmpty) {
          expect(title.didExceedMaxLines, isFalse, reason: 'title cut at $width × $scale');
        } else {
          expect(find.text('Edit'), findsOneWidget);
        }
      }
    }
    // Wide enough at normal text size: the full label.
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    tester.view.physicalSize = const Size(700, 1600);
    await tester.pumpAndSettle();
    expect(find.text('Edit details'), findsOneWidget);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    expect(tester.takeException(), isNull);
  });

  testWidgets('A sunny kickoff shows the sun and no rain chip', (tester) async {
    arenaMatchSoon();
    fakeForecasts.forecast = const KickoffForecast(temperatureC: 33, weatherCode: 0, rainChance: 10);
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    expect(find.text('33°C'), findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    expect(find.text('10%'), findsNothing);
    expect(find.byIcon(Icons.water_drop_outlined), findsNothing);

    await tester.tap(find.text('33°C'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('At kickoff: 33°C, sunny, 10% chance of rain.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 12));
  });

  testWidgets("The venue's details keep the bigger tiles, closed from the top", (tester) async {
    arenaMatchSoon();
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arena 5 Rama 9'));
    await tester.pumpAndSettle();

    expect(find.text('CONDITIONS'), findsOneWidget);
    expect(find.text('40% rain'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget);
    expect(find.textContaining('Updated '), findsOneWidget);
    expect(find.textContaining('km away'), findsNothing);
    expect(find.textContaining('Open-Meteo.com ·'), findsNothing);

    // The close button sits above everything else in the sheet.
    final close = tester.getTopLeft(find.byTooltip('Close'));
    expect(close.dy, lessThan(tester.getTopLeft(find.text('Pitch 3 — park behind the 7-Eleven')).dy));
    expect(close.dy, lessThan(tester.getTopLeft(find.text('CONDITIONS')).dy));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('CONDITIONS'), findsNothing);
  });

  testWidgets('Unhealthy air is flagged red, with advice a tap away', (tester) async {
    arenaMatchSoon();
    fakeAir.air = fakeAir.reading(usAqi: 162);
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();
    final aqi = find.text('AQI 162');
    expect(tester.widget<Text>(aqi).style?.color, AppColors.alertOnDark);

    await tester.tap(aqi);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Unhealthy (US AQI 162). Consider masks'), findsOneWidget);
    expect(find.textContaining('at Chulalongkorn Hospital station, 1.4 km from the venue'), findsOneWidget);
    expect(find.textContaining('World Air Quality Index Project (waqi.info)'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 12));
  });

  testWidgets('The chips fit a small phone', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    arenaMatchSoon();
    fakeForecasts.forecast = const KickoffForecast(temperatureC: 27, weatherCode: 99, rainChance: 100);
    fakeAir.air = fakeAir.reading(usAqi: 130);
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('AQI 130'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Likely rain turns the rain chip gold', (tester) async {
    arenaMatchSoon();
    fakeForecasts.forecast = const KickoffForecast(temperatureC: 27, weatherCode: 63, rainChance: 70);
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('70%')).style?.color, AppColors.teamGold);
  });

  testWidgets('A kickoff past the 16-day forecast says when the forecast comes', (tester) async {
    // match-1 as it is: years away.
    final match = fakeMatches.matches.first;
    fakeMatches.matches.first = Match(
      id: match.id,
      teamId: match.teamId,
      opponent: match.opponent,
      kickoffAt: match.kickoffAt,
      venue: 'Arena 5 Rama 9',
      venueId: 'v-arena',
      createdBy: match.createdBy,
    );
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();
    expect(find.textContaining('Forecast from'), findsOneWidget);
    expect(fakeForecasts.asked, isEmpty);
  });

  testWidgets('A full Maps link fills the venue location; otherwise the admin types it', (
    tester,
  ) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lumpini Park Pitch 2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add new venue'));
    await tester.pumpAndSettle();
    expect(find.text('LOCATION · FOR WEATHER FORECAST · OPTIONAL'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'e.g. Arena 5 Rama 9'), 'Kickhub Onnut');
    // A share link carries no location: nothing is filled, nothing is fetched.
    await tester.enterText(find.widgetWithText(TextField, 'Paste the Share link'), 'https://maps.app.goo.gl/kick');
    await tester.pump();
    expect(find.textContaining('touch and hold the pitch'), findsOneWidget);

    // A full link carries it: both fields filled on the device.
    await tester.enterText(
      find.widgetWithText(TextField, 'https://maps.app.goo.gl/kick'),
      'https://www.google.com/maps/place/Polo/@13.7303951,100.5504902,17z',
    );
    await tester.pump();
    expect(find.widgetWithText(TextField, '13.730395'), findsOneWidget);
    expect(find.widgetWithText(TextField, '100.55049'), findsOneWidget);

    // Pasted as Google Maps copies them, both at once.
    await tester.enterText(find.widgetWithText(TextField, '13.730395'), '13.75, 100.6');
    await tester.pump();
    expect(find.widgetWithText(TextField, '13.75'), findsOneWidget);
    expect(find.widgetWithText(TextField, '100.6'), findsOneWidget);

    // Half a location doesn't save.
    await tester.enterText(find.widgetWithText(TextField, '100.6'), '');
    await tester.pump();
    expect(find.text('Add the longitude too.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '100.5018'), '100.6');
    await tester.pump();

    await tester.tap(find.text('Save venue'));
    await tester.pumpAndSettle();
    expect(fakeVenues.venues.last.latitude, 13.75);
    expect(fakeVenues.venues.last.longitude, 100.6);
  });

  testWidgets('Match history lists past matches with their Man of the Match', (tester) async {
    await pumpMatchTab(tester);

    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();

    expect(find.text('vs Thai Group'), findsOneWidget);
    expect(find.text('vs Riverside Rovers'), findsOneWidget);
    expect(find.text('SEP 2026'), findsOneWidget);
    // Aung Ko's vote made Min Thu MOTM; no score recorded yet.
    expect(find.text('Min Thu'), findsOneWidget);
    expect(find.text('No score'), findsNWidgets(2));
  });

  testWidgets('Players fill in game scores while the match is on', (tester) async {
    await pumpMatchTab(tester, role: TeamRole.player);
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Riverside Rovers'));
    await tester.pumpAndSettle();

    // Game 1 is there from kickoff, before anyone saves it.
    expect(find.text('Playing now'), findsOneWidget);
    await tester.tap(find.text('Tap to add the score'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Plus one for Golden Goal FC'));
      await tester.pump();
    }
    await tester.tap(find.byTooltip('Plus one for Riverside Rovers'));
    await tester.pump();
    await tester.tap(find.text('Save score'));
    await tester.pumpAndSettle();

    expect(fakeMatches.games['past-live']!.single.scoreLabel, '3–1');
    expect(find.text('3–1'), findsWidgets);
    expect(find.text('by you'), findsOneWidget);

    // Game 2: nobody remembers.
    await tester.tap(find.text('Add game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not sure'));
    await tester.pumpAndSettle();
    expect(fakeMatches.games['past-live']!.last.isNotSure, isTrue);
    expect(find.text('Game 2'), findsOneWidget);
    expect(find.text('3–1 · ?'), findsOneWidget);
  });

  /// A match that finished a minute ago (kicked off 61 minutes ago, 1 hr
  /// play time) — MOTM voting is open until midnight. All three played.
  Match finishedJustNow() {
    final match = Match(
      id: 'recent-1',
      teamId: 'team-1',
      opponent: 'Harbour City',
      kickoffAt: DateTime.now().subtract(const Duration(minutes: 61)),
    );
    fakeMatches.pastMatches.insert(0, match);
    fakeMatches.addPlayed('recent-1', ['test-1', 'p-2', 'p-3']);
    return match;
  }

  testWidgets('Players vote Man of the Match after the match — never for themselves',
      (tester) async {
    finishedJustNow();
    await pumpMatchTab(tester, role: TeamRole.player);
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Harbour City'));
    await tester.pumpAndSettle();

    // Players can't record scores.
    expect(find.text('Add score'), findsNothing);

    // Candidates are whoever played, minus me ("Test Player (you)" is only
    // the Who played chip).
    expect(find.text('Who was the best player?'), findsOneWidget);
    expect(find.text('Test Player'), findsNothing);
    expect(find.text('Test Player (you)'), findsOneWidget);

    // .first: the vote option, above the Who played chip of the same name.
    await tester.tap(find.text('Aung Ko').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();

    expect(fakeMatches.motmVotes['recent-1']?['test-1'], 'p-2');
    // Secret ballot: my vote and the count, but no tallies or winner yet.
    expect(find.textContaining('You voted Aung Ko'), findsOneWidget);
    expect(find.text('1 of 3 voted'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    expect(find.text('Change vote'), findsOneWidget);
  });

  testWidgets('Players rate their game after the match, then vote MOTM', (tester) async {
    finishedJustNow();
    await pumpMatchTab(tester, role: TeamRole.player);
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Harbour City'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    // Prefilled with their main position (CM): Middle.
    expect(find.text('Where did you play most today?'), findsOneWidget);
    await tester.tap(find.text('Middle'));
    await tester.pumpAndSettle();
    expect(find.text('How many goals did you help make?'), findsOneWidget);
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('How many goals did you score?'), findsOneWidget);
    await tester.tap(find.text('Not sure'));
    await tester.pumpAndSettle();
    expect(find.text('How often did you take the ball back?'), findsOneWidget);
    await tester.tap(find.text('A lot'));
    await tester.pumpAndSettle();

    // Question 4: a teammate, never yourself.
    expect(find.text('Who controlled the game best today?'), findsOneWidget);
    expect(find.text('Test Player'), findsNothing);
    await tester.tap(find.text('Aung Ko'));
    await tester.pumpAndSettle();

    final saved = fakeMatches.myAnswers['recent-1']!;
    expect(saved.position, PlayedPosition.midfielder);
    expect(saved.answers, [1, null, 2]);
    expect(saved.pickId, 'p-2');

    // Last step: Man of the Match.
    expect(find.text('Who was Man of the Match?'), findsOneWidget);
    await tester.tap(find.text('Min Thu'));
    await tester.pumpAndSettle();
    expect(fakeMatches.motmVotes['recent-1']?['test-1'], 'p-3');
    expect(find.text('Thanks!'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Rate your game · Done'), findsOneWidget);
  });

  testWidgets("A Maybe player who didn't play says so, and is left out", (tester) async {
    finishedJustNow();
    fakeMatches.answerAs('recent-1', 'test-1', RsvpAnswer.maybe);
    await pumpMatchTab(tester, role: TeamRole.player);
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Harbour City'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Did you play today?'), findsOneWidget);
    await tester.tap(find.text("No, I didn't"));
    await tester.pumpAndSettle();

    expect(fakeMatches.played[('recent-1', 'test-1')], isFalse);
    expect(find.text("This match won't count for you."), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    // No longer in the vote or the questions.
    expect(find.text('Who was the best player?'), findsNothing);
    expect(find.text('Start'), findsNothing);
  });

  testWidgets('An admin cancels a match after it was played, behind a warning', (tester) async {
    await pumpMatchTab(tester);
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Thai Group'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel match'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this match?'), findsOneWidget);
    expect(find.textContaining("This can't be undone."), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel match'));
    await tester.pumpAndSettle();

    expect(fakeMatches.pastMatches.any((match) => match.id == 'past-1'), isFalse);
    expect(find.text('vs Thai Group'), findsNothing);
  });

  testWidgets('Man of the Match is decided once everyone who played has voted',
      (tester) async {
    finishedJustNow();
    fakeMatches.motmVotes['recent-1'] = {'p-2': 'p-3', 'p-3': 'p-2'};
    await pumpMatchTab(tester, role: TeamRole.player);
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Harbour City'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Min Thu').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();

    // 3 of 3 voted: decided — Min Thu 2 votes, no more voting.
    expect(find.text('3 of 3 voted'), findsOneWidget);
    expect(find.text('Min Thu'), findsWidgets);
    expect(find.text('2 of 3 votes'), findsOneWidget);
    expect(find.text('Change vote'), findsNothing);
    expect(find.text('Submit vote'), findsNothing);
  });

  testWidgets('Past its voting deadline, a match with no votes has no Man of the Match',
      (tester) async {
    // Thai Group (13 Sep) is long past midnight; clear its votes.
    fakeMatches.motmVotes.clear();
    await pumpMatchTab(tester, role: TeamRole.player);
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Thai Group'));
    await tester.pumpAndSettle();

    expect(find.text('No Man of the Match — nobody voted.'), findsOneWidget);
    expect(find.text('Who was the best player?'), findsNothing);
  });

  testWidgets("Man of the Match voting stays locked until the match ends", (tester) async {
    await pumpMatchTab(tester, role: TeamRole.player);
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Riverside Rovers'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Voting opens when the match ends'), findsOneWidget);
    expect(find.text('Who was the best player?'), findsNothing);
    expect(find.text('Submit vote'), findsNothing);
  });

  testWidgets('Match tab shows the closest match, with See more for the rest', (tester) async {
    fakeMatches.matches.add(
      Match(
        id: 'match-2',
        teamId: 'team-1',
        opponent: 'Riverside Rovers',
        kickoffAt: DateTime(2037, 10, 17, 19),
      ),
    );
    await pumpMatchTab(tester, role: TeamRole.player);

    // The closest match leads; the other is behind "See more".
    expect(find.text('Are you playing vs Sundown United?'), findsOneWidget);
    expect(find.text('1 more upcoming match'), findsOneWidget);

    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming matches'), findsOneWidget);
    expect(find.text('SAT, 3 OCT'), findsOneWidget);
    expect(find.text('SAT, 17 OCT'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);

    // Open the later match and vote on it from its detail screen.
    await tester.tap(find.text('vs Riverside Rovers'));
    await tester.pumpAndSettle();

    expect(find.text('Are you playing vs Riverside Rovers?'), findsOneWidget);
    expect(find.text('1 more upcoming match'), findsNothing);

    await tester.tap(find.text("I'm out"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();

    expect(fakeMatches.answersFor('match-2')['test-1'], RsvpAnswer.no);
    expect(fakeMatches.answersFor('match-1')['test-1'], isNull);
    expect(find.text("You voted I'm out"), findsOneWidget);
  });

  testWidgets("A teammate's vote shows live on the Match tab and on a match's detail screen",
      (tester) async {
    final changes = sl<TeamChanges>() as FakeTeamChanges;
    fakeMatches.matches.add(
      Match(
        id: 'match-2',
        teamId: 'team-1',
        opponent: 'Riverside Rovers',
        kickoffAt: DateTime(2037, 10, 17, 19),
      ),
    );
    await pumpMatchTab(tester, role: TeamRole.player);

    String votedLabel() => tester.widget<Text>(find.textContaining(' voted')).data!;

    /// A teammate who hasn't voted yet votes on their own phone.
    Future<void> teammateVotes(String matchId) async {
      final before = votedLabel();
      final teammate = fakeMatches.squad
          .firstWhere((p) => p.profileId != 'test-1' && !fakeMatches.answersFor(matchId).containsKey(p.profileId));
      fakeMatches.answerAs(matchId, teammate.profileId, RsvpAnswer.yes);
      changes.push('team-1', TeamTable.matchRsvps);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(votedLabel(), isNot(before), reason: 'poll for $matchId did not update');
    }

    await teammateVotes('match-1');

    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Riverside Rovers'));
    await tester.pumpAndSettle();
    expect(find.text('Are you playing vs Riverside Rovers?'), findsOneWidget);
    await teammateVotes('match-2');
  });

  AppNotification notification(
    String id,
    NotificationKind kind,
    String title, {
    String? matchId = 'match-1',
    bool read = false,
  }) =>
      AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: '',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        matchId: matchId,
        teamId: 'team-1',
        readAt: read ? DateTime.now() : null,
      );

  final unreadDots = find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).color == AppColors.unread,
  );

  Finder bellBadge(String count) => find.descendant(
        of: find.ancestor(
          of: find.byIcon(Icons.notifications_none_rounded),
          matching: find.byType(Stack),
        ).first,
        matching: find.text(count),
      );

  Future<void> openHome(WidgetTester tester) async {
    await pumpMatchTab(tester, role: TeamRole.player);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
  }

  testWidgets("A notification for a match made since the app last loaded still opens it",
      (tester) async {
    await openHome(tester);
    // Another admin schedules it; this phone hasn't heard yet.
    final created = await fakeMatches.createMatch(
      teamId: 'team-1',
      opponent: 'Late Arrivals',
      kickoffAt: DateTime.now().add(const Duration(days: 4)),
      durationMinutes: 60,
    );
    final matchId = created.getOrElse(() => throw StateError('not created')).id;
    fakeNotifications.items.add(
      notification('n-new', NotificationKind.newMatch, 'New match vs Late Arrivals', matchId: matchId),
    );

    NotificationRouting.open('/notifications/n-new');
    await tester.pumpAndSettle();

    expect(find.text('This match is no longer available.'), findsNothing);
    expect(find.text('Are you playing vs Late Arrivals?'), findsOneWidget);
  });

  testWidgets('The bell counts unread notifications, lists them, and Read all clears it',
      (tester) async {
    fakeNotifications.items.addAll([
      notification('n1', NotificationKind.newMatch, 'New match vs Sundown United'),
      notification('n2', NotificationKind.feeDue, 'You owe ฿150'),
      notification('n3', NotificationKind.motmResult, 'Man of the Match: Aung Ko', read: true),
    ]);
    await openHome(tester);
    expect(bellBadge('2'), findsOneWidget);

    // One arriving live bumps the count without a refresh.
    fakeNotifications.arrive(
      notification('n4', NotificationKind.squadReady, 'Squad ready! 10 in for vs Sundown United'),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(bellBadge('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('You owe ฿150'), findsOneWidget);
    expect(find.text('Man of the Match: Aung Ko'), findsOneWidget);
    expect(unreadDots, findsNWidgets(3));

    await tester.tap(find.text('Read all'));
    await tester.pumpAndSettle();
    expect(unreadDots, findsNothing);
    expect(fakeNotifications.items.every((item) => item.isRead), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(bellBadge('3'), findsNothing);
  });

  testWidgets("Tapping a match notification marks it read and opens the match's detail screen",
      (tester) async {
    fakeNotifications.items.addAll([
      notification('n1', NotificationKind.newMatch, 'New match vs Sundown United'),
      notification('n2', NotificationKind.feeDue, 'You owe ฿150'),
    ]);
    await openHome(tester);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New match vs Sundown United'));
    await tester.pumpAndSettle();
    expect(find.text('Are you playing vs Sundown United?'), findsOneWidget);
    expect(fakeNotifications.items.firstWhere((item) => item.id == 'n1').isRead, isTrue);

    // Back on the list, only the other one is still unread.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(unreadDots, findsOneWidget);
  });

  testWidgets("Tapping a push opens its match and marks it read", (tester) async {
    fakeNotifications.items.add(
      notification('n1', NotificationKind.rsvpNudge, 'Are you playing vs Sundown United?'),
    );
    await openHome(tester);

    // What a tapped push hands over (see 023_push_opens_notification.sql).
    NotificationRouting.open('/notifications/n1');
    await tester.pumpAndSettle();

    expect(find.text('Match'), findsWidgets);
    expect(find.text("I'm in"), findsOneWidget);
    expect(fakeNotifications.items.single.isRead, isTrue);
  });

  test('Only /notifications/<id> routes carry a notification id', () {
    expect(NotificationRouting.notificationIdIn('/notifications/abc-123'), 'abc-123');
    expect(NotificationRouting.notificationIdIn('/notifications'), isNull);
    expect(NotificationRouting.notificationIdIn('/notifications/'), isNull);
    expect(NotificationRouting.notificationIdIn('/match'), isNull);
  });

  testWidgets('A shared match link opens the match; one for another team says so', (tester) async {
    await openHome(tester);
    // Shared from another phone (054's share_link).
    await fakeShares.getShareLink('match-1', ShareKind.match);

    NotificationRouting.open('/open/${FakeShareRepository.tokenFor('match-1', ShareKind.match)}');
    await tester.pumpAndSettle();
    expect(find.text('Are you playing vs Sundown United?'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    NotificationRouting.open('/s/not-ours');
    await tester.pumpAndSettle();
    expect(
      find.text("This link is for another team's players, or its match was deleted."),
      findsOneWidget,
    );
  });

  test('Share links carry their token', () {
    expect(NotificationRouting.shareTokenIn('/open/a1b2c3'), 'a1b2c3');
    expect(NotificationRouting.shareTokenIn('/s/a1b2c3'), 'a1b2c3');
    expect(NotificationRouting.shareTokenIn('/s/'), isNull);
    expect(NotificationRouting.shareTokenIn('/match'), isNull);
  });

  testWidgets("Tapping an upcoming match on Home opens its detail screen", (tester) async {
    await openHome(tester);
    await tester.tap(find.text('vs Sundown United').first);
    await tester.pumpAndSettle();
    expect(find.text('Are you playing vs Sundown United?'), findsOneWidget);
  });

  const fridayCrew = Team(
    id: 'squad-1',
    name: 'Friday Crew',
    inviteCode: 'K7Q2XM',
    role: TeamRole.superAdmin,
    isActive: true,
    kind: GroupKind.squad,
  );

  /// The shell with [fridayCrew] as the active group.
  Future<void> pumpSquad(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      homeProvided(
        MaterialApp.router(routerConfig: shellRouter()),
        teams: [
          fridayCrew,
          const Team(
            id: 'team-1',
            name: 'Golden Goal FC',
            inviteCode: 'GOLD42',
            role: TeamRole.player,
            isActive: false,
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets("Home shows a card for another group's unread notifications", (tester) async {
    AppNotification inGroup(String id, String teamId, String title, int hoursAgo, {bool read = false}) =>
        AppNotification(
          id: id,
          kind: NotificationKind.newMatch,
          title: title,
          body: '',
          createdAt: DateTime.now().subtract(Duration(hours: hoursAgo)),
          teamId: teamId,
          readAt: read ? DateTime.now() : null,
        );
    // Newest first, like the inbox.
    fakeNotifications.items.addAll([
      inGroup('n1', 'team-1', 'New match vs Sundown United', 1),
      inGroup('n2', 'squad-1', 'Ko added Hotpot night', 2),
      inGroup('n3', 'team-1', 'Are you playing on Saturday?', 3),
      inGroup('n4', 'team-1', 'Man of the Match: Aung Ko', 4, read: true),
    ]);
    await pumpSquad(tester);

    // Friday Crew is open: only Golden Goal FC's two unread count.
    expect(find.text('IN YOUR OTHER GROUPS'), findsOneWidget);
    expect(find.text('Golden Goal FC'), findsOneWidget);
    expect(find.text('2 new'), findsOneWidget);
    expect(find.text('New match vs Sundown United'), findsOneWidget);
    expect(find.text('Ko added Hotpot night'), findsNothing);

    // All read: the card goes.
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read all'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('IN YOUR OTHER GROUPS'), findsNothing);
  });

  testWidgets('A squad shows the four squad tabs and an empty Home', (tester) async {
    await pumpSquad(tester);

    for (final tab in ['Home', 'Expenses', 'Settle', 'Members']) {
      expect(find.text(tab), findsWidgets);
    }
    expect(find.text('Match'), findsNothing);
    expect(find.text('Friday Crew'), findsOneWidget);
    expect(find.text("You're all square"), findsOneWidget);
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(find.text('Monthly expense'), findsOneWidget);

    await tester.tap(find.text('Members').last);
    await tester.pumpAndSettle();
    expect(find.text('K7Q2XM'), findsOneWidget);
    expect(find.text('3 MEMBERS'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
  });

  testWidgets('The split types explain themselves', (tester) async {
    await pumpSquad(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    expect(find.text('Tap a type to choose how it’s shared'), findsOneWidget);
    expect(find.text('Equal: everyone pays the same.'), findsOneWidget);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Custom: tick who’s in, then type what each pays.'), findsOneWidget);
    expect(find.text('Equal: everyone pays the same.'), findsNothing);
  });

  testWidgets('Exact with no total typed: the total adds up the shares as they are typed',
      (tester) async {
    TextField amountBox() =>
        tester.widget<TextField>(find.byKey(const ValueKey('expense-amount')));
    await pumpSquad(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exact'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the amount, or type each share to add it up.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('share-test-1')), '200');
    await tester.pumpAndSettle();
    expect(amountBox().controller!.text, '200');
    await tester.enterText(find.byKey(const ValueKey('share-aung')), '300');
    await tester.pumpAndSettle();
    expect(amountBox().controller!.text, '500');
    expect(
      find.text('Total added up from the shares: ฿500. Type a total to check against it.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const ValueKey('expense-title')), 'Snacks');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(fakeSquad.expenses.single.amountCents, 50000);
    expect(fakeSquad.expenses.single.shares, {'test-1': 20000, 'aung': 30000});
  });

  testWidgets('A typed total stays put, and shares must add up to it', (tester) async {
    TextField amountBox() =>
        tester.widget<TextField>(find.byKey(const ValueKey('expense-amount')));
    await pumpSquad(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exact'));
    await tester.pumpAndSettle();

    // Typed first: never changed by the shares.
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '600');
    await tester.enterText(find.byKey(const ValueKey('share-test-1')), '200');
    await tester.pumpAndSettle();
    expect(amountBox().controller!.text, '600');
    expect(find.textContaining('Total added up'), findsNothing);
    expect(find.textContaining('Shares must add up to ฿600'), findsOneWidget);

    // Shares over a typed total: it still stays, and says how much over.
    await tester.enterText(find.byKey(const ValueKey('share-aung')), '500');
    await tester.pumpAndSettle();
    expect(amountBox().controller!.text, '600');
    expect(find.text('Shares must add up to ฿600 · ฿700 entered, ฿100 over.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('share-aung')), '');

    // Typed over a filled-in total: also stays.
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '');
    await tester.enterText(find.byKey(const ValueKey('share-aung')), '300');
    await tester.pumpAndSettle();
    expect(amountBox().controller!.text, '500');
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '700');
    await tester.enterText(find.byKey(const ValueKey('share-aung')), '400');
    await tester.pumpAndSettle();
    expect(amountBox().controller!.text, '700');
  });

  testWidgets('Custom: the filled-in total counts only the ticked people', (tester) async {
    TextField amountBox() =>
        tester.widget<TextField>(find.byKey(const ValueKey('expense-amount')));
    await pumpSquad(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('share-test-1')), '200');
    await tester.enterText(find.byKey(const ValueKey('share-aung')), '300');
    await tester.enterText(find.byKey(const ValueKey('share-ko')), '100');
    await tester.pumpAndSettle();
    expect(amountBox().controller!.text, '600');

    // Untick Ko: their ฿100 leaves the total.
    await tester.tap(find.bySemanticsLabel('Include Ko'));
    await tester.pumpAndSettle();
    expect(amountBox().controller!.text, '500');
  });

  testWidgets(
      'Adding ฿1,000 split equally between 3 shows ฿334 (exact ฿333.33) each; the payer covers ฿332',
      (tester) async {
    await pumpSquad(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    // A normal expense: no monthly options.
    expect(find.text('Charged every month'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '1000');
    await tester.pumpAndSettle();
    expect(find.text('฿334'), findsNWidgets(2));
    expect(find.text('exact ฿333.33'), findsNWidgets(2));
    expect(find.text('฿332'), findsOneWidget);
    expect(find.text('covers the rest'), findsOneWidget);

    // A title is required — the category isn't used in its place.
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add a title'), findsOneWidget);
    expect(fakeSquad.expenses, isEmpty);
    // Let the message clear off the Save button.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('expense-title')), 'Friday dinner');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    final saved = fakeSquad.expenses.single;
    expect(saved.payerId, 'test-1');
    expect(saved.shares, {'test-1': 33200, 'aung': 33400, 'ko': 33400});
    // Back on Home: the others owe me ฿668 between them.
    expect(find.text("Overall you're owed"), findsOneWidget);
    expect(find.text('฿668'), findsWidgets);
    // The card shows both the title and the category.
    expect(find.text('Friday dinner'), findsOneWidget);
    expect(find.textContaining('Food · '), findsOneWidget);
    expect(fakeSquad.expenses.single.title, 'Friday dinner');
  });

  testWidgets('Two people paid: each types what they paid, the rest is split', (tester) async {
    await pumpSquad(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '900');
    await tester.pumpAndSettle();

    // Paid by: me and Aung.
    await tester.tap(find.text('You').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Several people paid'));
    await tester.pumpAndSettle();
    expect(find.text('Who paid? · up to 5'), findsOneWidget);
    // The sheet sits on top: its "Aung" is the last one.
    await tester.tap(find.text('Aung').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done · 2 paid'));
    await tester.pumpAndSettle();
    expect(find.text('You + 1'), findsOneWidget);
    expect(find.text('WHO PAID WHAT'), findsOneWidget);

    // The ฿900 I'd typed became my part; the total now follows the boxes.
    expect(find.text('Total of who paid what'), findsOneWidget);
    TextField box(String key) => tester.widget<TextField>(find.byKey(ValueKey(key)));
    expect(box('paid-test-1').controller!.text, '900');
    expect(box('expense-amount').readOnly, isTrue);

    // I paid ฿500, Aung ฿400: the amount fills in as ฿900.
    await tester.enterText(find.byKey(const ValueKey('paid-test-1')), '500');
    await tester.pumpAndSettle();
    expect(box('expense-amount').controller!.text, '500');
    await tester.enterText(find.byKey(const ValueKey('paid-aung')), '400');
    await tester.pumpAndSettle();
    expect(box('expense-amount').controller!.text, '900');
    expect(find.text('Total ฿900 from 2 payers.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('expense-title')), 'Hotpot');
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    final saved = fakeSquad.expenses.single;
    expect(saved.payers, {'test-1': 50000, 'aung': 40000});
    expect(saved.payerId, 'test-1');
    expect(saved.shares, {'test-1': 30000, 'aung': 30000, 'ko': 30000});
    // Ko's ฿300 goes ฿200 to me (I'm ฿200 over) and ฿100 to Aung.
    expect(saved.owed, [
      (fromId: 'ko', toId: 'test-1', cents: 20000),
      (fromId: 'ko', toId: 'aung', cents: 10000),
    ]);
    expect(find.text("Overall you're owed"), findsOneWidget);
  });

  testWidgets('A Settle card says why; tapping it shows how it adds up and the history',
      (tester) async {
    // ฿900 dinner: Aung paid ฿500, Ko ฿400, ฿300 each. I'm ฿300 short;
    // Aung is ฿200 over and Ko ฿100, so I owe Aung ฿200 and Ko ฿100.
    fakeSquad.expenses.add(
      Expense(
        id: 'dinner',
        title: 'Dinner',
        category: ExpenseCategory.food,
        amountCents: 90000,
        spentAt: DateTime(2026, 9, 27, 20),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'aung',
        payers: const {'aung': 50000, 'ko': 40000},
        shares: const {'aung': 30000, 'test-1': 30000, 'ko': 30000},
        createdBy: 'aung',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();

    // The card explains the ฿200, without listing every expense.
    expect(find.text('67% of your ฿300 Dinner share — Aung & Ko paid'), findsOneWidget);
    expect(find.text('33% of your ฿300 Dinner share — Aung & Ko paid'), findsOneWidget);

    await tester.tap(find.text('67% of your ฿300 Dinner share — Aung & Ko paid'));
    await tester.pumpAndSettle();
    expect(find.text('YOU PAY AUNG'), findsOneWidget);
    expect(find.text('Pay ฿200'), findsOneWidget);
    // A short sum: what I owe Aung for, down to the total.
    expect(find.text('HOW IT ADDS UP'), findsOneWidget);
    expect(find.text('You owe Aung for'), findsOneWidget);
    expect(find.text('You pay Aung'), findsOneWidget);
  });

  testWidgets('A trip: people add what they paid, an admin closes it, it settles on its own',
      (tester) async {
    fakeSquad.trips.add(
      Trip(
        id: 'trip-cm',
        name: 'Chiang Mai',
        startsOn: DateTime(2026, 10, 10),
        endsOn: DateTime(2026, 10, 12),
        memberIds: const ['test-1', 'aung', 'ko'],
        createdBy: 'test-1',
      ),
    );
    await pumpSquad(tester);

    // Home's balance card has "Trip expense" (beside "Monthly expense");
    // one open trip goes straight to its sheet.
    expect(find.text('New trip'), findsNothing);
    expect(find.text('Monthly expense'), findsOneWidget);
    await tester.tap(find.text('Trip expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add trip expense'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('TRIPS'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    await tester.tap(find.text('Chiang Mai'));
    await tester.pumpAndSettle();
    expect(find.text('Settling up starts once an admin closes the trip.'), findsOneWidget);

    // A ฿900 dinner I paid, split across the trip.
    await tester.tap(find.text('Add trip expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add trip expense'), findsNWidgets(2));
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '900');
    await tester.enterText(find.byKey(const ValueKey('expense-title')), 'Dinner');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    final saved = fakeSquad.expenses.single;
    expect(saved.tripId, 'trip-cm');
    expect(saved.shares, {'test-1': 30000, 'aung': 30000, 'ko': 30000});
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.textContaining('Food · '), findsOneWidget);

    // Close it: Aung and Ko each owe me ฿300 — for the trip only.
    await tester.tap(find.text('Close trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close trip').last);
    await tester.pumpAndSettle();
    expect(fakeSquad.trips.single.isClosed, isTrue);
    expect(find.text('YOU GET'), findsOneWidget);
    expect(find.text('฿600'), findsWidgets);
    expect(find.text('Aung'), findsWidgets);
    expect(find.text('For Dinner'), findsNWidgets(2));
    expect(find.text('Add trip expense'), findsNothing);

    // The squad's own balances never saw it.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text("You're all square"), findsOneWidget);
    // Closed: as an admin I can still start the next trip from Home.
    expect(find.text('Trip expense'), findsOneWidget);
    expect(find.text('You get ฿600'), findsOneWidget);
  });

  testWidgets('An expense with proof of payment shows it to the squad', (tester) async {
    fakeSquad.expenses.add(
      Expense(
        id: 'dinner',
        title: 'Friday dinner',
        category: ExpenseCategory.food,
        amountCents: 90000,
        spentAt: DateTime(2026, 9, 27, 20),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'aung',
        shares: const {'aung': 30000, 'test-1': 30000, 'ko': 30000},
        createdBy: 'aung',
        receiptPath: 'receipts/squad-1/aung/1.jpg',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Friday dinner'));
    await tester.pumpAndSettle();
    expect(find.text('PROOF OF PAYMENT'), findsOneWidget);
    expect(find.text('Receipt or slip · tap to view'), findsOneWidget);
  });

  testWidgets("A notification from another group switches to it, and says so", (tester) async {
    fakeNotifications.items.addAll([
      AppNotification(
        id: 'n-other',
        kind: NotificationKind.newMatch,
        title: 'New match vs Sundown United',
        body: '',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        teamId: 'team-1',
        matchId: 'match-1',
      ),
      AppNotification(
        id: 'n-left',
        kind: NotificationKind.newMatch,
        title: 'New match vs Old Rivals',
        body: '',
        createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
        teamId: 'team-i-left',
        matchId: 'match-gone',
      ),
    ]);
    // In the Friday Crew squad; Golden Goal FC is the other group.
    await pumpSquad(tester);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New match vs Sundown United'));
    await tester.pumpAndSettle();
    expect(find.text('Switched to Golden Goal FC'), findsOneWidget);
    expect(find.text('Are you playing vs Sundown United?'), findsOneWidget);

    // A group they've left: no match to show, and not called a "match".
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('New match vs Old Rivals'));
    await tester.pumpAndSettle();
    expect(find.text("You're no longer in this group."), findsOneWidget);
  });

  testWidgets("A rating notification filed under an expense squad opens the football Squad tab", (
    tester,
  ) async {
    // From before 050_rating_pushes_football_only.sql: filed under the
    // Friday Crew squad, where ratings mean nothing.
    fakeNotifications.items.add(
      AppNotification(
        id: 'n-rated',
        kind: NotificationKind.playerRated,
        title: 'Aung Ko rated themselves 80 OVR',
        body: 'ST · W',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        teamId: 'squad-1',
      ),
    );
    // In the Friday Crew squad; Golden Goal FC is the football team.
    await pumpSquad(tester);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aung Ko rated themselves 80 OVR'));
    await tester.pumpAndSettle();

    expect(find.text('Switched to Golden Goal FC'), findsOneWidget);
    expect(find.text('TEAM RATING'), findsOneWidget);
  });

  testWidgets("An expense notification opens the expense, even one added since the ledger loaded", (
    tester,
  ) async {
    fakeNotifications.items.addAll([
      AppNotification(
        id: 'n-added',
        kind: NotificationKind.expenseAdded,
        title: 'Aung added Hotpot',
        body: 'Your share: ฿300 of ฿900 in Friday Crew.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        teamId: 'squad-1',
        expenseId: 'hotpot',
      ),
      AppNotification(
        id: 'n-gone',
        kind: NotificationKind.expenseAdded,
        title: 'Aung added Taxi',
        body: '',
        createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
        teamId: 'squad-1',
        expenseId: 'taxi-deleted',
      ),
    ]);
    await pumpSquad(tester);
    // Added on Aung's phone after this ledger loaded, with no live update.
    fakeSquad.expenses.add(
      Expense(
        id: 'hotpot',
        title: 'Hotpot',
        category: ExpenseCategory.food,
        amountCents: 90000,
        spentAt: DateTime(2026, 9, 27, 20),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'aung',
        shares: const {'aung': 30000, 'test-1': 30000, 'ko': 30000},
        createdBy: 'aung',
      ),
    );
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aung added Hotpot'));
    await tester.pumpAndSettle();
    expect(find.text('Hotpot'), findsWidgets);
    expect(find.byKey(const ValueKey('comment-field')), findsOneWidget);

    // Deleted: says so, instead of a spinner that never stops.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aung added Taxi'));
    await tester.pumpAndSettle();
    expect(find.text('This expense was deleted.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('A trip reminder opens the trip, not a missing match', (tester) async {
    fakeSquad.trips.add(
      Trip(
        id: 'trip-pk',
        name: 'Phuket',
        startsOn: DateTime(2026, 11, 1),
        endsOn: DateTime(2026, 11, 3),
        memberIds: const ['test-1', 'aung', 'ko'],
        createdBy: 'aung',
      ),
    );
    fakeNotifications.items.add(
      AppNotification(
        id: 'n-trip-rem',
        kind: NotificationKind.fromDb('trip_reminder'),
        title: 'Aung reminded you to settle up for Phuket',
        body: '',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        teamId: 'squad-1',
        tripId: 'trip-pk',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aung reminded you to settle up for Phuket'));
    await tester.pumpAndSettle();

    expect(find.text('This match is no longer available.'), findsNothing);
    expect(find.text('Phuket'), findsWidgets);
  });

  testWidgets('A "trip closed" notification opens the trip', (tester) async {
    fakeSquad.trips.add(
      Trip(
        id: 'trip-cm',
        name: 'Chiang Mai',
        startsOn: DateTime(2026, 10, 10),
        endsOn: DateTime(2026, 10, 12),
        memberIds: const ['test-1', 'aung', 'ko'],
        createdBy: 'aung',
        closedAt: DateTime(2026, 10, 13),
      ),
    );
    fakeNotifications.items.add(
      AppNotification(
        id: 'n-trip',
        kind: NotificationKind.tripClosed,
        title: 'Chiang Mai is closed — time to settle up',
        body: "You're all square for the trip.",
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        teamId: 'squad-1',
        tripId: 'trip-cm',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('TRIP'), findsOneWidget);

    await tester.tap(find.text('Chiang Mai is closed — time to settle up'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CLOSED · SETTLING UP'), findsOneWidget);
    expect(find.text('Everyone on the trip is settled up.'), findsOneWidget);
  });

  testWidgets('Anyone on a trip can split a trip expense, among the people on it', (tester) async {
    // A regular member, not an admin.
    fakeSquad.members[0] = const squad_member.SquadMember(
      profileId: 'test-1',
      name: 'Test Player',
      role: TeamRole.player,
      walletQrPath: 'test-1/qr.png',
    );
    fakeSquad.trips.add(
      Trip(
        id: 'trip-beach',
        name: 'Beach',
        startsOn: DateTime(2026, 10, 10),
        endsOn: DateTime(2026, 10, 11),
        memberIds: const ['test-1', 'aung'],
        createdBy: 'aung',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Trip expense'));
    await tester.pumpAndSettle();

    // Every split choice, and only Aung and me — Ko isn't going.
    for (final mode in ['Equal', 'Chosen', 'Exact', 'Custom', 'Treat']) {
      expect(find.text(mode), findsOneWidget);
    }
    expect(find.text('Aung'), findsOneWidget);
    expect(find.text('Ko'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '500');
    await tester.tap(find.text('Exact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('share-test-1')), '200');
    await tester.enterText(find.byKey(const ValueKey('share-aung')), '300');
    await tester.enterText(find.byKey(const ValueKey('expense-title')), 'Snacks');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();
    expect(fakeSquad.expenses.single.shares, {'test-1': 20000, 'aung': 30000});
    expect(fakeSquad.expenses.single.tripId, 'trip-beach');
  });

  testWidgets('Remind to pay works person to person — even when you owe more overall',
      (tester) async {
    Expense paid(String id, String payer, Map<String, int> shares) => Expense(
      id: id,
      title: id,
      category: ExpenseCategory.food,
      amountCents: shares.values.fold(0, (a, b) => a + b),
      spentAt: DateTime(2026, 9, 27, 20),
      splitMode: ExpenseSplitMode.exact,
      payerId: payer,
      shares: shares,
      createdBy: payer,
    );
    // Ko owes me ฿300, but I owe Aung ฿500: overall I owe.
    fakeSquad.expenses
      ..add(paid('Taxi', 'test-1', {'ko': 30000}))
      ..add(paid('Hotel', 'aung', {'test-1': 50000}));
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remind').last);
    await tester.pumpAndSettle();
    expect(fakeSquad.reminded, [('test-1', 'ko', null)]);
    expect(find.text('Reminder sent.'), findsOneWidget);
  });

  testWidgets('Trips show in Expenses and Settle; history opens like the Wallet\'s', (tester) async {
    fakeSquad.trips.add(
      Trip(
        id: 'trip-cm',
        name: 'Chiang Mai',
        startsOn: DateTime(2026, 10, 10),
        endsOn: DateTime(2026, 10, 12),
        memberIds: const ['test-1', 'aung', 'ko'],
        createdBy: 'test-1',
        closedAt: DateTime(2026, 10, 13),
      ),
    );
    fakeSquad.expenses.add(
      Expense(
        id: 'raft',
        title: 'Rafting',
        category: ExpenseCategory.tickets,
        amountCents: 90000,
        spentAt: DateTime(2026, 10, 11, 10),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'test-1',
        shares: const {'test-1': 30000, 'aung': 30000, 'ko': 30000},
        createdBy: 'test-1',
        tripId: 'trip-cm',
      ),
    );
    await pumpSquad(tester);

    // Expenses: the squad's first; trips' on the "Trips" tab,
    // each under its trip, with "Add trip expense".
    await tester.tap(find.text('Expenses').last);
    await tester.pumpAndSettle();
    expect(find.text('Rafting'), findsNothing);
    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    expect(find.text('Rafting'), findsOneWidget);
    expect(find.text('Chiang Mai'), findsOneWidget);
    expect(find.text('You get ฿600'), findsOneWidget);
    expect(find.text('Add trip expense'), findsOneWidget);

    // Settle: Squad · Trips; the trip's own card on Trips, and each
    // tab's own payment history.
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();
    expect(find.text('Squad'), findsOneWidget);
    await tester.tap(find.byTooltip('Payment history'));
    await tester.pumpAndSettle();
    expect(find.text('Payment history'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trips').last);
    await tester.pumpAndSettle();
    expect(find.text('You get ฿600'), findsOneWidget);
    await tester.tap(find.byTooltip('Payment history'));
    await tester.pumpAndSettle();
    expect(find.text('Trip payment history'), findsOneWidget);
    expect(find.text('No payments yet.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // On the trip, remind Aung to pay for it.
    await tester.tap(find.text('You get ฿600'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remind').first);
    await tester.pumpAndSettle();
    expect(fakeSquad.reminded, [('test-1', 'aung', 'trip-cm')]);
  });

  testWidgets('A monthly expense charges this month, shows under Monthly, and can be paused',
      (tester) async {
    await pumpSquad(tester);
    await tester.tap(find.text('Expenses').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add monthly expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add monthly expense'), findsNWidgets(2));
    expect(find.text('Charged every month'), findsOneWidget);
    // Its own categories — the service — not everyday ones.
    expect(find.text('Food'), findsNothing);
    expect(find.text('Netflix'), findsOneWidget);
    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();
    // Picking one fills in an empty title.
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('expense-title')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      'YouTube',
    );
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '420');
    await tester.enterText(find.byKey(const ValueKey('expense-title')), 'YouTube Family');
    // Charged on the 1st, so this month's charge is always due already.
    await tester.tap(find.byKey(const ValueKey('charge-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1st').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save monthly expense'));
    await tester.pumpAndSettle();

    // Saved, and — its day having come this month — charged straight away.
    final rec = fakeSquad.recurring.single;
    expect(rec.chargeDay, 1);
    expect(rec.category, ExpenseCategory.youtube);
    expect(rec.shares, {'test-1': 14000, 'aung': 14000, 'ko': 14000});
    final charge = fakeSquad.expenses.single;
    expect(charge.recurringId, rec.id);
    expect(charge.title, startsWith('YouTube Family · '));
    expect(find.text('YouTube Family'), findsOneWidget);
    expect(find.textContaining('next '), findsOneWidget);

    // I pay the provider: remind those who haven't paid this month.
    expect(find.text('Aung & Ko still owe for this month'), findsOneWidget);
    await tester.tap(find.text('Remind to pay'));
    await tester.pumpAndSettle();
    expect(fakeSquad.reminded, [('test-1', 'aung', null), ('test-1', 'ko', null)]);
    expect(find.text('Reminders sent to 2 people.'), findsOneWidget);
    expect(find.text('Reminded'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // The charge is an ordinary squad expense, marked Monthly.
    await tester.tap(find.text('Expenses').at(1));
    await tester.pumpAndSettle();
    expect(find.textContaining('🔁 Monthly'), findsOneWidget);

    // Pause it.
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YouTube Family'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect(fakeSquad.recurring.single.isPaused, isTrue);
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('A You pay card names only the newest expense behind it', (tester) async {
    Expense byAung(String id, String title, DateTime at) => Expense(
      id: id,
      title: title,
      category: ExpenseCategory.other,
      amountCents: 30000,
      spentAt: at,
      splitMode: ExpenseSplitMode.exact,
      payerId: 'aung',
      shares: const {'test-1': 15000, 'aung': 15000},
      createdBy: 'aung',
    );
    fakeSquad.expenses
      ..add(byAung('drinks', 'Drinks', DateTime(2026, 9, 20)))
      ..add(byAung('yt', 'YouTube Family · Oct 2026', DateTime(2026, 10, 1)));
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();

    expect(find.text('For YouTube Family · Oct 2026 and 1 earlier'), findsOneWidget);
    expect(find.textContaining('Drinks'), findsNothing);
  });

  testWidgets('Guests from outside the squad join the split, shown for information', (tester) async {
    await pumpSquad(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '1000');
    await tester.enterText(find.byKey(const ValueKey('expense-title')), 'Dinner');
    await tester.pumpAndSettle();

    // Tom: covered by me (the default).
    await tester.tap(find.text('Add guest'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('guest-name')), 'Tom');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    // Sara: covered by no one — she pays the payer directly.
    await tester.tap(find.text('Add guest'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('guest-name')), 'Sara');
    await tester.tap(find.byKey(const ValueKey('guest-host')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No one — they pay the payer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    // ฿1,000 ÷ 5 = ฿200 each, guests included.
    expect(find.text('Tom (guest)'), findsOneWidget);
    expect(find.text('covered by You'), findsOneWidget);
    expect(find.text('pays the payer directly'), findsOneWidget);
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    // Their shares sit with whoever covers them — here, me both times
    // (I paid) — and they're saved alongside for information.
    final saved = fakeSquad.expenses.single;
    expect(saved.shares, {'test-1': 60000, 'aung': 20000, 'ko': 20000});
    expect(saved.guests, const [
      ExpenseGuest(name: 'Tom', amountCents: 20000, hostId: 'test-1'),
      ExpenseGuest(name: 'Sara', amountCents: 20000),
    ]);

    // The expense page lists them as guests; my own share is ฿200.
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    expect(find.text('Tom · guest'), findsOneWidget);
    expect(find.text('Covered by You'), findsOneWidget);
    expect(find.text('Pays You directly'), findsOneWidget);

    // Editing brings them back as guests; saving unchanged keeps it all.
    await tester.tap(find.byTooltip('Edit expense'));
    await tester.pumpAndSettle();
    expect(find.text('Tom (guest)'), findsOneWidget);
    expect(find.text('Sara (guest)'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(fakeSquad.expenses.single.shares, {'test-1': 60000, 'aung': 20000, 'ko': 20000});
    expect(fakeSquad.expenses.single.guests, hasLength(2));
  });

  testWidgets("A payment someone already sent isn't taken off what you owe them", (tester) async {
    Expense paid(String id, String payer, Map<String, int> shares) => Expense(
      id: id,
      title: id,
      category: ExpenseCategory.other,
      amountCents: shares.values.fold(0, (a, b) => a + b),
      spentAt: DateTime(2026, 9, 27, 20),
      splitMode: ExpenseSplitMode.exact,
      payerId: payer,
      shares: shares,
      createdBy: payer,
    );
    // I owe Aung ฿1,000; Aung owes me ฿25 — and has sent it (pending).
    fakeSquad.expenses
      ..add(paid('Hotel', 'aung', {'test-1': 100000}))
      ..add(paid('Coffee', 'test-1', {'aung': 2500}));
    fakeSquad.receivePayment('aung', 2500);
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();

    // ฿1,000, not ฿975: Aung's ฿25 is already on its way.
    expect(find.text('฿1,000'), findsWidgets);
    expect(find.text('฿975'), findsNothing);
    expect(
      find.textContaining('Includes ฿25 Aung sent you · confirm it in To confirm'),
      findsOneWidget,
    );

    // How it adds up, as a short sum: 1,000 − 25 + 25 = 1,000.
    await tester.tap(find.text('Aung'));
    await tester.pumpAndSettle();
    expect(find.text('You owe Aung for'), findsOneWidget);
    expect(find.text('Aung owes you for'), findsOneWidget);
    expect(find.text('Aung already paid you'), findsOneWidget);
    expect(find.text('฿1,000 − ฿25 + ฿25 = ฿1,000'), findsOneWidget);
    expect(find.text('You pay Aung'), findsOneWidget);
    expect(find.text('Pay ฿1,000'), findsOneWidget);
    // The payments stay folded away until asked for.
    expect(find.text('Pending — counted as paid'), findsNothing);
    await tester.tap(find.text('Aung already paid you'));
    await tester.pumpAndSettle();
    expect(find.text('Pending — counted as paid'), findsOneWidget);
    // And the expenses behind a line.
    await tester.tap(find.text('You owe Aung for'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel'), findsOneWidget);
  });

  testWidgets('Adding an expense asks for your payment QR first', (tester) async {
    fakeSquad.members[0] = const squad_member.SquadMember(
      profileId: 'test-1',
      name: 'Test Player',
      role: TeamRole.superAdmin,
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    expect(find.text('Add your payment QR first'), findsOneWidget);
    expect(find.text('Upload QR'), findsOneWidget);
    // Not now: no expense sheet.
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Add your payment QR first'), findsNothing);
    expect(find.byKey(const ValueKey('expense-amount')), findsNothing);
  });

  testWidgets('Adding a trip expense asks for your payment QR first too', (tester) async {
    fakeSquad.members[0] = const squad_member.SquadMember(
      profileId: 'test-1',
      name: 'Test Player',
      role: TeamRole.superAdmin,
    );
    fakeSquad.trips.add(
      Trip(
        id: 'trip-cm',
        name: 'Chiang Mai',
        startsOn: DateTime(2026, 10, 10),
        endsOn: DateTime(2026, 10, 12),
        memberIds: const ['test-1', 'aung', 'ko'],
        createdBy: 'test-1',
      ),
    );
    await pumpSquad(tester);

    // From Home's "Trip expense"…
    await tester.tap(find.text('Trip expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add your payment QR first'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Add trip expense'), findsNothing);

    // …and from the trip's own page.
    await tester.tap(find.text('Chiang Mai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add trip expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add your payment QR first'), findsOneWidget);
  });

  testWidgets('Starting a trip asks for your payment QR first', (tester) async {
    // An admin with no trip yet and no QR.
    fakeSquad.members[0] = const squad_member.SquadMember(
      profileId: 'test-1',
      name: 'Test Player',
      role: TeamRole.superAdmin,
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Trip expense'));
    await tester.pumpAndSettle();
    expect(find.text('Add your payment QR first'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('New trip'), findsNothing);
  });

  testWidgets('Members with a profile photo show it; the rest show initials', (tester) async {
    fakeSquad.members[2] = const squad_member.SquadMember(
      profileId: 'ko',
      name: 'Ko',
      role: TeamRole.player,
      avatarUrl: 'https://example.com/avatars/ko.jpg',
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Members').last);
    await tester.pumpAndSettle();

    final photos = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is ResizeImage &&
          ((w.image as ResizeImage).imageProvider as NetworkImage).url ==
              'https://example.com/avatars/ko.jpg',
    );
    expect(photos, findsOneWidget);
    // Aung has none: just the initial.
    expect(find.text('A'), findsWidgets);
  });

  testWidgets('Picking Other asks what it is, and cards show that name', (tester) async {
    await pumpSquad(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-label')), findsNothing);
    // Other is last in the row of category chips.
    await tester.drag(find.text('Food'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(find.text('What for? e.g. Gym'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('category-label')),
        matching: find.byType(TextField),
      ),
      'Gym',
    );
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '300');
    await tester.enterText(find.byKey(const ValueKey('expense-title')), 'October pass');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    final saved = fakeSquad.expenses.single;
    expect(saved.category, ExpenseCategory.other);
    expect(saved.categoryLabel, 'Gym');
    // The card says "Gym", not "Other".
    expect(find.textContaining('Gym · '), findsOneWidget);
  });

  testWidgets('How it adds up: 1,000 for breakfast − 500 for dinner = they pay you 500',
      (tester) async {
    Expense paid(String id, String payer, Map<String, int> shares) => Expense(
      id: id,
      title: id,
      category: ExpenseCategory.food,
      amountCents: shares.values.fold(0, (a, b) => a + b),
      spentAt: DateTime(2026, 9, 27, 8),
      splitMode: ExpenseSplitMode.exact,
      payerId: payer,
      shares: shares,
      createdBy: payer,
    );
    // Aung paid ฿500 for my dinner; I paid ฿1,000 for Aung's breakfast.
    fakeSquad.expenses
      ..add(paid('Dinner', 'aung', {'test-1': 50000}))
      ..add(paid('Breakfast', 'test-1', {'aung': 100000}));
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aung'));
    await tester.pumpAndSettle();

    expect(find.text('Aung owes you for'), findsOneWidget);
    expect(find.text('฿1,000'), findsWidgets);
    expect(find.text('You owe Aung for'), findsOneWidget);
    expect(find.text('−฿500'), findsOneWidget);
    expect(find.text('฿1,000 − ฿500 = ฿500'), findsOneWidget);
    expect(find.text('Aung pays you'), findsOneWidget);
  });

  testWidgets('A pending payment that clears every debt still shows, not All square',
      (tester) async {
    fakeSquad.expenses.add(
      Expense(
        id: 'lunch',
        title: 'Lunch',
        category: ExpenseCategory.food,
        amountCents: 60000,
        spentAt: DateTime(2026, 9, 27, 13),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'aung',
        shares: const {'aung': 30000, 'test-1': 30000},
        createdBy: 'aung',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I paid in cash'));
    await tester.pumpAndSettle();

    // Nothing's left once it goes through, but it hasn't yet.
    expect(fakeSquad.settlements.single.isPending, isTrue);
    expect(find.text('All square'), findsNothing);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Remind to confirm'), findsOneWidget);
  });

  testWidgets('A cash payment changes balances only after the receiver confirms it',
      (tester) async {
    fakeSquad.expenses.add(
      Expense(
        id: 'dinner',
        title: 'Friday dinner',
        category: ExpenseCategory.food,
        amountCents: 90000,
        spentAt: DateTime(2026, 9, 27, 20),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'aung',
        shares: const {'aung': 30000, 'test-1': 30000, 'ko': 30000},
        createdBy: 'aung',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();

    expect(find.text('Overall you owe ฿300'), findsOneWidget);
    expect(find.text('฿300'), findsWidgets);

    // One in the hero, one on the debt row.
    expect(find.text('Pay'), findsNWidgets(2));
    await tester.tap(find.text('Pay').first);
    await tester.pumpAndSettle();
    expect(find.text('Pay Aung'), findsOneWidget);
    // Aung has no QR but has bank details, so Bank is picked.
    expect(find.text('123-4-56789'), findsOneWidget);
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I paid in cash'));
    await tester.pumpAndSettle();

    // Sent and waiting: counted as paid, so nothing's left to pay — Aung's
    // card shows what I sent, Pending, with a nudge.
    expect(fakeSquad.settlements.single.isPending, isTrue);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Remind to confirm'), findsOneWidget);
    expect(find.text('฿300 sent · waiting for Aung to confirm'), findsOneWidget);
    expect(find.textContaining("Overall you're even"), findsOneWidget);

    // Aung confirms on their phone; it arrives over Realtime.
    await fakeSquad.respondSettlement(
      settlementId: fakeSquad.settlements.single.id,
      accept: true,
    );
    (sl<TeamChanges>() as FakeTeamChanges).push('squad-1', TeamTable.settlements);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text("Overall you're even"), findsOneWidget);
    expect(find.text('SETTLED'), findsOneWidget);
  });

  testWidgets('Sent back shows only after a reject; sent again, it waits on the You pay card',
      (tester) async {
    fakeSquad.expenses.add(
      Expense(
        id: 'dinner',
        title: 'Friday dinner',
        category: ExpenseCategory.food,
        amountCents: 90000,
        spentAt: DateTime(2026, 9, 27, 20),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'aung',
        shares: const {'aung': 30000, 'test-1': 30000, 'ko': 30000},
        createdBy: 'aung',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();

    Future<void> payCash(Finder button) async {
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I paid in cash'));
      await tester.pumpAndSettle();
    }

    Future<void> aungRejects() async {
      await fakeSquad.respondSettlement(
        settlementId: fakeSquad.settlements.last.id,
        accept: false,
        reason: 'Nothing arrived',
      );
      (sl<TeamChanges>() as FakeTeamChanges).push('squad-1', TeamTable.settlements);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    await payCash(find.text('Pay').first);
    // Just waiting: no Sent back yet.
    expect(find.text('SENT BACK'), findsNothing);
    await aungRejects();
    expect(find.text('SENT BACK'), findsOneWidget);
    expect(find.text('Send again'), findsOneWidget);
    expect(find.text('Remind to confirm'), findsNothing);

    await tester.scrollUntilVisible(find.text('Send again'), 200);
    await payCash(find.text('Send again'));
    // Sent again: Sent back goes; the reminder is on Aung's You pay card.
    expect(find.text('SENT BACK'), findsNothing);
    expect(find.text('Send again'), findsNothing);
    expect(find.text('Remind to confirm'), findsOneWidget);
    expect(find.text('WAITING FOR CONFIRMATION'), findsNothing);

    // Rejected again: still one "Send again", and no reminder.
    await aungRejects();
    expect(find.text('Send again'), findsOneWidget);
    expect(find.text('Remind to confirm'), findsNothing);
  });

  testWidgets('The receiver confirms a payment from the Settle tab', (tester) async {
    fakeSquad.expenses.add(
      Expense(
        id: 'beer',
        title: 'Beer tower',
        category: ExpenseCategory.drinks,
        amountCents: 60000,
        spentAt: DateTime(2026, 9, 27, 22),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'test-1',
        shares: const {'test-1': 20000, 'aung': 20000, 'ko': 20000},
        createdBy: 'test-1',
      ),
    );
    fakeSquad.receivePayment('ko', 20000);
    await pumpSquad(tester);
    // Home flags it too.
    expect(find.text('Ko says they paid you ฿200'), findsOneWidget);

    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();
    expect(find.text('TO CONFIRM'), findsOneWidget);
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(find.text('Ko says they paid you'), findsOneWidget);
    await tester.tap(find.text('Received'));
    await tester.pumpAndSettle();

    expect(fakeSquad.settlements.single.isConfirmed, isTrue);
    expect(find.text('TO CONFIRM'), findsNothing);
    // Aung still owes ฿200; Ko is settled.
    expect(find.text('from Aung'), findsOneWidget);
    expect(find.text('Nothing to pay'), findsOneWidget);
  });

  Expense owedExpense(String id, String payer, Map<String, int> shares) => Expense(
    id: id,
    title: id,
    category: ExpenseCategory.food,
    amountCents: shares.values.fold(0, (a, b) => a + b),
    spentAt: DateTime(2026, 9, 27, 8),
    splitMode: ExpenseSplitMode.exact,
    payerId: payer,
    shares: shares,
    createdBy: payer,
  );

  testWidgets('Pay part: Full, Half or Custom, and what is left shows', (tester) async {
    fakeSquad.expenses.add(owedExpense('Dinner', 'aung', {'test-1': 100000}));
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay ฿1,000'));
    await tester.pumpAndSettle();

    expect(find.text('Full'), findsOneWidget);
    await tester.tap(find.text('Half · ฿500'));
    await tester.pump();
    expect(find.text('You owe ฿1,000 · ฿500 left after this'), findsOneWidget);
    await tester.tap(find.text('Cash'));
    await tester.pump();
    await tester.tap(find.text('I paid in cash'));
    await tester.pumpAndSettle();
    expect(fakeSquad.settlements.single.amountCents, 50000);

    // What's left, and what's been paid toward it.
    expect(find.textContaining('Paid ฿500 of ฿1,000 so far'), findsWidgets);
  });

  testWidgets('A partial payment is flagged to the receiver before they confirm it',
      (tester) async {
    fakeSquad.expenses.add(owedExpense('Dinner', 'test-1', {'aung': 100000}));
    fakeSquad.receivePayment('aung', 40000);
    await pumpSquad(tester);
    // Home says so — with a red dot: it needs checking.
    expect(find.text('Aung says they paid you ฿400 · part of ฿1,000'), findsOneWidget);
    expect(find.text('NEEDS YOUR CHECK'), findsOneWidget);
    expect(find.byKey(const ValueKey('check-dot')), findsOneWidget);

    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();
    expect(find.text('Aung paid you ฿400 · partial'), findsOneWidget);
    expect(find.textContaining('Part of ฿1,000 · ฿600 left after'), findsOneWidget);

    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(find.text('PARTIAL PAYMENT TO CONFIRM'), findsOneWidget);
    expect(
      find.text(
        'This is a partial payment: ฿400 of the ฿1,000 Aung owes you. '
        'After you confirm, they still owe ฿600.',
      ),
      findsOneWidget,
    );
    expect(find.text('฿400 of ฿1,000'), findsOneWidget);

    await tester.tap(find.text('Received'));
    await tester.pumpAndSettle();
    expect(fakeSquad.settlements.single.isConfirmed, isTrue);
    expect(find.text('Partial payment confirmed. Aung still owes you ฿600.'), findsOneWidget);
  });

  testWidgets('The receiver confirms only the part that arrived', (tester) async {
    fakeSquad.expenses.add(owedExpense('Dinner', 'test-1', {'ko': 100000}));
    fakeSquad.receivePayment('ko', 100000);
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I got a different amount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('received-amount')), '500');
    await tester.pump();
    expect(find.text('The other ฿500 still counts as owed by Ko.'), findsOneWidget);
    await tester.tap(find.text('Confirm ฿500'));
    await tester.pumpAndSettle();

    final settlement = fakeSquad.settlements.single;
    expect(settlement.isConfirmed, isTrue);
    expect(settlement.amountCents, 50000);
    expect(settlement.sentCents, 100000);
    expect(find.text('Confirmed ฿500. The other ฿500 still counts as owed.'), findsOneWidget);
    // Ko still owes the other half.
    expect(find.text('TO CONFIRM'), findsNothing);
    expect(find.text('฿500'), findsWidgets);
  });

  testWidgets('Pay later: promise a day; reminders wait until then', (tester) async {
    fakeSquad.expenses.add(owedExpense('Dinner', 'aung', {'test-1': 40000}));
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aung'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay later'));
    await tester.pumpAndSettle();
    expect(find.text('WHEN WILL YOU PAY AUNG?'), findsOneWidget);
    await tester.tap(find.text('Promise'));
    await tester.pumpAndSettle();

    final promise = fakeSquad.promises.single;
    expect(promise.toId, 'aung');
    final now = DateTime.now();
    expect(promise.promisedOn, DateTime(now.year, now.month, now.day + 1));
    expect(find.textContaining('You said you’d pay on'), findsOneWidget);
    // One promised day at a time.
    expect(find.text('Pay later'), findsNothing);
  });

  testWidgets("Someone who promised a day isn't reminded until then", (tester) async {
    fakeSquad.expenses.add(owedExpense('Dinner', 'test-1', {'aung': 30000, 'ko': 30000}));
    final now = DateTime.now();
    fakeSquad.promises.add(
      PaymentPromise(
        id: 'p1',
        fromId: 'aung',
        toId: 'test-1',
        promisedOn: DateTime(now.year, now.month, now.day + 5),
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Aung will pay you on'), findsOneWidget);
    // Ko can be reminded; Aung can't.
    expect(find.text('Remind'), findsNWidgets(2)); // the hero's and Ko's card
    await tester.tap(find.textContaining('Aung will pay you on'));
    await tester.pumpAndSettle();
    expect(find.text('Remind'), findsNothing);
    expect(find.text('Got cash'), findsOneWidget);
  });

  testWidgets('Got cash: whoever is owed records it, and it counts straight away',
      (tester) async {
    fakeSquad.expenses.add(owedExpense('Dinner', 'test-1', {'aung': 100000}));
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aung'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Got cash'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('cash-amount')), '600');
    await tester.pump();
    expect(find.text('They owe you ฿1,000 · ฿400 left after this'), findsOneWidget);
    await tester.tap(find.text('Record ฿600 received'));
    await tester.pumpAndSettle();

    final cash = fakeSquad.settlements.single;
    expect(cash.isConfirmed, isTrue);
    expect(cash.recordedBy, 'test-1');
    expect(find.text('AUNG PAYS YOU'), findsOneWidget);
    expect(find.text('฿400'), findsWidgets);
    expect(find.textContaining('Aung paid ฿600 of ฿1,000 so far'), findsOneWidget);
  });

  testWidgets('Pick the day of the month for payment reminders', (tester) async {
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();
    expect(find.text('Reminders: last day of the month'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reminder-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();

    expect(fakeSquad.members.first.reminderDay, 25);
    expect(find.text('Reminders: the 25th of each month'), findsOneWidget);
  });

  testWidgets('Pay the payer back from an expense: Pay, then Pending, then Paid', (tester) async {
    fakeSquad.expenses.add(
      Expense(
        id: 'dinner',
        title: 'Friday dinner',
        category: ExpenseCategory.food,
        amountCents: 90000,
        spentAt: DateTime(2026, 9, 27, 20),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'aung',
        shares: const {'aung': 30000, 'test-1': 30000, 'ko': 30000},
        createdBy: 'aung',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Friday dinner'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Pay Aung'), findsOneWidget);
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I paid in cash'));
    await tester.pumpAndSettle();
    expect(fakeSquad.settlements.single.amountCents, 30000);
    // Sent: waiting for Aung, so no paying twice.
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Pay'), findsNothing);

    // Confirmed: nothing left to pay Aung.
    await fakeSquad.respondSettlement(
      settlementId: fakeSquad.settlements.single.id,
      accept: true,
    );
    (sl<TeamChanges>() as FakeTeamChanges).push('squad-1', TeamTable.settlements);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
  });

  testWidgets('Comments and replies on an expense, live', (tester) async {
    fakeSquad.expenses.add(
      Expense(
        id: 'dinner',
        title: 'Friday dinner',
        category: ExpenseCategory.food,
        amountCents: 120000,
        spentAt: DateTime(2026, 9, 27, 20),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'aung',
        shares: const {'aung': 40000, 'test-1': 40000, 'ko': 40000},
        createdBy: 'aung',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Friday dinner'));
    await tester.pumpAndSettle();
    expect(find.text('No comments yet. Ask about the tip, who had what…'), findsOneWidget);

    // A new comment.
    await tester.enterText(find.byKey(const ValueKey('comment-field')), 'Was the tip included?');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Was the tip included?'), findsOneWidget);
    expect(find.text('COMMENTS · 1'), findsOneWidget);
    // Sent: the keyboard goes away.
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('comment-field'))).focusNode?.hasFocus,
      isFalse,
    );

    // Aung answers on their phone; it arrives over Realtime.
    fakeSquad.commentAs('aung', 'dinner', 'Yes, ฿100 tip is in the total.',
        parentId: fakeSquad.comments.single.id);
    (sl<TeamChanges>() as FakeTeamChanges).push('squad-1', TeamTable.expenseComments);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Yes, ฿100 tip is in the total.'), findsOneWidget);
    expect(find.text('COMMENTS · 2'), findsOneWidget);

    // Replying to Aung's reply joins the same thread.
    await tester.tap(find.text('Reply').last);
    await tester.pumpAndSettle();
    expect(find.text('Replying to Aung'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('comment-field')), 'Thanks!');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final thanks = fakeSquad.comments.last;
    expect(thanks.body, 'Thanks!');
    expect(thanks.parentId, fakeSquad.comments.first.id);
    expect(find.text('Replying to Aung'), findsNothing);

    // Deleting my top comment takes its replies with it.
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();
    expect(find.text('Its 2 replies go with it.'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(fakeSquad.comments, isEmpty);
    expect(find.text('Thanks!'), findsNothing);
  });

  testWidgets('Remind people who owe you — once a day each', (tester) async {
    fakeSquad.expenses.add(
      Expense(
        id: 'hotpot',
        title: 'Hotpot night',
        category: ExpenseCategory.food,
        amountCents: 90000,
        spentAt: DateTime(2026, 9, 27, 20),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'test-1',
        shares: const {'test-1': 30000, 'aung': 30000, 'ko': 30000},
        createdBy: 'test-1',
      ),
    );
    await pumpSquad(tester);
    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();

    expect(find.text('from 2 people'), findsOneWidget);
    expect(find.text('Remind all'), findsOneWidget);
    expect(find.text('Remind'), findsNWidgets(2));

    // Remind Ko alone.
    await tester.tap(find.text('Remind').last);
    await tester.pumpAndSettle();
    expect(fakeSquad.reminded, hasLength(1));
    expect(find.text('Reminder sent.'), findsOneWidget);
    expect(find.text('Reminded'), findsOneWidget);
    expect(find.text('Remind'), findsOneWidget);

    // "Remind all" now only reaches Aung — Ko's had today's.
    await tester.tap(find.text('Remind all'));
    await tester.pumpAndSettle();
    expect(fakeSquad.reminded, hasLength(2));
    expect(find.text('Remind all'), findsNothing);
    expect(find.text('Reminded'), findsNWidgets(3));
  });

  testWidgets("A squad that fails to load says why — never shows an empty squad", (tester) async {
    fakeSquad.ledgerError = 'relation "public.squad_reminders" does not exist';
    await pumpSquad(tester);

    expect(find.text("Couldn't load this squad"), findsOneWidget);
    expect(find.textContaining('squad_reminders'), findsOneWidget);
    expect(find.textContaining('0 members'), findsNothing);
    expect(find.text("You're all square"), findsNothing);

    fakeSquad.ledgerError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Squad · 3 members'), findsOneWidget);

    // A failed refresh keeps what's already on screen.
    fakeSquad.ledgerError = 'Network error';
    (sl<TeamChanges>() as FakeTeamChanges).push('squad-1', TeamTable.expenses);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Squad · 3 members'), findsOneWidget);
  });

  testWidgets('A sent payment can be nudged to confirm — once a day', (tester) async {
    fakeSquad.expenses.add(
      Expense(
        id: 'dinner',
        title: 'Friday dinner',
        category: ExpenseCategory.food,
        amountCents: 90000,
        spentAt: DateTime(2026, 9, 27, 20),
        splitMode: ExpenseSplitMode.equal,
        payerId: 'aung',
        shares: const {'aung': 30000, 'test-1': 30000, 'ko': 30000},
        createdBy: 'aung',
      ),
    );
    // Just sent.
    fakeSquad.sentPaymentAgo('aung', 30000, const Duration(minutes: 1));
    await pumpSquad(tester);
    // Home shows it too, where the pending payment is mentioned.
    expect(find.text('You paid Aung ฿300 · waiting for them to confirm'), findsOneWidget);
    expect(find.text('Remind to confirm'), findsOneWidget);

    await tester.tap(find.text('Settle').last);
    await tester.pumpAndSettle();

    // On Aung's You pay card, not a separate section.
    expect(find.text('WAITING FOR CONFIRMATION'), findsNothing);
    expect(find.text('Remind to confirm'), findsOneWidget);

    await tester.tap(find.text('Remind to confirm'));
    await tester.pumpAndSettle();
    expect(fakeSquad.nudged, [fakeSquad.settlements.single.id]);
    expect(find.text('Reminded Aung to confirm.'), findsOneWidget);
    expect(find.text('Remind to confirm'), findsNothing);
    expect(find.text('Reminded'), findsOneWidget);
  });

  testWidgets('Home recaps a finished match: vote MOTM, then see the winner', (tester) async {
    finishedJustNow();
    await pumpMatchTab(tester, role: TeamRole.player);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('vs Harbour City'), findsOneWidget);
    expect(find.text('Vote for Man of the Match'), findsOneWidget);
    // Home tab badge for the MOTM vote; Match tab badge for the RSVP.
    expect(find.text('!'), findsNWidgets(2));

    await tester.tap(find.text('Vote now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aung Ko').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Vote for Man of the Match'), findsNothing);
    // Secret until everyone's voted (or midnight): just the progress.
    expect(find.text('Man of the Match voting open · 1 of 3 voted'), findsOneWidget);
    // Voted, but "Rate your game" still keeps Home's badge on.
    expect(find.text('Rate your game — 4 quick questions'), findsOneWidget);
    expect(find.text('!'), findsNWidgets(2));
  });

  testWidgets('Home recaps show the unpaid fee, and Wallet gets a badge', (tester) async {
    finishedJustNow();
    fakeWallet.bills['recent-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'p-2',
      payerName: 'Aung Ko',
      splitMode: SplitMode.team,
    );
    await pumpMatchTab(tester);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('You owe ฿300 to Aung Ko'), findsOneWidget);
    expect(find.text('No score yet'), findsWidgets);
    // Home (MOTM vote + fee), Wallet (fee), and Match — the admin hasn't
    // voted on the upcoming match yet.
    expect(find.text('!'), findsNWidgets(3));

    // Home doesn't take payment itself — it sends you to the Wallet tab.
    await tester.tap(find.text('Go to Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('YOU OWE'), findsOneWidget);
    await tester.tap(find.text('Pay ฿300'));
    await tester.pumpAndSettle();
    expect(find.text('Pay Aung Ko'), findsOneWidget);
  });

  test('A match only counts as finished after kick-off + play time', () {
    final kickoff = DateTime(2026, 9, 20, 19);
    final history = MatchHistory(
      members: const [
        MatchdayPlayer(profileId: 'me', name: 'Me'),
        MatchdayPlayer(profileId: 'p-2', name: 'Aung Ko'),
      ],
      matches: [
        PastMatch(
          match: Match(
            id: 'm',
            teamId: 't',
            opponent: 'X',
            kickoffAt: kickoff,
            durationMinutes: 90,
          ),
          answers: const {'me': RsvpAnswer.yes, 'p-2': RsvpAnswer.yes},
        ),
      ],
    );
    PendingActions at(DateTime now) => PendingActions.compute(
          userId: 'me',
          now: now,
          history: history,
        );

    // Before kickoff it isn't on Home.
    expect(at(kickoff.subtract(const Duration(minutes: 1))).recaps, isEmpty);
    // Kicked off 80 minutes ago — still playing: on Home for the scores,
    // nothing to vote on or answer yet.
    final playing = at(kickoff.add(const Duration(minutes: 80)));
    expect(playing.recaps, hasLength(1));
    expect(playing.motmVotesNeeded, 0);
    expect(playing.answersNeeded, 0);
    expect(playing.homeTabAlert, isFalse);
    // 90 minutes of play time are up — MOTM vote + the questions.
    final finished = at(kickoff.add(const Duration(minutes: 90)));
    expect(finished.recaps, hasLength(1));
    expect(finished.motmVotesNeeded, 1);
    expect(finished.answersNeeded, 1);
    expect(finished.homeTabAlert, isTrue);
    expect(finished.matchTabAlert, isFalse);
    // A week later it drops off Home.
    expect(at(kickoff.add(const Duration(days: 8))).recaps, isEmpty);
  });

  test("A match fee only nags (Home + Wallet badges) once the match has finished", () {
    final kickoff = DateTime(2026, 9, 20, 19);
    final wallet = TeamWallet(
      members: const [
        WalletMember(profileId: 'me', name: 'Me'),
        WalletMember(profileId: 'p-2', name: 'Aung Ko'),
      ],
      matches: [
        WalletMatch(
          match: Match(id: 'm', teamId: 't', opponent: 'X', kickoffAt: kickoff),
          bill: const MatchBill(
            totalCost: 600,
            payerId: 'p-2',
            payerName: 'Aung Ko',
            splitMode: SplitMode.team,
          ),
        ),
      ],
    );
    PendingActions at(DateTime now) =>
        PendingActions.compute(userId: 'me', now: now, wallet: wallet);

    // Billed before kick-off: not yet.
    expect(at(kickoff.subtract(const Duration(hours: 2))).walletTabAlert, isFalse);
    // Finished (1 hr default play time): Wallet and Home both nag.
    final after = at(kickoff.add(const Duration(hours: 1)));
    expect(after.feesOwed, 1);
    expect(after.walletTabAlert, isTrue);
    expect(after.homeTabAlert, isTrue);
    expect(after.matchTabAlert, isFalse);
  });

  testWidgets("A fee for a match that hasn't been played yet doesn't badge Wallet or Home",
      (tester) async {
    // Bill on the upcoming match (3 Oct) — owed, but not yet due to nag.
    fakeWallet.bills['match-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'p-2',
      payerName: 'Aung Ko',
      splitMode: SplitMode.team,
    );
    await pumpMatchTab(tester);
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('YOU OWE'), findsOneWidget);
    // Only the Match tab's RSVP nag — nothing for the fee yet.
    expect(find.text('!'), findsOneWidget);
  });

  testWidgets('Tapping a poll option shows who voted, with photo and name', (tester) async {
    await pumpHome(tester, const MatchPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();
    await tester.tap(find.text("I'm in"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit vote'));
    await tester.pumpAndSettle();

    // Tap the "I'm in" result row (its voter photos live on it).
    await tester.tap(find.text("I'm in"));
    await tester.pumpAndSettle();

    Finder inSheet(String text) =>
        find.descendant(of: find.byType(BottomSheet), matching: find.text(text));
    expect(inSheet('Votes'), findsOneWidget);
    expect(inSheet("I'm in · 2"), findsOneWidget);
    expect(inSheet('Aung Ko'), findsOneWidget);
    expect(inSheet('Test Player (you)'), findsOneWidget);
    expect(inSheet('Min Thu'), findsNothing);
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(PlayerAvatar)),
      findsNWidgets(2),
    );

    // Switch to who hasn't replied.
    await tester.tap(inSheet('No reply · 1'));
    await tester.pumpAndSettle();
    expect(inSheet('Aung Ko'), findsNothing);
    expect(inSheet('Min Thu'), findsOneWidget);
  });

  testWidgets('Players needed: set in the match form, shown as progress in the poll',
      (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(find.text('Players needed'), findsOneWidget);

    // Blank is allowed; + starts at the minimum of 2.
    await tester.tap(find.byTooltip('One player more'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);

    // Out of range blocks saving; 10 is fine.
    await tester.enterText(find.widgetWithText(TextField, '2'), '99');
    await tester.pump();
    expect(find.textContaining('Enter between 2 and 50 players'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '99'), '10');
    await tester.pump();

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fakeMatches.matches.first.playersNeeded, 10);
    // Aung Ko is In: 1 of 10.
    expect(find.textContaining('1 of 10 players in'), findsOneWidget);
  });

  testWidgets('Admins remind players to vote — once a day', (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    // Test Player and Min Thu haven't answered.
    await tester.tap(find.text("Remind players to vote (2 haven't answered)"));
    await tester.pumpAndSettle();

    expect(fakeMatches.nudged, ['match-1']);
    expect(find.textContaining('Reminded today at'), findsOneWidget);
    // Disabled for the rest of the day.
    await tester.tap(find.textContaining('Reminded today at'));
    await tester.pumpAndSettle();
    expect(fakeMatches.nudged, ['match-1']);
  });

  testWidgets("Players don't get the remind button", (tester) async {
    await pumpHome(tester, const MatchPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();
    expect(find.textContaining('Remind players to vote'), findsNothing);
  });

  testWidgets('Remind all unpaid — then each is greyed out for the day', (tester) async {
    fakeWallet.bills['match-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'test-1',
      payerName: 'Test Player',
      splitMode: SplitMode.team,
    );
    await pumpHome(tester, const WalletPage(user: user));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remind unpaid (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Remind all unpaid (2)'), findsOneWidget);

    await tester.tap(find.text('Remind all unpaid (2)'));
    await tester.pumpAndSettle();

    expect(fakeWallet.reminded, [('match-1', null)]);
    expect(find.text('Everyone unpaid was reminded today'), findsOneWidget);
  });

  testWidgets('Remind picked players one by one', (tester) async {
    fakeWallet.bills['match-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'test-1',
      payerName: 'Test Player',
      splitMode: SplitMode.team,
    );
    await pumpHome(tester, const WalletPage(user: user));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remind unpaid (2)'));
    await tester.pumpAndSettle();
    Finder inSheet(String text) =>
        find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

    await tester.tap(inSheet('Min Thu'));
    await tester.pump();
    await tester.tap(inSheet('Remind selected (1)'));
    await tester.pumpAndSettle();

    expect(fakeWallet.reminded, hasLength(1));
    expect(fakeWallet.reminded.single.$1, 'match-1');
    expect(fakeWallet.reminded.single.$2, {'p-3'});
    // Aung Ko can still be reminded today; Min Thu can't.
    expect(find.text('Remind unpaid (1)'), findsOneWidget);
    await tester.tap(find.text('Remind unpaid (1)'));
    await tester.pumpAndSettle();
    expect(inSheet('Remind all unpaid (1)'), findsOneWidget);
    expect(find.textContaining('Reminded today at'), findsOneWidget);
  });

  testWidgets("Wallet's first card breaks down the closest match's bill", (tester) async {
    fakeWallet.bills['match-1'] = MatchBill(
      totalCost: 900,
      payerId: 'p-2',
      payerName: 'Aung Ko',
      splitMode: SplitMode.team,
      payments: {
        'p-3': BillPayment(profileId: 'p-3', slipPath: 'x', paidAt: DateTime(2026, 9, 20)),
      },
    );
    await pumpHome(tester, const WalletPage(user: user), role: TeamRole.player);
    await tester.pumpAndSettle();

    // The closest match (Sundown United, 3 Oct) leads — not all-time totals.
    expect(find.text('vs Sundown United'), findsOneWidget);
    expect(find.text('Still owed to Aung Ko'), findsOneWidget);
    // 3-way split of ฿900: Min Thu paid ฿300, I owe ฿300, Aung Ko's own ฿300.
    expect(find.text('Paid back'), findsOneWidget);
    expect(find.text('Still owed'), findsOneWidget);
    expect(find.text("Aung Ko's own share"), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('฿900.00'), findsWidgets);
    expect(
      find.text("฿300 paid back + ฿300 owed + ฿300 Aung Ko's share = ฿900.00"),
      findsOneWidget,
    );
  });

  testWidgets('Wallet shows the top 2 bills, with See all bills for the rest', (tester) async {
    for (var i = 0; i < 4; i++) {
      final match = Match(
        id: 'old-$i',
        teamId: 'team-1',
        opponent: 'Rival $i',
        kickoffAt: DateTime(2026, 8, 1 + i, 19),
      );
      fakeMatches.pastMatches.add(match);
      fakeWallet.bills[match.id] = const MatchBill(
        totalCost: 300,
        payerId: 'test-1',
        payerName: 'Test Player',
        splitMode: SplitMode.team,
      );
    }
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      homeProvided(MaterialApp.router(routerConfig: shellRouter())),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('See all bills (4)'), findsOneWidget);
    await tester.tap(find.text('See all bills (4)'));
    await tester.pumpAndSettle();

    expect(find.text('All bills'), findsOneWidget);
    expect(find.text('AUG 2026'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      expect(find.text('vs Rival $i'), findsOneWidget);
    }
    expect(find.text('2 unpaid'), findsNWidgets(4));
  });

  testWidgets('No total cost yet shows 2 matches, with See more for the rest', (tester) async {
    for (var i = 0; i < 3; i++) {
      fakeMatches.pastMatches.add(
        Match(
          id: 'unbilled-$i',
          teamId: 'team-1',
          opponent: 'Rival $i',
          kickoffAt: DateTime(2026, 8, 1 + i, 19),
        ),
      );
    }
    tester.view
      ..physicalSize = const Size(800, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpHome(tester, const WalletPage(user: user));
    await tester.pumpAndSettle();

    expect(find.text('NO TOTAL COST YET'), findsOneWidget);
    expect(find.textContaining('vs Rival'), findsNothing);
    final seeMore = find.textContaining('See more (');
    expect(seeMore, findsOneWidget);

    await tester.tap(seeMore);
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(find.text('vs Rival $i'), findsOneWidget);
    }
    expect(find.text('Show less'), findsOneWidget);

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(find.textContaining('vs Rival'), findsNothing);
  });

  testWidgets('Bill history is always one tap away from the Wallet', (tester) async {
    fakeWallet.bills['match-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'p-2',
      payerName: 'Aung Ko',
      splitMode: SplitMode.team,
    );
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(homeProvided(MaterialApp.router(routerConfig: shellRouter())));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    // Just one bill — no "See all", but the history button is there.
    expect(find.textContaining('See all bills'), findsNothing);
    await tester.tap(find.byTooltip('Bill history'));
    await tester.pumpAndSettle();
    expect(find.text('All bills'), findsOneWidget);
    expect(find.text('vs Sundown United'), findsOneWidget);
  });

  testWidgets('Adding a total cost asks for a wallet QR first', (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Add total cost'), 200);
    await tester.tap(find.text('Add total cost'));
    await tester.pumpAndSettle();

    // No QR yet: an error message with a Profile shortcut, and no bill form.
    expect(find.textContaining('Add your wallet QR in Profile first'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Total cost you paid'), findsNothing);
  });

  testWidgets("Any team admin can cancel a match, not just whoever created it", (tester) async {
    // Created by Aung Ko — another admin, not me.
    final match = fakeMatches.matches.first;
    fakeMatches.matches[0] = Match(
      id: match.id,
      teamId: match.teamId,
      opponent: match.opponent,
      kickoffAt: match.kickoffAt,
      venue: match.venue,
      createdBy: 'p-2',
    );
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    expect(find.text('Edit details'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cancel match'), 200);
    expect(find.text('Cancel match'), findsOneWidget);
  });

  testWidgets('Back goes to Home from any tab; on Home, press back twice to exit',
      (tester) async {
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(homeProvided(MaterialApp.router(routerConfig: shellRouter())));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Bill history'), findsOneWidget);

    // Back from Wallet → Home.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Golden Goal FC'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    // Back on Home → "press again" message, not exit.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    // Again, straight away → exit.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(platformCalls, contains('SystemNavigator.pop'));
    await tester.pumpAndSettle();
  });
}
