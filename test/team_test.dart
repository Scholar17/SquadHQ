import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:squad_hq/core/di/injection_container.dart';
import 'package:squad_hq/features/auth/domain/entities/app_user.dart';
import 'package:squad_hq/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:squad_hq/features/team/presentation/bloc/team_bloc.dart';
import 'package:squad_hq/features/team/presentation/bloc/team_event.dart';
import 'package:squad_hq/features/team/presentation/pages/app_shell_page.dart';
import 'package:squad_hq/features/team/presentation/pages/dashboard_page.dart';
import 'package:squad_hq/features/team/presentation/pages/match_page.dart';
import 'package:squad_hq/features/team/presentation/pages/squad_page.dart';
import 'package:squad_hq/features/team/presentation/pages/wallet_page.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initTestSupabase();
    await initDependencies();
  });

  const user = AppUser(
    id: 'test-1',
    name: 'Test Player',
    provider: AuthProvider.google,
    phone: '+66812345678',
    username: 'testplayer',
  );

  Future<void> pumpTeam(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => sl<TeamBloc>()..add(const TeamStarted()),
            child: child,
          ),
        ),
      );

  testWidgets('Home shows the matchday hero and needs-you actions', (tester) async {
    await pumpTeam(tester, const DashboardPage(user: user));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Golden Goal FC'), findsOneWidget);
    expect(find.text('vs Sundown United'), findsOneWidget);
    expect(find.text('MOTM voting is open'), findsOneWidget);
    expect(find.text('Open matchday'), findsOneWidget);
  });

  testWidgets('Match hub shows the roster and RSVP progress', (tester) async {
    await pumpTeam(tester, const MatchPage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('MATCHDAY HUB'), findsOneWidget);
    expect(find.text('Messi'), findsOneWidget);
    expect(find.text('Remind everyone'), findsOneWidget);
  });

  testWidgets('Wallet shows team balance and owed fees', (tester) async {
    await pumpTeam(tester, const WalletPage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('฿4,250'), findsOneWidget);
    expect(find.text('3 unpaid'), findsOneWidget);
  });

  testWidgets('Add bill splits a new bill equally across the roster', (tester) async {
    await pumpTeam(tester, const WalletPage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('3 unpaid'), findsOneWidget);

    await tester.tap(find.text('+ Add bill'));
    await tester.pumpAndSettle();

    expect(find.text('Split a bill'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Rent fee'), '900');
    await tester.enterText(find.widgetWithText(TextField, 'Water fee'), '90');
    await tester.pump();

    // 9 players, ฿990 total — an even ฿110 each.
    expect(find.text('฿990'), findsWidgets);

    await tester.ensureVisible(find.text('Split ฿990'));
    await tester.tap(find.text('Split ฿990'));
    await tester.pumpAndSettle();

    expect(find.text('Split a bill'), findsNothing);
    expect(find.text('9 unpaid'), findsOneWidget);
  });

  testWidgets('Add bill lets a manager exclude a player from the split', (tester) async {
    await pumpTeam(tester, const WalletPage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('+ Add bill'));
    await tester.pumpAndSettle();

    expect(find.text('9 of 9'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.text('8 of 9'), findsOneWidget);
  });

  testWidgets('Squad tab lists the roster and opens a player card', (tester) async {
    await pumpTeam(tester, const SquadPage(user: user));
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
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => sl<AuthBloc>(),
        child: MaterialApp(
          home: BlocProvider(
            create: (_) => sl<TeamBloc>()..add(const TeamStarted()),
            child: const SquadPage(user: user),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Your profile'));
    await tester.pumpAndSettle();

    expect(find.text('Test Player'), findsOneWidget);
    expect(find.text('+66812345678'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Test Player'), findsOneWidget);
  });

  testWidgets('App shell switches between all four tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShellPage(user: user)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Golden Goal FC'), findsOneWidget);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('SQUAD WALLET'), findsOneWidget);

    await tester.tap(find.text('Squad'));
    await tester.pumpAndSettle();
    expect(find.text('SQUAD · 2026 SEASON'), findsOneWidget);
  });
}
