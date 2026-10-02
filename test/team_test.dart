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
import 'package:squad_hq/features/match/domain/entities/match.dart';
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
import 'package:squad_hq/features/notifications/domain/repositories/notification_repository.dart';
import 'package:squad_hq/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:squad_hq/features/notifications/presentation/pages/notifications_page.dart';
import 'package:squad_hq/features/squad/domain/entities/expense.dart';
import 'package:squad_hq/features/squad/domain/repositories/squad_repository.dart';
import 'package:squad_hq/features/squad/presentation/bloc/squad_ledger_bloc.dart';
import 'package:squad_hq/features/squad/presentation/pages/expense_detail_page.dart';
import 'package:squad_hq/features/squad/presentation/pages/expenses_page.dart';
import 'package:squad_hq/features/squad/presentation/pages/settle_page.dart';
import 'package:squad_hq/features/squad/presentation/pages/squad_home_page.dart';
import 'package:squad_hq/features/squad/presentation/pages/squad_members_page.dart';
import 'package:squad_hq/features/team/domain/entities/team_snapshot.dart';
import 'package:squad_hq/features/team/presentation/bloc/team_bloc.dart';
import 'package:squad_hq/features/team/presentation/bloc/team_event.dart';
import 'package:squad_hq/features/team/presentation/pages/app_shell_page.dart';
import 'package:squad_hq/features/team/presentation/pages/dashboard_page.dart';
import 'package:squad_hq/features/team/presentation/pages/match_page.dart';
import 'package:squad_hq/features/team/presentation/pages/player_card_page.dart';
import 'package:squad_hq/features/team/presentation/pages/squad_page.dart';
import 'package:squad_hq/features/team/presentation/pages/wallet_page.dart';
import 'package:squad_hq/features/team/presentation/widgets/group_tab.dart';
import 'package:squad_hq/features/team_membership/domain/entities/team.dart';
import 'package:squad_hq/features/team_membership/presentation/bloc/team_membership_bloc.dart';
import 'package:squad_hq/features/team_membership/presentation/bloc/team_membership_state.dart';
import 'package:squad_hq/features/wallet/domain/entities/team_wallet.dart';
import 'package:squad_hq/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:squad_hq/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:squad_hq/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:squad_hq/features/wallet/presentation/pages/wallet_bills_page.dart';

import 'fake_notification_repository.dart';
import 'fake_squad_repository.dart';
import 'fake_team_changes.dart';
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
        ) {
    emit(TeamMembershipLoaded(teams));
  }
}

void main() {
  final fakeMatches = FakeMatchRepository(teamId: 'team-1', userId: 'test-1');
  final fakeWallet = FakeWalletRepository(fakeMatches);
  final fakeNotifications = FakeNotificationRepository();
  final fakeSquad = FakeSquadRepository(userId: 'test-1');

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
      ..unregister<TeamChanges>()
      ..registerLazySingleton<TeamChanges>(FakeTeamChanges.new);
  });

  setUp(() {
    fakeMatches.reset();
    fakeWallet.reset();
    fakeNotifications.reset();
    fakeSquad.reset();
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
              setMatchScore: sl(),
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
    // Nothing finished recently yet, so just the hint.
    expect(find.text('AFTER THE MATCH'), findsOneWidget);
    expect(find.textContaining('Once a match finishes'), findsOneWidget);
  });

  testWidgets('Home role pill switches an admin between Manager and Player views',
      (tester) async {
    await pumpHome(tester, const DashboardPage(user: user));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('+ New match'), findsOneWidget);

    await tester.tap(find.text('Manager'));
    await tester.pump();

    expect(find.text('Player'), findsOneWidget);
    expect(find.text('+ New match'), findsNothing);

    await tester.tap(find.text('Player'));
    await tester.pump();

    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('+ New match'), findsOneWidget);
  });

  testWidgets("Home role pill doesn't let a player switch to Manager", (tester) async {
    await pumpHome(tester, const DashboardPage(user: user), role: TeamRole.player);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Player'), findsOneWidget);

    await tester.tap(find.text('Player'));
    await tester.pump();

    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Manager'), findsNothing);
    expect(find.text('Only team admins can switch to the Manager view'), findsOneWidget);
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

  testWidgets('Admins in the Manager view can vote too, without the urgent styling',
      (tester) async {
    await pumpHome(tester, const MatchPage(user: user));
    await tester.pumpAndSettle();

    // Not voted yet: options + Submit vote, but no glow/"needed" label.
    expect(find.text('POLL · YOUR VOTE NEEDED'), findsNothing);
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
    expect(find.text('Cancel match?'), findsOneWidget);

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

    // One Pay button — on the "You owe" card; the bill card only shows status.
    expect(find.text('Pay ฿300'), findsOneWidget);
    expect(find.text('You owe ฿300 · pay in Wallet'), findsOneWidget);
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
    expect(find.text('Replace slip'), findsOneWidget);

    Navigator.of(sheet).pop();
    await tester.pumpAndSettle();

    expect(find.text('YOU OWE'), findsNothing);
    expect(find.text('฿300'), findsWidgets);
    expect(find.text("You've paid"), findsOneWidget);
  });

  testWidgets('The payer can only edit their bill from the Manager view', (tester) async {
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

    final page = tester.element(find.byType(WalletPage));
    page.read<TeamBloc>().add(const TeamRoleToggled());
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

  testWidgets('Squad tab lists the roster and opens a player card', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.squad,
      routes: [
        GoRoute(
          path: AppRoutes.squad,
          builder: (context, state) => teamProvided(const SquadPage(user: user)),
        ),
        GoRoute(
          path: AppRoutes.teamPlayer,
          builder: (context, state) => PlayerCardPage(member: state.extra! as SquadMember),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Neymar'), findsOneWidget);

    await tester.tap(find.text('Neymar'));
    await tester.pumpAndSettle();

    expect(find.text('Player card'), findsOneWidget);
    expect(find.text('OVR'), findsOneWidget);
  });

  testWidgets('Your profile shows account details and confirms before logging out',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.squad,
      routes: [
        GoRoute(
          path: AppRoutes.squad,
          builder: (context, state) => teamProvided(const SquadPage(user: user)),
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

    expect(find.text('Test Player'), findsOneWidget);
    expect(find.text('+66812345678'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('WALLET QR'), findsOneWidget);
    expect(find.text('Upload QR'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('BANK DETAILS'), 200);
    expect(find.text('Optional · for squad-mates who pay by transfer'), findsOneWidget);
    // No Firebase in tests, so push shows as unavailable.
    await tester.scrollUntilVisible(find.text('NOTIFICATIONS'), 200);
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
    // An admin in the Manager view never gets the RSVP badge.
    expect(find.text('!'), findsNothing);

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

  testWidgets('An admin records a past match score', (tester) async {
    await pumpMatchTab(tester);
    await tester.tap(find.byTooltip('Match history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Thai Group'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add score'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Plus one for Golden Goal FC'));
      await tester.pump();
    }
    await tester.tap(find.byTooltip('Plus one for Thai Group'));
    await tester.pump();
    await tester.tap(find.text('Save score'));
    await tester.pumpAndSettle();

    expect(find.text('3 – 1'), findsOneWidget);
    expect(find.text('Win'), findsOneWidget);
    expect(find.text('Edit score'), findsOneWidget);
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
        kickoffAt: DateTime(2026, 10, 17, 19),
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
        kickoffAt: DateTime(2026, 10, 17, 19),
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

  testWidgets('A squad shows the four squad tabs and an empty Home', (tester) async {
    await pumpSquad(tester);

    for (final tab in ['Home', 'Expenses', 'Settle', 'Members']) {
      expect(find.text(tab), findsWidgets);
    }
    expect(find.text('Match'), findsNothing);
    expect(find.text('Friday Crew'), findsOneWidget);
    expect(find.text("You're all square"), findsOneWidget);
    expect(find.text('No expenses yet'), findsOneWidget);

    await tester.tap(find.text('Members').last);
    await tester.pumpAndSettle();
    expect(find.text('K7Q2XM'), findsOneWidget);
    expect(find.text('3 MEMBERS'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
  });

  testWidgets(
      'Adding ฿1,000 split equally between 3 shows ฿334 (exact ฿333.33) each; the payer covers ฿332',
      (tester) async {
    await pumpSquad(tester);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '1000');
    await tester.pumpAndSettle();
    expect(find.text('฿334'), findsNWidgets(2));
    expect(find.text('exact ฿333.33'), findsNWidgets(2));
    expect(find.text('฿332'), findsOneWidget);
    expect(find.text('covers the rest'), findsOneWidget);

    await tester.tap(find.text('Save expense'));
    await tester.pumpAndSettle();

    final saved = fakeSquad.expenses.single;
    expect(saved.payerId, 'test-1');
    expect(saved.shares, {'test-1': 33200, 'aung': 33400, 'ko': 33400});
    // Back on Home: the others owe me ฿668 between them.
    expect(find.text("You're owed"), findsOneWidget);
    expect(find.text('฿668'), findsWidgets);
    expect(find.text('Food'), findsWidgets);
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

    expect(find.text('YOU OWE'), findsOneWidget);
    expect(find.text('฿300'), findsWidgets);

    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Pay Aung'), findsOneWidget);
    // Aung has no QR but has bank details, so Bank is picked.
    expect(find.text('123-4-56789'), findsOneWidget);
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I paid in cash'));
    await tester.pumpAndSettle();

    // Sent, but not counted yet.
    expect(fakeSquad.settlements.single.isPending, isTrue);
    expect(find.text('WAITING FOR CONFIRMATION'), findsOneWidget);
    expect(find.text('YOU OWE'), findsOneWidget);

    // Aung confirms on their phone; it arrives over Realtime.
    await fakeSquad.respondSettlement(
      settlementId: fakeSquad.settlements.single.id,
      accept: true,
    );
    (sl<TeamChanges>() as FakeTeamChanges).push('squad-1', TeamTable.settlements);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('ALL SQUARE'), findsOneWidget);
    expect(find.text('SETTLED'), findsOneWidget);
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
    expect(find.text("YOU'RE OWED"), findsOneWidget);
    expect(find.text('Aung → You'), findsOneWidget);
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
    // Voted: only the Match tab's RSVP badge is left.
    expect(find.text('!'), findsOneWidget);
  });

  testWidgets('Home recaps show the unpaid fee, and Wallet gets a badge', (tester) async {
    finishedJustNow();
    fakeWallet.bills['recent-1'] = const MatchBill(
      totalCost: 900,
      payerId: 'p-2',
      payerName: 'Aung Ko',
      splitMode: SplitMode.team,
    );
    // Admin in Manager view: no RSVP nag, so any badge is from MOTM / fee.
    await pumpMatchTab(tester);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('You owe ฿300 to Aung Ko'), findsOneWidget);
    expect(find.text('Add score'), findsOneWidget);
    // Two badges: Home (MOTM vote + fee) and Wallet (fee). None on Match —
    // no RSVP nag in the Manager view.
    expect(find.text('!'), findsNWidgets(2));

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
          playerView: true,
          now: now,
          history: history,
        );

    // Kicked off 80 minutes ago — still playing.
    expect(at(kickoff.add(const Duration(minutes: 80))).recaps, isEmpty);
    // 90 minutes of play time are up — recap + MOTM vote.
    final finished = at(kickoff.add(const Duration(minutes: 90)));
    expect(finished.recaps, hasLength(1));
    expect(finished.motmVotesNeeded, 1);
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
        PendingActions.compute(userId: 'me', playerView: true, now: now, wallet: wallet);

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
    expect(find.text('!'), findsNothing);
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

  testWidgets("Only the admin who created a match can cancel it", (tester) async {
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
    expect(find.text('Cancel match'), findsNothing);
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
